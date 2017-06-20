//
//  IndoorLocationManager.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 14.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import Accelerate

enum FilterType: Int {
    case none = 0
    case kalman
    case particle
}

typealias Anchor = (id: Int, position: CGPoint)

protocol IndoorLocationManagerDelegate {
    func updatePosition(_ position: CGPoint)
    func updateAnchors(_ anchors: [Anchor])
    func updateCovariance(covX: Double, covY: Double)
    func updateParticles(_ particles: [Particle])
    
    func showAlertWithTitle(_ title: String, message: String)
}

class IndoorLocationManager {
    
    static let shared = IndoorLocationManager()
    
    var delegate: IndoorLocationManagerDelegate?
    
    var anchors: [Anchor]?
        
    var filter: BayesianFilter?
    
    var filterSettings: FilterSettings
    
    var position: CGPoint?
    
    private init() {
        filterSettings = FilterSettings()
    }
    
    //MARK: Private API
    private func parseData(_ stringData: String) -> [String : Double]? {
        
        // Remove carriage return
        if let inlineStringData = stringData.components(separatedBy: "\r").first {
            // Check that returned data is of expected format
            if (inlineStringData.range(of: "([A-Za-z]+-?[0-9-]*=-?[0-9.]+&)*([A-Za-z]+-?[0-9.]*=-?[0-9.]+)", options: .regularExpression) != inlineStringData.startIndex..<inlineStringData.endIndex) {
                delegate?.showAlertWithTitle("Error", message: String(describing: inlineStringData))
                return nil
            }
            
            // Split string at "&" characters
            let splitData = inlineStringData.components(separatedBy: "&")
            
            var parsedData = [String : Double]()
            for component in splitData {
                let key = component.components(separatedBy: "=")[0]
                let value = Double(component.components(separatedBy: "=")[1])
                parsedData[key] = value!
            }
            return parsedData
        }
        delegate?.showAlertWithTitle("Error", message: "Received unexpected format from Arduino!")
        return nil
    }
    
    private func parseCalibrationData(data: Data?) {
        guard let data = data else {
            delegate?.showAlertWithTitle("Error", message: "No calibration data received!")
            return
        }
        
        let stringData = String(data: data, encoding: String.Encoding.utf8)!
        
        guard let anchorDict = self.parseData(stringData) else { return }
        
        var anchors = [Anchor]()
        var distances = [Double]()
        
        // Iterate from 0 to anchorDict.count / 4 because there are 4 values for every anchor:
        // ID, xPos, yPos, dist
        for i in 0..<anchorDict.count / 4 {
            guard let id = anchorDict["ID\(i)"],
                let xCoordinate = anchorDict["xPos\(i)"],
                let yCoordinate = anchorDict["yPos\(i)"],
                let distance = anchorDict["dist\(i)"] else {
                    fatalError("Error retrieving data from anchorDict")
            }
            anchors.append(Anchor(id: Int(id), position: CGPoint(x: xCoordinate, y: yCoordinate)))
            distances.append(distance)
        }
        
        self.anchors = anchors
        
        self.delegate?.updateAnchors(anchors)
        
        // Least squares algorithm to get initial position
        self.position = leastSquares(anchors: anchors.map { $0.position }, distances: distances)
    }
    
    private func receivedCalibrationResult(_ result: NetworkResult) {
        switch result {
        case .success(let data):
            self.parseCalibrationData(data: data)
            self.delegate?.showAlertWithTitle("Success", message: "Calibration Successful!")
        case .failure(let error):
            self.delegate?.showAlertWithTitle("Error", message: error.localizedDescription)
        }
    }
    
    //MARK: Public API
    func calibrate(automatic: Bool) {
        if automatic {
            NetworkManager.shared.pozyxTask(task: .calibrate) { result in
                self.receivedCalibrationResult(result)
            }
        } else {
            guard let anchors = anchors else { return }
            var anchorStringData = ""
            for (i, anchor) in anchors.enumerated() {
                anchorStringData += "ID\(i)=\(anchor.id)&xPos\(i)=\(Int((anchor.position.x)))&yPos\(i)=\(Int((anchor.position.y)))"
                if (i != anchors.count - 1) {
                    anchorStringData += "&"
                }
            }
            NetworkManager.shared.pozyxTask(task: .setAnchors, data: anchorStringData) { result in
                self.receivedCalibrationResult(result)
            }
        }
    }
    
    func beginRanging() {
        NetworkManager.shared.pozyxTask(task: .beginRanging) { _ in }
    }
    
    func stopRanging() {
        NetworkManager.shared.pozyxTask(task: .stopRanging) { _ in }
    }
    
    func newData(_ data: String?) {
        guard let data = data else {
            delegate?.showAlertWithTitle("Error", message: "No ranging data received!")
            return
        }

        guard let measurementDict = parseData(data) else { return }
        
        guard let anchors = anchors else {
            delegate?.showAlertWithTitle("Error", message: "No Anchors found. Calibration has to be executed first!")
            return
        }
        
        var measurements = [Double]()
        for i in 0..<anchors.count {
            guard let distance = measurementDict["dist\(i)"] else {
                fatalError("Error retrieving data from measurementDict")
            }
            measurements.append(distance)
        }
        
        guard let xAcc = measurementDict["xAcc"], let yAcc = measurementDict["yAcc"] else {
            fatalError("Error retrieving data from measurementDict")
        }
        measurements.append(xAcc)
        measurements.append(yAcc)
        
        filter?.computeAlgorithm(measurements: measurements) { position in
            self.position = position
            
            self.delegate?.updatePosition(position)
            
            switch (self.filterSettings.filterType) {
            case .kalman:
                guard let filter = self.filter as? KalmanFilter else { return }
                self.delegate?.updateCovariance(covX: filter.P[0], covY: filter.P[7])
            case .particle:
                guard let filter = self.filter as? ParticleFilter else { return }
                self.delegate?.updateParticles(filter.particles)
            default:
                break
            }
        }
    }
    
    func addAnchorWithID(_ id: Int, x: Int, y: Int) {
        if (anchors == nil) {
            anchors = []
        }
        anchors?.append(Anchor(id: id, position: CGPoint(x: x, y: y)))
    }
}

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
    var filterSettings = FilterSettings()
    
    var position: CGPoint?
    
    var isCalibrated = false
    var isRanging = false
    
    private var cachedMeasurement: [String : Double]?
    
    private init() {}
    
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
    
    private func parseCalibrationData(data: Data?) -> Bool {
        guard let data = data else {
            delegate?.showAlertWithTitle("Error", message: "No calibration data received!")
            return false
        }
        
        let stringData = String(data: data, encoding: String.Encoding.utf8)!
        
        guard let anchorDict = self.parseData(stringData) else { return false }
        
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
            anchors.append(Anchor(id: Int(id), position: CGPoint(x: xCoordinate / 10, y: yCoordinate / 10)))
            distances.append(distance / 10)
        }
        
        self.anchors = anchors
        
        self.delegate?.updateAnchors(anchors)
        
        // Least squares algorithm to get initial position
        self.position = leastSquares(anchors: anchors.map { $0.position }, distances: distances)
        
        return true
    }
    
    private func receivedCalibrationResult(_ result: NetworkResult) {
        switch result {
        case .success(let data):
            if self.parseCalibrationData(data: data) {
                isCalibrated = true
                self.delegate?.showAlertWithTitle("Success", message: "Calibration Successful!")
            }
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
//            // Fake manual calibration response for testing purposes.
//            let data = ("ID0=\(Int("666D", radix: 16)!)&xPos0=0&yPos0=0&dist0=500" +
//                        "&ID1=\(Int("6F21", radix: 16)!)&xPos1=1100&yPos1=3350&dist1=500" +
//                        "&ID2=\(Int("6F59", radix: 16)!)&xPos2=4050&yPos2=1300&dist2=500").data(using: .utf8)
//            let result = NetworkResult.success(data)
//            receivedCalibrationResult(result)
            
            // Faking anchors as I'm too lazy to enter coordinates every time.
            addAnchorWithID(Int("666D", radix: 16)!, x: 0, y: 0)
            addAnchorWithID(Int("6F21", radix: 16)!, x: 110, y: 335)
            addAnchorWithID(Int("6F59", radix: 16)!, x: 405, y: 130)
            
            guard let anchors = anchors else { return }
            var anchorStringData = ""
            for (i, anchor) in anchors.enumerated() {
                anchorStringData += "ID\(i)=\(anchor.id)&xPos\(i)=\(Int((anchor.position.x) * 10))&yPos\(i)=\(Int((anchor.position.y) * 10))"
                if (i != anchors.count - 1) {
                    anchorStringData += "&"
                }
            }
            NetworkManager.shared.pozyxTask(task: .setAnchors, data: anchorStringData) { result in
                self.receivedCalibrationResult(result)
            }
        }
    }
    
    func beginRanging(successCallback: @escaping () -> ()) {
        if isCalibrated {
            NetworkManager.shared.pozyxTask(task: .beginRanging) { result in
                switch result {
                case .failure(let error):
                    self.delegate?.showAlertWithTitle("Error", message: error.localizedDescription)
                case .success(_):
                    self.isRanging = true
                    successCallback()
                }
            }
        } else {
            delegate?.showAlertWithTitle("Error", message: "Calibration has to be executed first!")
        }
    }
    
    func stopRanging(successCallback: @escaping () -> ()) {
        NetworkManager.shared.pozyxTask(task: .stopRanging) { result in
            switch result {
            case .failure(let error):
                self.delegate?.showAlertWithTitle("Error", message: error.localizedDescription)
            case .success(_):
                self.isRanging = false
                successCallback()
            }
        }
    }
    
    func newRangingData(_ data: String?) {
        guard isRanging else {
            stopRanging() { _ in }
            return
        }
        
        guard let data = data else {
            delegate?.showAlertWithTitle("Error", message: "No ranging data received!")
            return
        }

        guard var measurementDict = parseData(data) else { return }
        
        // If one component of the measurement is 0, use the last measurement again. This might sometimes happen as Pozyx is not that stable
        if measurementDict.values.contains(0) {
            guard let cachedMeasurement = cachedMeasurement else { return }
            measurementDict = cachedMeasurement
        } else {
            cachedMeasurement = measurementDict
        }
                
        guard let anchors = anchors else {
            fatalError("No Anchors found")
        }
        
        var measurements = [Double]()
        for i in 0..<anchors.count {
            guard let distance = measurementDict["dist\(i)"] else {
                fatalError("Error retrieving data from measurementDict")
            }
            measurements.append(distance / 10)
        }
        
        guard let xAcc = measurementDict["xAcc"], let yAcc = measurementDict["yAcc"] else {
            fatalError("Error retrieving data from measurementDict")
        }
        measurements.append(xAcc / 10)
        measurements.append(yAcc / 10)
        
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

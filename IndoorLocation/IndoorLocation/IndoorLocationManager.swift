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
        
        // Check that returned data is of expected format
        if (stringData.range(of: "([A-Za-z]+-?[0-9-]*=-?[0-9.]+&)*([A-Za-z]+-?[0-9.]*=-?[0-9.]+)\\r?\\n?", options: .regularExpression) != stringData.startIndex..<stringData.endIndex) {
            print("Wrong format of calibration data! Received: \(String(describing: stringData))")
            return nil
        }
        
        // Remove carriage return and split string at "&" characters
        let splitData = stringData.components(separatedBy: "\r").first?.components(separatedBy: "&")
        
        var parsedData = [String : Double]()
        for component in splitData! {
            let key = component.components(separatedBy: "=")[0]
            let value = Double(component.components(separatedBy: "=")[1])
            parsedData[key] = value!
        }
        return parsedData
    }
    
    private func parseCalibrationData(data: Data?) {
        guard let data = data else {
            print("No calibration data received!")
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
                    print("Error retrieving data from anchorDict")
                    return
            }
            anchors.append(Anchor(id: Int(id), position: CGPoint(x: xCoordinate, y: yCoordinate)))
            distances.append(distance)
        }
        
        self.anchors = anchors
        
        self.delegate?.updateAnchors(anchors)
        
        // Least squares algorithm to get initial position
        self.position = leastSquares(anchors: anchors.map { $0.position }, distances: distances)
    }
    
    //MARK: Public API
    func calibrate(automatic: Bool) {
        if automatic {
            NetworkManager.shared.pozyxTask(task: .calibrate) { data in
                self.parseCalibrationData(data: data)
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
            NetworkManager.shared.pozyxTask(task: .setAnchors, data: anchorStringData) { data in
                self.parseCalibrationData(data: data)
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
            print("No ranging data received!")
            return
        }

        guard let measurementDict = parseData(data) else { return }
        
        guard let anchors = anchors else { return }
        var measurements = [Double]()
        for i in 0..<anchors.count {
            guard let distance = measurementDict["dist\(i)"] else {
                print("Error retrieving data from measurementDict")
                return
            }
            measurements.append(distance)
        }
        
        guard let xAcc = measurementDict["xAcc"], let yAcc = measurementDict["yAcc"] else {
            print("Error retrieving data from measurementDict")
            return
        }
        measurements.append(xAcc)
        measurements.append(yAcc)
        
        filter?.computeAlgorithm(measurements: measurements) { position in
            self.position = position
            
            delegate?.updatePosition(position)
            
            switch (filterSettings.filterType) {
            case .kalman:
                guard let filter = filter as? KalmanFilter else { return }
                delegate?.updateCovariance(covX: filter.P[0], covY: filter.P[7])
            case .particle:
                guard let filter = filter as? ParticleFilter else { return }
                delegate?.updateParticles(filter.particles)
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

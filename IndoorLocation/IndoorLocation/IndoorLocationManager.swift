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

typealias Anchor = (id: Int, position: CGPoint, isActive: Bool)

protocol IndoorLocationManagerDelegate {
    func setAnchors(_ anchors: [Anchor])
    func updateActiveAnchors(_ anchors: [Anchor], distances: [Float])
    func updatePosition(_ position: CGPoint)
    func updateCovariance(covX: Float, covY: Float)
    func updateParticles(_ particles: [Particle])
}

class IndoorLocationManager {
    
    static let shared = IndoorLocationManager()
    
    var delegate: IndoorLocationManagerDelegate?
    
    var anchors: [Anchor]?
    var filter: BayesianFilter?
    var filterSettings = FilterSettings()
    
    var position: CGPoint?
    var initialDistances: [Float]?
    
    var isCalibrated = false
    var isRanging = false
    
    private init() {}
    
    //MARK: Private API
    private func parseData(_ stringData: String) -> [String : Float]? {
        
        // Remove carriage return
        if let inlineStringData = stringData.components(separatedBy: "\r").first {
            // Check that returned data is of expected format
            if (inlineStringData.range(of: "([A-Za-z]+-?[0-9-]*=-?[0-9.]+&)*([A-Za-z]+-?[0-9.]*=-?[0-9.]+)", options: .regularExpression) != inlineStringData.startIndex..<inlineStringData.endIndex) {
                alertWithTitle("Error", message: String(describing: inlineStringData))
                return nil
            }
            
            // Split string at "&" characters
            let splitData = inlineStringData.components(separatedBy: "&")
            
            var parsedData = [String : Float]()
            for component in splitData {
                let key = component.components(separatedBy: "=")[0]
                let value = Float(component.components(separatedBy: "=")[1])
                parsedData[key] = value!
            }
            return parsedData
        }
        alertWithTitle("Error", message: "Received unexpected format from Arduino!")
        return nil
    }
    
    private func receivedCalibrationResult(_ result: NetworkResult) {
        switch result {
        case .success(let data):
            guard let data = data else {
                alertWithTitle("Error", message: "No calibration data received!")
                return
            }
            
            let stringData = String(data: data, encoding: String.Encoding.utf8)!
            
            guard var anchorDict = self.parseData(stringData) else { return }
            
            var anchors = [Anchor]()
            var distances = [Float]()
            
            // Iterate from 0 to anchorDict.count / 4 because there are 4 values for every anchor:
            // ID, xPos, yPos, dist
            for i in 0..<anchorDict.count / 4 {
                guard let id = anchorDict["ID\(i)"],
                    let xPos = anchorDict["xPos\(i)"],
                    let yPos = anchorDict["yPos\(i)"],
                    let dist = anchorDict["dist\(i)"] else {
                        fatalError("Error retrieving data from anchorDict")
                }
                
                if dist != 0 {
                    anchors.append(Anchor(id: Int(id), position: CGPoint(x: CGFloat(xPos / 10), y: CGFloat(yPos / 10)), isActive: true))
                    distances.append(dist / 10)
                } else {
                    anchors.append(Anchor(id: Int(id), position: CGPoint(x: CGFloat(xPos / 10), y: CGFloat(yPos / 10)), isActive: false))
                }
            }
            
            self.anchors = anchors
            
            self.delegate?.setAnchors(anchors)
            
            initialDistances = distances
            
            isCalibrated = true
            alertWithTitle("Success", message: "Calibration Successful!")
            
        case .failure(let error):
            alertWithTitle("Error", message: error.localizedDescription)
        }
    }
    
    //MARK: Public API
    func calibrate() {
        if filterSettings.calibrationModeIsAutomatic {
            NetworkManager.shared.pozyxTask(task: .calibrate) { result in
                self.receivedCalibrationResult(result)
            }
        } else {
            // Faking anchors as I'm too lazy to enter coordinates every time.
            if (anchors == nil || !(anchors!.count > 0)) {
                addAnchorWithID(Int("666D", radix: 16)!, x: 500, y: 0)
                addAnchorWithID(Int("6F21", radix: 16)!, x: 390, y: 335)
                addAnchorWithID(Int("6F59", radix: 16)!, x: 95, y: 130)
                addAnchorWithID(Int("6F51", radix: 16)!, x: 195, y: 335)
                // Not even existing anchors
                addAnchorWithID(Int("6AAA", radix: 16)!, x: 0, y: 0)
                addAnchorWithID(Int("6AAB", radix: 16)!, x: 250, y: 250)
            }
            
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
    
    func beginRanging(resultCallback: @escaping (Error?) -> ()) {
        if isCalibrated {
            NetworkManager.shared.pozyxTask(task: .beginRanging) { result in
                switch result {
                case .failure(let error):
                    resultCallback(error)
                case .success(_):
                    self.isRanging = true
                    resultCallback(nil)
                }
            }
        } else {
            alertWithTitle("Error", message: "Calibration has to be executed first!")
        }
    }
    
    func stopRanging(resultCallback: @escaping (Error?) -> ()) {
        NetworkManager.shared.pozyxTask(task: .stopRanging) { result in
            switch result {
            case .failure(let error):
                resultCallback(error)
            case .success(_):
                self.isRanging = false
                resultCallback(nil)
            }
        }
    }
    
    func newRangingData(_ data: String?) {
        guard isRanging else {
            stopRanging() { _ in }
            return
        }
        
        guard let data = data else {
            alertWithTitle("Error", message: "No ranging data received!")
            return
        }

        guard var measurementDict = parseData(data) else { return }
        
        // Discard measurements equal to 0. This might sometimes happen as Pozyx is not that stable
        for measurement in measurementDict {
            if measurement.value == 0 {
                measurementDict.removeValue(forKey: measurement.key)
            }
        }
                
        guard var anchors = anchors else {
            fatalError("No Anchors found")
        }
        
        // Determine which anchors are active
        var distances = [Float]()
        for i in 0..<anchors.count {
            if let distance = measurementDict["dist\(anchors[i].id)"] {
                distances.append(distance / 10)
                anchors[i].isActive = true
            } else {
                anchors[i].isActive = false
            }
        }
        
        var acceleration = [Float]()
        if let xAcc = measurementDict["xAcc"] {
            acceleration.append(xAcc / 10)
        } else {
            acceleration.append(0)
        }
        if let yAcc = measurementDict["yAcc"] {
            acceleration.append(yAcc / 10)
        } else {
            acceleration.append(0)
        }
        
        filter?.computeAlgorithm(anchors: anchors.filter({ $0.isActive }), distances: distances, acceleration: acceleration) { position in
            self.position = position
            
            self.delegate?.updatePosition(position)
            
            self.delegate?.updateActiveAnchors(anchors, distances: distances)
            
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
        if anchors != nil {
            anchors?.append(Anchor(id: id, position: CGPoint(x: x, y: y), isActive: false))
        } else {
            anchors = [Anchor(id: id, position: CGPoint(x: x, y: y), isActive: false)]
        }
    }
    
    func removeAnchorWithID(_ id: Int) {
        anchors = anchors?.filter({ $0.id != id })
    }
}

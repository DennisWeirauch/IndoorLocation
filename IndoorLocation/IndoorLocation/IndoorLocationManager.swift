//
//  IndoorLocationManager.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 14.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import Accelerate

/**
 The type of filter that is used.
 ````
 case none
 case kalman
 case particle
 ````
 */
enum FilterType: Int {
    /// No filter. A linear least squares algorithm will be executed
    case none = 0
    
    /// Extended Kalman filter
    case kalman
    
    /// Particle filter
    case particle
}

/// Structure of an anchor having an id, a position and a flag indicating whether it is currently within range.
typealias Anchor = (id: Int, position: CGPoint, isActive: Bool)

/**
 A protocol to be implemented by a ViewController. It informs the delegate about updates for the GUI.
 */
protocol IndoorLocationManagerDelegate {
    func setAnchors(_ anchors: [Anchor])
    func updateActiveAnchors(_ anchors: [Anchor], distances: [Float], acceleration: [Float])
    func updatePosition(_ position: CGPoint)
    func updateCovariance(eigenvalue1: Float, eigenvalue2: Float, angle: Float)
    func updateParticles(_ particles: [Particle])
}

/**
 Class for managing positioning. It interacts with the NetworkManager and the ViewControllers to perform all essential tasks.
 */
class IndoorLocationManager {
    
    static let shared = IndoorLocationManager()
    
    var delegate: IndoorLocationManagerDelegate?
    
    var anchors: [Anchor]?
    var filter: BayesianFilter
    var filterSettings: FilterSettings
    
    var position: CGPoint?
    var initialDistances: [Float]?
    
    var isCalibrated = false
    var isRanging = false
    
    private init() {
        filter = BayesianFilter()
        filterSettings = FilterSettings()
    }
    
    //MARK: Private API
    /**
     Parse data received from the Arduino.
     - Parameter stringData: Received data as String
     - Throws: In the case of a wrong received format
     - Returns: The received data parsed as dictionary
     */
    private func parseData(_ stringData: String) throws -> [String : Float] {
        
        // Remove carriage return
        guard let inlineStringData = stringData.components(separatedBy: "\r").first else {
            throw NSError(domain: "Error", code: 0, userInfo: [NSLocalizedDescriptionKey : "Received unexpected message from Arduino!"])
        }
        
        // Check that returned data is of expected format
        guard (inlineStringData.range(of: "([A-Za-z]+-?[0-9-]*=-?[0-9.]+&)*([A-Za-z]+-?[0-9.]*=-?[0-9.]+)", options: .regularExpression) == inlineStringData.startIndex..<inlineStringData.endIndex) else {
            throw NSError(domain: "Error", code: 0, userInfo: [NSLocalizedDescriptionKey : "Received unexpected message from Arduino!"])
        }
        
        // Split string at "&" characters
        let splitData = inlineStringData.components(separatedBy: "&")
        
        // Fill the dictionary
        var parsedData = [String : Float]()
        for component in splitData {
            let key = component.components(separatedBy: "=")[0]
            let value = Float(component.components(separatedBy: "=")[1])
            parsedData[key] = value!
        }
        return parsedData
    }
    
    /**
     A function to perform calibration. The calibration data is sent to the Arduino and the response is processed accordingly.
     - Parameter resultCallback: A closure that is called after calibration is completed or an error occurred
     - Parameter error: The error that occurred
     */
    func calibrate(resultCallback: @escaping (_ error: Error?) -> ()) {
        // Faking anchors as I'm too lazy to enter coordinates every time.
        if (anchors == nil || !(anchors!.count > 0)) {
            addAnchorWithID(Int("666D", radix: 16)!, x: 425, y: 0)
            addAnchorWithID(Int("6F21", radix: 16)!, x: 345, y: 320)
            addAnchorWithID(Int("6F59", radix: 16)!, x: 0, y: 115)
            addAnchorWithID(Int("6F51", radix: 16)!, x: 140, y: 345)
        }
        
        // Generate string of calibration data to send to the arduino.
        guard let anchors = anchors else { return }
        var anchorStringData = ""
        for (i, anchor) in anchors.enumerated() {
            // Multiply coordinates by 10 to convert from cm to mm.
            anchorStringData += "ID\(i)=\(anchor.id)&xPos\(i)=\(Int((anchor.position.x) * 10))&yPos\(i)=\(Int((anchor.position.y) * 10))"
            if (i != anchors.count - 1) {
                anchorStringData += "&"
            }
        }
        
        // Send calibration data to Arduino to calibrate Pozyx tag
        NetworkManager.shared.networkTask(task: .calibrate, data: anchorStringData) { result in
            do {
                switch result {
                    
                case .success(let data):
                    // Process successful response
                    guard let data = data else {
                        throw NSError(domain: "Error", code: 0, userInfo: [NSLocalizedDescriptionKey : "No calibration data received!"])
                    }
                    
                    let stringData = String(data: data, encoding: String.Encoding.utf8)!
                    
                    var anchorDict = try self.parseData(stringData)
                    
                    var anchors = [Anchor]()
                    var distances = [Float]()
                    
                    // Retrieve data from anchorDict. Iterate from 0 to anchorDict.count / 4 because there are 4 values
                    // for every anchor: ID, xPos, yPos, dist
                    for i in 0..<anchorDict.count / 4 {
                        guard let id = anchorDict["ID\(i)"],
                            let xPos = anchorDict["xPos\(i)"],
                            let yPos = anchorDict["yPos\(i)"],
                            let dist = anchorDict["dist\(i)"] else {
                                fatalError("Error retrieving data from anchorDict")
                        }
                        
                        if dist != 0 {
                            // Divide all units by 10 to convert from mm to cm.
                            anchors.append(Anchor(id: Int(id), position: CGPoint(x: CGFloat(xPos / 10), y: CGFloat(yPos / 10)), isActive: true))
                            distances.append(dist / 10)
                        } else {
                            anchors.append(Anchor(id: Int(id), position: CGPoint(x: CGFloat(xPos / 10), y: CGFloat(yPos / 10)), isActive: false))
                        }
                    }
                    
                    self.anchors = anchors
                    
                    self.delegate?.setAnchors(anchors)
                    
                    self.initialDistances = distances
                    
                    self.isCalibrated = true
                    
                case .failure(let error):
                    throw error
                    
                }
            } catch let error {
                resultCallback(error)
            }
            
            resultCallback(nil)
        }
    }
    
    /**
     Function used to begin ranging on the Arduino.
     - Parameter resultCallback: A closure that is called after beginning to range is successful or an error occurred
     - Parameter error: The error that occurred
     */
    func beginRanging(resultCallback: @escaping (_ error: Error?) -> ()) {
        if isCalibrated {
            NetworkManager.shared.networkTask(task: .beginRanging) { result in
                switch result {
                case .failure(let error):
                    resultCallback(error)
                case .success(_):
                    self.isRanging = true
                    resultCallback(nil)
                }
            }
        } else {
            let error = NSError(domain: "Error", code: 0, userInfo: [NSLocalizedDescriptionKey : "Calibration has to be executed first!"])
            resultCallback(error)
        }
    }
    
    /**
     Function used to stop ranging on the Arduino.
     - Parameter resultCallback: A closure that is called after stopping to range is successful or an error occurred
     - Parameter error: The error that occurred
     */
    func stopRanging(resultCallback: @escaping (Error?) -> ()) {
        NetworkManager.shared.networkTask(task: .stopRanging) { result in
            switch result {
            case .failure(let error):
                resultCallback(error)
            case .success(_):
                self.isRanging = false
                resultCallback(nil)
            }
        }
    }
    
    /**
     A function that is called by the NetworkManager when new measurement data from the Arduino is available. This function
     handles processing of received data, executes the selected filter to determine the position and tells the delegate to
     update the view accordingly.
     - Parameter data: The data that is received from the Arduino
     */
    func newRangingData(_ data: String?) {
        // Only process data if ranging is currently active. Otherwise discard data
        guard isRanging else {
            stopRanging() { _ in }
            return
        }
        
        guard let data = data,
            var anchors = anchors,
            var measurementDict = try? parseData(data) else { return }
        
        // Discard measurements equal to 0. This might sometimes happen as Pozyx is not that stable
        for measurement in measurementDict {
            if measurement.value == 0 {
                measurementDict.removeValue(forKey: measurement.key)
            }
        }
        
        // Determine which anchors are active
        var distances = [Float]()
        for i in 0..<anchors.count {
            if let distance = measurementDict["dist\(anchors[i].id)"] {
                // Divide distance by 10 to convert from mm to cm.
                distances.append(distance / 10)
                anchors[i].isActive = true
            } else {
                anchors[i].isActive = false
            }
        }
        
        var acceleration = [Float]()
        if let xAcc = measurementDict["xAcc"] {
            // Divide acceleration by 10 to convert from mm/s^2 to cm/s^2.
            acceleration.append(xAcc / 10)
        } else {
            acceleration.append(0)
        }
        if let yAcc = measurementDict["yAcc"] {
            // Adding yAcc negative because Pozyx has a right coordinate system while we have a left coordinate system here.
            // Also divide by 10 to convert from mm/s^2 to cm/s^2
            acceleration.append(-yAcc / 10)
        } else {
            acceleration.append(0)
        }
        
        // Execute the algorithm of the selected filter
        filter.executeAlgorithm(anchors: anchors.filter({ $0.isActive }), distances: distances, acceleration: acceleration) { position in
            self.position = position
            
            // Inform delegate about UI changes
            self.delegate?.updatePosition(position)
            self.delegate?.updateActiveAnchors(anchors, distances: distances, acceleration: acceleration)
            
            switch (self.filterSettings.filterType) {
            case .kalman:
                guard let filter = self.filter as? KalmanFilter else { return }
                let positionCovariance = [filter.P[0], filter.P[1], filter.P[6], filter.P[7]]
                let (eigenvalues, eigenvectors) = positionCovariance.computeEigenvalueDecomposition()
                let angle = atan(eigenvectors[2] / eigenvectors[0])
                self.delegate?.updateCovariance(eigenvalue1: eigenvalues[0], eigenvalue2: eigenvalues[1], angle: angle)
            case .particle:
                guard let filter = self.filter as? ParticleFilter else { return }
                self.delegate?.updateParticles(filter.particles)
            default:
                break
            }
        }
    }
    
    /**
     Function to add an anchor with specified parameters.
     - Parameter id: ID of the anchor as Int
     - Parameter x: x-Coordinate of the anchor
     - Parameter y: y-Coordinate of the anchor
     */
    func addAnchorWithID(_ id: Int, x: Int, y: Int) {
        if anchors != nil {
            anchors?.append(Anchor(id: id, position: CGPoint(x: x, y: y), isActive: false))
        } else {
            anchors = [Anchor(id: id, position: CGPoint(x: x, y: y), isActive: false)]
        }
    }
    
    /**
     Removes the anchor with the specified ID.
     - Parameter id: The id of the anchor to be removed
     */
    func removeAnchorWithID(_ id: Int) {
        anchors = anchors?.filter({ $0.id != id })
    }
}

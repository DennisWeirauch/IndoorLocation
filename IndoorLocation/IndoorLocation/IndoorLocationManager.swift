//
//  IndoorLocationManager.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 14.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import Accelerate

enum FilterType {
    case none
    case kalman
    case particle
}

enum AnnotationType {
    case position
    case anchor
    case particle
    case covariance
}

protocol IndoorLocationManagerDelegate {
    func updateAnnotationsFor(_ annotationType: AnnotationType)
}

class IndoorLocationManager {
    
    static let shared = IndoorLocationManager()
    
    var delegate: IndoorLocationManagerDelegate?
    
    //TODO: Refactor anchors to be a [String : CGPoint] Dict
    var anchors: [CGPoint]?
    
    var anchorIDs: [Int]?
    
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
    
    //MARK: Public API
    func calibrate() {
        NetworkManager.shared.pozyxTask(task: .calibrate) { data in
            guard let data = data else {
                print("No calibration data received!")
                return
            }
            
            let stringData = String(data: data, encoding: String.Encoding.utf8)!

            guard let anchorDict = self.parseData(stringData) else { return }

            var anchors = [CGPoint]()
            var anchorIDs = [Int]()
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
                anchors.append(CGPoint(x: xCoordinate, y: yCoordinate))
                anchorIDs.append(Int(id))
                distances.append(distance)
            }
            
            self.anchors = anchors
            self.anchorIDs = anchorIDs
            
            self.delegate?.updateAnnotationsFor(.anchor)
            
            // Least squares algorithm to get initial position
            self.position = leastSquares(anchors: anchors, distances: distances)
        }
    }
    
    func beginPositioning() {
        print("Begin positioning!")
        filter?.predict()
        NetworkManager.shared.pozyxTask(task: .beginRanging) { _ in }
    }
    
    func stopPositioning() {
        print("Stop positioning!")
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
        
        filter?.update(measurements: measurements) { position in
            self.position = position
            
            delegate?.updateAnnotationsFor(.position)
            
            switch (filterSettings.filterType) {
            case .kalman:
                delegate?.updateAnnotationsFor(.covariance)
                filter?.predict()
            case .particle:
                filter?.predict()
                delegate?.updateAnnotationsFor(.particle)
            default:
                break
            }
        }
    }
}

//
//  IndoorLocationManager.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 14.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

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

class IndoorLocationManager: NSObject {
    
    static let shared = IndoorLocationManager()
    
    var delegate: IndoorLocationManagerDelegate?
    
    var anchors: [CGPoint]?
    
    var filter: BayesianFilter? = nil
    
    var filterSettings: FilterSettings
    
    private override init() {
        filterSettings = FilterSettings(positioningModeIsRelative: true,
                                        calibrationModeIsAutomatic: true,
                                        dataSinkIsLocal: true,
                                        filterType: .none)
        //TODO: Move to FilterSettingsVC
        filter = BayesianFilter()
        
        super.init()
    }
    
    //MARK: Public API
    func calibrate() {
        NetworkManager.shared.pozyxTask(task: .calibrate) { data in
            guard let data = data else {
                print("No calibration data received!")
                return
            }
            let calibrationData = String(data: data, encoding: String.Encoding.utf8)
            // Remove carriage return and split string at "&" characters
            guard let splitData = calibrationData?.components(separatedBy: "\r")[0].components(separatedBy: "&") else {
                print("Wrong format of calibration data!")
                return
            }
            let anchor1 = CGPoint(x: Double((splitData[0].components(separatedBy: "=")[1]))!,
                                  y: Double((splitData[1].components(separatedBy: "=")[1]))!)
            let anchor2 = CGPoint(x: Double((splitData[2].components(separatedBy: "=")[1]))!,
                                  y: Double((splitData[3].components(separatedBy: "=")[1]))!)
            let anchor3 = CGPoint(x: Double((splitData[4].components(separatedBy: "=")[1]))!,
                                  y: Double((splitData[5].components(separatedBy: "=")[1]))!)
            self.anchors = [anchor1, anchor2, anchor3]
            
            self.delegate?.updateAnnotationsFor(.anchor)
        }
    }
    
    func beginPositioning() {
        print("Begin positioning!")
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

        let splitData = data.components(separatedBy: "&")
        let xPos = Double(splitData[0].components(separatedBy: "=")[1])!
        let yPos = Double(splitData[1].components(separatedBy: "=")[1])!
        let xAcc = Double(splitData[2].components(separatedBy: "=")[1])!
        let yAcc = Double(splitData[3].components(separatedBy: "=")[1])!
        let zAcc = Double(splitData[4].components(separatedBy: "=")[1])!
        
        filter?.update(measurements: [xPos, yPos, xAcc, yAcc, zAcc]) { _ in
            delegate?.updateAnnotationsFor(.position)
            
            switch (filterSettings.filterType) {
            case .kalman:
                delegate?.updateAnnotationsFor(.covariance)
            case .particle:
                delegate?.updateAnnotationsFor(.particle)
            default:
                break
            }
        }
    }
}

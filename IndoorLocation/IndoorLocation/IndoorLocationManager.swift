//
//  IndoorLocationManager.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 14.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

enum FilterType: Int {
    case none = 0
    case kalman
    case particle
}

class IndoorLocationManager: NSObject {
    
    static let sharedInstance = IndoorLocationManager()
    
    var anchors: [CGPoint]?
    
    var position: CGPoint?
    
    var filter: BayesianFilter?
    
    var filterSettings: FilterSettings
    
    private override init() {
        filter = ParticleFilter()
        
        filterSettings = FilterSettings(positioningModeIsRelative: true,
                                        calibrationModeIsAutomatic: true,
                                        dataSinkIsLocal: true,
                                        filterType: .particle)
        
        super.init()
        
        position = filter?.getPosition()
    }
    
    func calibrate(resultCallback: @escaping () -> Void) {
        NetworkManager.sharedInstance.pozyxTask(task: .calibrate) { data in
            guard let data = data else {
                print("No calibration data received")
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
            
            resultCallback()
        }
    }
    
    func beginPositioning() {
        print("Begin positioning!")
    }
    
    func stopPositioning() {
        print("Stop positioning!")
    }
}

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
        
        calibrate() //TODO: Remove calibrate call from init()
        
        position = filter?.getPosition()
    }
    
    func calibrate() {
        //TODO: Calibrate either from Pozyx or manually
        let anchor1 = CGPoint(x: 290, y: 300)
        let anchor2 = CGPoint(x: 550, y: 300)
        let anchor3 = CGPoint(x: 550, y: 30)
        
        self.anchors = [anchor1, anchor2, anchor3]
    }
    
    func beginPositioning() {
        print("Begin positioning!")
        NetworkManager.sharedInstance.setupStream()
    }
    
    func stopPositioning() {
        print("Stop positioning!")
    }
}

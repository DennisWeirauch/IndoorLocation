//
//  Settings.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 11.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

enum FilterType: Int {
    case none = 0
    case kalman
    case particle
}

class Settings: NSObject {
    var accelerationUncertainty = 25
    
    var distanceUncertainty = 50
    
    var positioningModeIsRelative = true
    
    var calibrationModeIsAutomatic = true
    
    var dataSinkIsLocal = true
    
    var filterType = FilterType.none
    
    static let sharedInstance = Settings()
    
//    func getSharedInstance() -> Settings {
//        if (self.settings == nil) {
//            self.settings = Settings()
//            return settings!
//        } else {
//            return self.settings!
//        }
//    }
    override init() {
        super.init()
    }
}

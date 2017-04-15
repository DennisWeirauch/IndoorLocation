//
//  FilterSettings.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 11.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

class FilterSettings: NSObject {
    
    var positioningModeIsRelative: Bool
    
    var calibrationModeIsAutomatic: Bool
    
    var dataSinkIsLocal: Bool
    
    var filterType: FilterType
    
    var accelerationUncertainty: Double?
    
    var distanceUncertainty: Double?
    
    init(positioningModeIsRelative: Bool,
         calibrationModeIsAutomatic: Bool,
         dataSinkIsLocal: Bool,
         filterType: FilterType,
         accelerationUncertainty: Double? = nil,
         distanceUncertainty: Double? = nil) {
        
        self.positioningModeIsRelative = positioningModeIsRelative
        self.calibrationModeIsAutomatic = calibrationModeIsAutomatic
        self.dataSinkIsLocal = dataSinkIsLocal
        self.filterType = filterType
        self.accelerationUncertainty = accelerationUncertainty
        self.distanceUncertainty = distanceUncertainty
        
        super.init()
    }
}

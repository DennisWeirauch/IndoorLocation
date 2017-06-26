//
//  FilterSettings.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 11.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

class FilterSettings {
    
    var positioningModeIsRelative = true
    
    var calibrationModeIsAutomatic = true
        
    var filterType: FilterType = .none
    
    // Filter parameters
    var accelerationUncertainty: Int = 25
    
    var distanceUncertainty: Int = 50
    
    var processingUncertainty: Int = 40
    
    var updateTime = 0.15
    
    var numberOfParticles: Int = 500
}

//
//  FilterSettings.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 11.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

class FilterSettings {
    
    var positioningModeIsRelative = true
    
    var calibrationModeIsAutomatic = true
    
    var dataSinkIsLocal = true
    
    var filterType: FilterType = .none
    
    // Kalman filter parameters
    var accelerationUncertainty: Double = 25
    
    var distanceUncertainty: Double = 50
    
    var processingUncertainty: Double = 40
    
    // Particle filter parameters
    var numberOfParticles: Int = 100
}

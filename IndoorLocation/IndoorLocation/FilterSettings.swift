//
//  FilterSettings.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 11.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

class FilterSettings {
    
    // View
    var isFloorplanVisible = false
    var areMeasurementsVisible = true
    
    // Filter
    var filterType: FilterType = .none
    
    var accelerationUncertainty: Int = 25
    var distanceUncertainty: Int = 50
    var processingUncertainty: Int = 40
    var numberOfParticles: Int = 500

    let updateTime: Float = 0.2
}

//
//  FilterSettings.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 11.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

class FilterSettings {
    
    // View settings
    var isFloorplanVisible = false
    var areMeasurementsVisible = true
    
    // Filter settings
    var filterType: FilterType = .none
    
    var accelerationUncertainty: Int = 25
    var distanceUncertainty: Int = 50
    var processingUncertainty: Int = 40
    var numberOfParticles: Int = 800
    
    /**
     The update time is necessary for the filters. It cannot be changed unless the frequency for measurements on the Arduino is changed as well.
     */
    let updateTime: Float = 0.2
}

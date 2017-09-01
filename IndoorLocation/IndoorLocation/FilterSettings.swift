//
//  FilterSettings.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 11.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

/**
 Class to store the settings for both the view and the active filter.
 */
class FilterSettings {
    
    //MARK: View settings
    var isFloorplanVisible = false
    var areMeasurementsVisible = true
    
    //MARK: Filter settings
    var filterType: FilterType = .none

    /// This models the uncertainty of the applied physical model. As the acceleration within one time step is not constant, the physical model is
    /// not perfectly precise. Its unit is in (cm/s^2)^2.
    var processUncertainty: Int = 40
    
    /// This models the uncertainty of the distance measurements. Its unit is in cm^2.
    var distanceUncertainty: Int = 50
    
    /// This models the uncertainty of the acceleration measurements. Its unit is in (cm/s^2)^2.
    var accelerationUncertainty: Int = 25
    
    var numberOfParticles: Int = 750
    
    /// The effective sample size. The larger it is chosen, the more frequently resampling is executed.
    var N_thr: Float = 100
    
    var isRegularizedPF = true
    
    /// The update time is necessary for the filters. It cannot be changed unless the frequency for measurements on the Arduino is changed as well.
    let updateTime: Float = 0.2
}

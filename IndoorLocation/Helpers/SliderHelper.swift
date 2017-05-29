//
//  SliderHelper.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 25.05.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

class SliderHelper {
    
    static func setupSlider(_ slider: UISlider,
                            value: Float,
                            minValue: Float,
                            maxValue: Float,
                            tag: Int) {
        
        slider.minimumValue = minValue
        slider.maximumValue = maxValue
        slider.value = value
        slider.tag = tag
    }
}

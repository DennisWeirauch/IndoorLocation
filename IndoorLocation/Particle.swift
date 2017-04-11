//
//  Particle.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 06/04/2017.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

class Particle: NSObject {
    var x: Double = 0.0
    var y: Double = 0.0
    
    var weight: Double = 1.0
    
    init(x: Double, y: Double, weight: Double) {
        self.x = x
        self.y = y
        self.weight = weight
    }
}

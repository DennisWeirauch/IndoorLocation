//
//  BayesianFilter.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 14.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

class BayesianFilter {
    
    var position = CGPoint(x: 0, y: 0)
    
    func predict() {}
    
    func update(measurements: [Double], successCallback: () -> Void) {
        position.x = CGFloat(measurements[0])
        position.y = CGFloat(measurements[1])
        
        successCallback()
    }
}

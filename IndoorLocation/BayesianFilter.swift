//
//  BayesianFilter.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 14.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

protocol BayesianFilter {

    func predict()
    
    func update(measurements: [Double])
    
    func getPosition() -> CGPoint
}

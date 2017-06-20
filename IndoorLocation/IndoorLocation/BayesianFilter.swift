//
//  BayesianFilter.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 14.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import Accelerate

class BayesianFilter {
    
    func computeAlgorithm(measurements: [Double], successCallback: @escaping (CGPoint) -> Void) {
        // Least squares algorithm:
        guard let anchors = IndoorLocationManager.shared.anchors else {
            fatalError("No anchors found!")
        }
        
        // Drop acceleration measurements
        let distances = Array(measurements.dropLast(2))
        
        // Compute least squares algorithm
        let position = leastSquares(anchors: anchors.map { $0.position }, distances: distances)
        
        successCallback(position)
    }
}

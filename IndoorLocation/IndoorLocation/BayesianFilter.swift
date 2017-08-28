//
//  BayesianFilter.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 14.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import Accelerate

/**
 Class to implement a Bayesian filter. Without subclassing, no filter is applied and therefore a linear least squares algorithm is executed.
 */
class BayesianFilter {
    
    /**
     Execute the algorithm of the filter to determine the agent's position.
     - Parameter anchors: The set of active anchors
     - Parameter distances: A vector containing distances to all active anchors
     - Parameter acceleration: A vector containing the accelerations in x and y direction
     - Parameter successCallback: A closure which is called when the function returns successfully
     - Parameter position: The position determined by the algorithm
     */
    func executeAlgorithm(anchors: [Anchor], distances: [Float], acceleration: [Float], successCallback: @escaping (_ position: CGPoint) -> Void) {
        // Compute least squares algorithm
        if let position = leastSquares(anchors: anchors.map { $0.position }, distances: distances) {
            successCallback(position)
        }
    }
}

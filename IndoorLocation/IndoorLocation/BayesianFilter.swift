//
//  BayesianFilter.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 14.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import Accelerate

class BayesianFilter {
    
    /**
     Execute the algorithm of the filter.
     - Parameter distances: A vector containing distances to all active anchors
     - Parameter acceleration: A vector containing the accelerations in x and y direction
     - Parameter successCallback: A closure which is called when the function returns successfully
     - Parameter position: The position determined by the algorithm
     - Parameter activeAnchors: The set of active anchors
     */
    func computeAlgorithm(distances: [Float?], acceleration: [Float], successCallback: @escaping (_ position: CGPoint, _ activeAnchors: [Anchor]) -> Void) {
        guard let anchors = IndoorLocationManager.shared.anchors else {
            fatalError("No anchors found!")
        }
        
        // Determine which anchors are active
        var activeAnchors = [Anchor]()
        var activeDistances = [Float]()
        for i in 0..<distances.count {
            if let distance = distances[i] {
                activeAnchors.append(anchors[i])
                activeDistances.append(distance)
            }
        }
        
        // Compute least squares algorithm
        if let position = leastSquares(anchors: activeAnchors.map { $0.position }, distances: activeDistances) {
            successCallback(position, activeAnchors)
        }
    }
}

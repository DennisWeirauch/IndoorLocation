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
    
    let stateDim = 4

    // Matrices
    /**
     Process matrix F representing the physical model:
     ````
     |1 0 dt 0 |
     |0 1 0  dt|
     |0 0 1  0 |
     |0 0 0  1 |
     ````
     */
    private(set) var F: [Float]
    
    /**
     Control input matrix B:
     ````
     |dt^2/2   0  |
     |   0  dt^2/2|
     |   dt    0  |
     |   0     dt |
     ````
     */
    private(set) var B: [Float]
    
    /// G is the factorization of the covariance matrix for the process noise Q
    private(set) var G: [Float]
    
    /// Q is the covariance matrix for the process noise
    private(set) var Q: [Float]
    
    /**
     R is the covariance matrix for the measurement noise. It is a numAnchors x numAnchors
     diagonal matrix with dist_sig entries on diagonal
     ````
     */
    private(set) var R: [Float]
    
    /// The inverse of matrix R
    private(set) var R_inv: [Float]
    
    /// The acceleration measurement of the previous time step as control input
    var u: [Float]
    
    /// The set of active anchors
    private(set) var activeAnchors = [Anchor]()
    
    init() {
        let settings = IndoorLocationManager.shared.filterSettings
        
        let proc_sig = Float(settings.processUncertainty)
        let dt = settings.updateTime
        
        // Initialize matrices
        F = [Float]()
        for i in 0..<stateDim {
            for j in 0..<stateDim {
                if (i == j) {
                    F.append(1)
                } else if (i + 2 == j) {
                    F.append(dt)
                } else {
                    F.append(0)
                }
            }
        }
        
        B = [Float]()
        for i in 0..<stateDim {
            for j in 0..<2 {
                if (i == j) {
                    B.append(dt ^^ 2 / 2)
                } else if (i == j + 2) {
                    B.append(dt)
                } else {
                    B.append(0)
                }
            }
        }
        
        // Compute G = B * sqrt(proc_sig)
        G = [Float](repeating: 0, count: B.count)
        var sqrtProcSig = sqrt(proc_sig)
        vDSP_vsmul(B, 1, &sqrtProcSig, &G, 1, vDSP_Length(B.count))
        
        // Transpose G
        var G_t = [Float](repeating: 0, count: G.count)
        vDSP_mtrans(G, 1, &G_t, 1, 2, vDSP_Length(stateDim))
        
        // Compute Q from Q = G * G_t
        Q = [Float](repeating: 0, count: stateDim * stateDim)
        vDSP_mmul(G, 1, G_t, 1, &Q, 1, vDSP_Length(stateDim), vDSP_Length(stateDim), 2)
        
        R = [Float]()
        R_inv = [Float]()
        
        activeAnchors = [Anchor]()
        u = [0,0]
    }
    
    /**
     Execute the algorithm of the filter to determine the agent's position.
     - Parameter anchors: The set of active anchors
     - Parameter distances: A vector containing distances to all active anchors
     - Parameter acceleration: A vector containing the accelerations in x and y direction
     - Parameter successCallback: A closure which is called when the function returns successfully
     - Parameter position: The position determined by the algorithm
     */
    func executeAlgorithm(anchors: [Anchor], distances: [Float], acceleration: [Float], successCallback: @escaping (_ position: CGPoint) -> Void) {}

    /**
     A function to update the set of active anchors. The new matrix R along with its inverse is determined.
     - Parameter anchors: The new set of active anchors
     */
    func didChangeAnchors(_ anchors: [Anchor]) {
        self.activeAnchors = anchors
        
        let pos_sig = Float(IndoorLocationManager.shared.filterSettings.distanceUncertainty)
        
        R.removeAll()
        for i in 0..<anchors.count {
            for j in 0..<anchors.count {
                if (i == j && i < anchors.count) {
                    R.append(pos_sig)
                } else {
                    R.append(0)
                }
            }
        }
        
        // Store inverse of matrix R as well to avoid computing it in every step for every particle
        R_inv = R.inverse()
    }
}

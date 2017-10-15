//
//  Particle.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 06/04/2017.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import Accelerate

class Particle {
    
    // State vector containing: [xPos, yPos, xVel, yVel]
    private(set) var state: [Float]
    var weight: Float
    
    var position: CGPoint {
        return CGPoint(x: CGFloat(state[0]), y: CGFloat(state[1]))
    }
    
    var filter: ParticleFilter
    
    init(state: [Float], weight: Float, filter: ParticleFilter) {
        self.state = state
        self.weight = weight
        self.filter = filter
    }
    
    init(fromParticle particle: Particle) {
        self.state = particle.state
        self.weight = particle.weight
        self.filter = particle.filter
    }
    
    //MARK: Public API
    /**
     Update state by drawing a value from the importance density of the particle.
     Here the transitional prior is implemented as importance density.
     - Parameter u: Acceleration vector of the last time step
     */
    func updateState(u: [Float]) {
        // Compute mean = F * state + B * u
        var B_u = [Float](repeating: 0, count: state.count)
        vDSP_mmul(filter.B, 1, u, 1, &B_u, 1, vDSP_Length(state.count), 1, 2)
        
        var mean = [Float](repeating: 0, count: state.count)
        vDSP_mmul(filter.F, 1, state, 1, &mean, 1, vDSP_Length(state.count), 1, vDSP_Length(state.count))
        
        vDSP_vadd(mean, 1, B_u, 1, &mean, 1, vDSP_Length(state.count))
        
        // Generate process noise sample
        let processNoise = [Float].randomGaussianVector(mean: [Float](repeating: 0, count: state.count), A: filter.G)
        
        // Calculate new state from state = mean + processNoise
        vDSP_vadd(mean, 1, processNoise, 1, &state, 1, vDSP_Length(state.count))
    }
    
    /**
     Update the particle's weight according to the measurement
     - Parameter anchors: The set of active anchors
     - Parameter measurements: The measurements vector containing distances to the anchors and acceleration values
     */
    func updateWeight(anchors: [Anchor], measurements: [Float]) {
        // Compute new weight = weight * p(z|x), with p(z|x) = N(z; h(x), R)
        let normalDist = computeNormalDistribution(x: measurements, m: filter.h(state), forTriangularCovariance: filter.R, withInverse: filter.R_inv)
        
        // Multiply weight with transitional prior. As weights are in log domain they have to be added
        weight = weight + normalDist
    }
    
    /**
     Regularize the particle. The particle's state vector is jittered with some noise according to matrix D.
     - Parameter D: Matrix D for which D * D_T = S (Sample covariance matrix of all particles)
     */
    func regularize(D: [Float]) {
        // Draw random sample from Gaussian kernel
        var regularizationNoise = [Float].randomGaussianVector(dim: state.count)
        
        // Multiply random sample with D
        vDSP_mmul(D, 1, regularizationNoise, 1, &regularizationNoise, 1, vDSP_Length(state.count), 1, vDSP_Length(state.count))
        
        // Multiply noise sample with optimal bandwith h_opt
        var h_opt = filter.h_opt
        vDSP_vsmul(regularizationNoise, 1, &h_opt, &regularizationNoise, 1, vDSP_Length(state.count))
        
        // Add noise to state
        vDSP_vadd(state, 1, regularizationNoise, 1, &state, 1, vDSP_Length(state.count))
    }
}

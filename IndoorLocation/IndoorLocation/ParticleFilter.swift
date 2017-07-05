//
//  ParticleFilter.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 06/04/2017.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import Accelerate

class Particle {
    
    // State vector containing: [xPos, yPos, xVel, yVel, xAcc, yAcc]
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
    // Update state by drawing a value from the importance density of this particle
    func updateState() {
        
        // Compute mean = F * state
        var mean = [Float](repeating: 0, count: state.count)
        vDSP_mmul(filter.F, 1, state, 1, &mean, 1, vDSP_Length(state.count), 1, vDSP_Length(state.count))
        
        state = [Float].randomGaussianVector(mean: mean, A: filter.G)
    }
    
    func updateWeight(measurements: [Float]) {
        
        // Compute new weight = weight * p(z|x), where is the transitional prior p(z|x) = N(z; h(x), R)
        let normalDist = computeNormalDistribution(x: measurements, m: h(state), forTriangularCovariance: filter.R, withInverse: filter.R_inv)
        weight = weight * normalDist
    }
    
    func regularize(D: [Float]) {
        var regularizationNoise = [Float].randomGaussianVector(dim: state.count)
        vDSP_mmul(D, 1, regularizationNoise, 1, &regularizationNoise, 1, vDSP_Length(state.count), 1, vDSP_Length(state.count))
        var h_opt = filter.h_opt
        vDSP_vsmul(regularizationNoise, 1, &h_opt, &regularizationNoise, 1, vDSP_Length(regularizationNoise.count))
        vDSP_vadd(state, 1, regularizationNoise, 1, &state, 1, vDSP_Length(state.count))
    }
    
    //MARK: Private API
    private func h(_ state: [Float]) -> [Float] {
        guard let anchors = IndoorLocationManager.shared.anchors else {
            fatalError("No anchors found!")
        }
        
        let anchorCoordinates = anchors.map { $0.position }
        
        let xPos = state[0]
        let yPos = state[1]
        let xAcc = state[4]
        let yAcc = state[5]
        
        var h = [Float]()
        for i in 0..<anchors.count {
            h.append(sqrt((Float(anchorCoordinates[i].x) - xPos) ^^ 2 + (Float(anchorCoordinates[i].y) - yPos) ^^ 2))
        }
        h.append(xAcc)
        h.append(yAcc)
        
        return h
    }
}

class ParticleFilter: BayesianFilter {
    
    let numberOfParticles: Int
    
    private(set) var particles: [Particle]
    
    // Matrices
    private(set) var F: [Float]
    private(set) var G: [Float]
    private(set) var Q: [Float]
    private(set) var R: [Float]
    private(set) var R_inv: [Float]
    
    var h_opt: Float {
        return 0.5 ^^ 0.1 * Float(numberOfParticles) ^^ -0.1
    }
    
    // Using a semaphore to make sure that only one thread can execute the algorithm at each time instance
    let semaphore = DispatchSemaphore(value: 1)
    
    init(position: CGPoint) {
        
        let settings = IndoorLocationManager.shared.filterSettings
        
        let acc_sig = Float(settings.accelerationUncertainty)
        let pos_sig = Float(settings.distanceUncertainty)
        var proc_fac = sqrt(Float(settings.processingUncertainty))
        let dt = settings.updateTime
        numberOfParticles = settings.numberOfParticles
        
        guard let anchors = IndoorLocationManager.shared.anchors else {
            fatalError("No anchors found!")
        }
        
        // Initialize matrices
        // F is a 6x6 matrix with '1's in main diagonal, 'dt's in second positive side diagonal and '(dt^2)/2's in fourth positive side diagonal
        F = [Float]()
        for i in 0..<6 {
            for j in 0..<6 {
                if (i == j) {
                    F.append(1)
                } else if (i + 2 == j) {
                    F.append(dt)
                } else if (i + 4 == j) {
                    F.append(dt ^^ 2 / 2)
                } else {
                    F.append(0)
                }
            }
        }
        
        // G is a 6x2 matrix with '(dt^2)/2's in main diagonal, 'dt's in second negative side diagonal and '1's in fourth negative side diagonal
        G = [Float]()
        for i in 0..<6 {
            for j in 0..<2 {
                if (i == j) {
                    G.append(dt ^^ 2 / 2)
                } else if (i == j + 2) {
                    G.append(dt)
                } else if (i == j + 4) {
                    G.append(1)
                } else {
                    G.append(0)
                }
            }
        }
        
        // Multiply G with the square root of processing factor
        vDSP_vsmul(G, 1, &proc_fac, &G, 1, vDSP_Length(G.count))
        
        // Compute Q from Q = G * G_t. Q is a 6x6 matrix
        Q = [Float](repeating: 0, count: 36)
        vDSP_mmul(G, 1, G, 1, &Q, 1, 6, 6, 1)
        
        // R is a (numAnchors + 2)x(numAnchors + 2) diagonal matrix with 'pos_sig's in first numAnchors entries and 'acc_sig's in the remaining entries
        R = [Float]()
        for i in 0..<anchors.count + 2 {
            for j in 0..<anchors.count + 2 {
                if (i == j && i < anchors.count) {
                    R.append(pos_sig)
                } else if (i == j && i >= anchors.count) {
                    R.append(acc_sig)
                } else {
                    R.append(0)
                }
            }
        }
        
        // Store inverse of matrix R as well to avoid computing it in every step for every particle
        R_inv = R.inverse()
        
        particles = [Particle]()
        
        super.init()
        
        // Initialize particles with randomized positions
        for _ in 0..<numberOfParticles {
            let (r1, r2) = Float.randomGaussian()
            let randomizedState = [Float(position.x) + pos_sig * r1, Float(position.y) + pos_sig * r2, 0, 0, 0, 0]
            let particle = Particle(state: randomizedState, weight: 1 / Float(numberOfParticles), filter: self)
            particles.append(particle)
        }
    }
    
    override func computeAlgorithm(measurements: [Float], successCallback: @escaping (CGPoint) -> Void) {
        
        // Request semaphore. Wait in case the algorithm is still in execution
        semaphore.wait()
        
        // Using a DispatchGroup to continue execution of algorithm only after the functions on each particle were executed
        let dispatchGroup = DispatchGroup()
        for particle in particles {
            // Execute functions on particles concurrently
            DispatchQueue.global().async(group: dispatchGroup) {
                // Draw new state from importance density
                particle.updateState()
                
                // Evaluate the importance weight up to a normalizing constant
                particle.updateWeight(measurements: measurements)
            }
        }
        
        dispatchGroup.notify(queue: DispatchQueue.global()) {
            // Normalize weights of all particles
            let totalWeight = self.particles.reduce(0, { $0 + $1.weight })
            self.particles.forEach { $0.weight = $0.weight / totalWeight }
            
            // Determine mean state
            var meanState = [Float](repeating: 0, count: 6)
            for particle in self.particles {
                var weightedState = [Float](repeating: 0, count: particle.state.count)
                vDSP_vsmul(particle.state, 1, &particle.weight, &weightedState, 1, vDSP_Length(meanState.count))
                vDSP_vadd(meanState, 1, weightedState, 1, &meanState, 1, vDSP_Length(meanState.count))
            }
            
            // Determine empirical covariance matrix S
            var S = [Float]()
            let sumOfSquaredWeights = self.particles.reduce(0, { $0 + $1.weight ^^ 2 })
            for j in 0..<meanState.count {
                for k in 0..<meanState.count {
                    let s_jk = (1 / 1 - sumOfSquaredWeights) * self.particles.reduce(0, { $0 + $1.weight * ($1.state[j] - meanState[j]) * ($1.state[k] - meanState[k]) })
                    S.append(s_jk)
                }
            }
            
            let D = S.computeCholeskyDecomposition()
            
            // Execute resampling algorithm
            self.resample()
            
            // Regularize
            self.particles.forEach { $0.regularize(D: D) }
            
            // Determine current position
            var meanX: Float = 0
            var meanY: Float = 0
            for particle in self.particles {
                meanX += Float(particle.position.x) * particle.weight
                meanY += Float(particle.position.y) * particle.weight
            }
            
            if (meanX.isNaN || meanY.isNaN) {
                fatalError("Algorithm produced error!")
            }
            
            // Release semaphore
            self.semaphore.signal()
            
            DispatchQueue.main.async(){
                successCallback(CGPoint(x: CGFloat(meanX), y: CGFloat(meanY)))
            }
        }
    }
    
    //MARK: Private API
    private func resample() {
        var resampledParticles = [Particle]()
        let N_inv = 1 / Float(numberOfParticles)

        // Construct cumulative sum of weights (CSW) c
        var c = [particles[0].weight]
        for i in 1..<particles.count {
            c.append(c.last! + particles[i].weight)
        }
        var i = 0
        // Draw a starting point u_0 from uniform distribution U[0, 1/numberOfParticles]
        let u_0 = Float.random(upperBound: N_inv)
        var u = [Float]()
        
        for j in 0..<numberOfParticles {
            // Move along the CSW
            u.append(u_0 + (N_inv) * Float(j))
            
            while (u[j] > c[i]) {
                i += 1
            }
            // Assign new sample and update weight
            particles[i].weight = N_inv
            resampledParticles.append(Particle(fromParticle: particles[i]))
        }
        
        particles = resampledParticles
    }
}

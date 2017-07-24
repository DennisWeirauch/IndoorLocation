//
//  ParticleFilter.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 06/04/2017.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import Accelerate

class ParticleFilter: BayesianFilter {
    
    var numberOfParticles: Int
    let stateDim = 6
    
    internal(set) var particles: [Particle]
    
    // Matrices
    internal(set) var F: [Float]
    internal(set) var G: [Float]
    internal(set) var Q: [Float]
    internal(set) var R: [Float]
    internal(set) var R_inv: [Float]
    
    var h_opt: Float {
        return 0.5 ^^ 0.1 * Float(numberOfParticles) ^^ -0.1
    }
    
    var activeAnchors = [Anchor]()
    
    // Using a semaphore to make sure that only one thread can execute the algorithm at each time instance
    let semaphore = DispatchSemaphore(value: 1)
    
    init(anchors: [Anchor], distances: [Float]) {
        activeAnchors = anchors
        
        let settings = IndoorLocationManager.shared.filterSettings
        
        let pos_sig = Float(settings.distanceUncertainty)
        let acc_sig = Float(settings.accelerationUncertainty)
        var proc_fac = sqrt(Float(settings.processingUncertainty))
        let dt = settings.updateTime
        numberOfParticles = settings.numberOfParticles
        
        // Initialize matrices
        // F is a stateDim x stateDim matrix representing the physical model
        F = [Float]()
        for i in 0..<stateDim {
            for j in 0..<stateDim {
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
        
        // G is a stateDim x 2 matrix with '(dt^2)/2's in main diagonal, 'dt's in second negative side diagonal and '1's in fourth negative side diagonal
        G = [Float]()
        for i in 0..<stateDim {
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
        
        var G_t = [Float](repeating: 0, count: G.count)
        vDSP_mtrans(G, 1, &G_t, 1, 2, vDSP_Length(stateDim))
        
        // Compute Q from Q = G * G_t. Q is a stateDim x stateDim covariance matrix for the process noise
        Q = [Float](repeating: 0, count: stateDim * stateDim)
        vDSP_mmul(G, 1, G_t, 1, &Q, 1, vDSP_Length(stateDim), vDSP_Length(stateDim), 1)
        
        // R is a (numAnchors + 2) x (numAnchors + 2) covariance matrix for the measurement noise
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
        
        if let position = leastSquares(anchors: activeAnchors.map { $0.position }, distances: distances) {
            // If a least squares estimate is available, use it to initialize all particles around that position.
            for _ in 0..<numberOfParticles {
                let (r1, r2) = Float.randomGaussian()
                let randomizedState = [Float(position.x) + pos_sig * r1, Float(position.y) + pos_sig * r2, 0, 0, 0, 0]
                let particle = Particle(state: randomizedState, weight: log(1 / Float(numberOfParticles)), filter: self)
                particles.append(particle)
            }
        } else {
            // If there were not enough anchors for a least squares estimate, initialize all particles on a circle around one anchor.
            // Determine the nearest distance and the associated anchor
            let nearestDistance = distances.min()!
            let nearestAnchor = activeAnchors[distances.index(of: nearestDistance)!]
            
            for _ in 0..<numberOfParticles {
                let phi = Float.random(upperBound: 2 * Float.pi)
                let (r1, _) = Float.randomGaussian()
                let radius = nearestDistance + pos_sig * r1
                let randomizedState = [cos(phi) * radius + Float(nearestAnchor.position.x), sin(phi) * radius + Float(nearestAnchor.position.y), 0, 0, 0, 0]
                let particle = Particle(state: randomizedState, weight: log(1 / Float(numberOfParticles)), filter: self)
                particles.append(particle)
            }
        }

    }
    
    override func computeAlgorithm(anchors: [Anchor], distances: [Float], acceleration: [Float], successCallback: @escaping (_ position: CGPoint) -> Void) {
        // Request semaphore. Wait in case the algorithm is still in execution
        semaphore.wait()
        
        if (activeAnchors.map { $0.id } != anchors.map { $0.id }) {
            didChangeAnchors(anchors)
        }
        
        // Using a DispatchGroup to continue execution of algorithm only after the functions on each particle were executed
        let dispatchGroup = DispatchGroup()
        for particle in particles {
            // Execute functions on particles concurrently
            DispatchQueue.global().async(group: dispatchGroup) {
                // Draw new state from importance density
                particle.updateState()
                
                let measurements = distances + acceleration
                // Evaluate the importance weight up to a normalizing constant
                particle.updateWeight(anchors: anchors, measurements: measurements)
            }
        }
        
        dispatchGroup.notify(queue: DispatchQueue.global()) {
            
            // Rescale weights for numerical stability
            let maxWeight = self.particles.map { $0.weight }.max()!
            self.particles.forEach { $0.weight = $0.weight - maxWeight }
        
            // Transform weights to normal domain
            self.particles.forEach { $0.weight = exp($0.weight) }
            
            // Normalize weights of all particles
            let totalWeight = self.particles.reduce(0, { $0 + $1.weight })
            self.particles.forEach { $0.weight = $0.weight / totalWeight }
            
            // Determine mean state
            var meanState = [Float](repeating: 0, count: self.stateDim)
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
            
            var D = S.computeCholeskyDecomposition()
            if D == nil {
                // Algorithm could not be executed because matrix was not positive definite. Make matrix positive definite and execute algorithm again
                let A = S.positiveDefiniteMatrix()
                D = A.computeCholeskyDecomposition()
            }
            
            // Execute resampling algorithm
            self.resample()
            
            // Make sure a valid D has been computed and execute regularization
            if let D = D {
                // Regularize
                self.particles.forEach { $0.regularize(D: D) }
            }
            // Determine position
            let position = self.particles.reduce((x: Float(0), y: Float(0)), { ($0.x + Float($1.position.x) * $1.weight, $0.y + Float($1.position.y) * $1.weight) })
            
            // Transform weights to log domain
            self.particles.forEach { $0.weight = log($0.weight) }
            
            // Release semaphore
            self.semaphore.signal()
            
            // Return with position on main thread
            DispatchQueue.main.async(){
                successCallback(CGPoint(x: CGFloat(position.x), y: CGFloat(position.y)))
            }
        }
    }
    
    //MARK: Private API
    /**
     Execute the resampling algorithm to reduce degeneracy of particles. Particles with a small weight are likely to be discarded while
     particles with higher weight are likely to be duplicated. In the end all particles are assigned equal weights as 1/N.
     */
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
            
            while (u[j] > c[i] && i < numberOfParticles - 1) {
                i += 1
            }
            // Assign new sample and update weight
            particles[i].weight = N_inv
            resampledParticles.append(Particle(fromParticle: particles[i]))
        }
        
        particles = resampledParticles
    }
    
    /**
     A function to update the set of active anchors. The new matrix R along with its inverse is determined.
     - Parameter anchors: The new set of active anchors
     */
    private func didChangeAnchors(_ anchors: [Anchor]) {
        self.activeAnchors = anchors
        
        let acc_sig = Float(IndoorLocationManager.shared.filterSettings.accelerationUncertainty)
        let pos_sig = Float(IndoorLocationManager.shared.filterSettings.distanceUncertainty)
        
        // R is a (numAnchors + 2) x (numAnchors + 2) covariance matrix for the measurement noise
        R.removeAll()
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
    }
}

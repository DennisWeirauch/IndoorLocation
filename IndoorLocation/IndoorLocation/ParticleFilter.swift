//
//  ParticleFilter.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 06/04/2017.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import Accelerate

/**
 Class that implements a Particle filter.
 */
class ParticleFilter: BayesianFilter {
    
    var numberOfParticles: Int
    let stateDim = 4
    
    // The set of particles
    private(set) var particles: [Particle]
    
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
     Process matrix A:
     ````
     |dt^2/2   0  |
     |   0  dt^2/2|
     |   dt    0  |
     |   0     dt |
     ````
     */
    private(set) var A: [Float]
    
    //TODO: Find name for G
    private(set) var G: [Float]
    
    /**
     R is the covariance matrix for the measurement noise. It is a (numAnchors + 2) x (numAnchors + 2) diagonal matrix of the form:
     ````
     |D_N 0|
     | 0  A|, with
     D_N = dist_sig * I_N, I_N being the identity matrix of order N
     A = acc_sig * I_2
     ````
     */
    private(set) var R: [Float]
    
    /// The inverse of matrix R
    private(set) var R_inv: [Float]
    
    /// The optimal bandwith for the regularization step
    var h_opt: Float {
        return pow(4/(Float(stateDim) + 2), 1/(Float(stateDim) + 4)) * pow(Float(numberOfParticles), -1/(Float(stateDim) + 4))
    }
    
    /// The acceleration measurement of the previous time step
    private var u: [Float]
    
    var activeAnchors = [Anchor]()
    
    // Using a semaphore to make sure that only one thread can execute the algorithm at each time instance
    let semaphore = DispatchSemaphore(value: 1)
    
    init?(anchors: [Anchor], distances: [Float]) {
        // Make sure at least one anchor is within range. Otherwise initialization is not possible.
        guard anchors.count > 0 else { return nil }

        activeAnchors = anchors
        
        let settings = IndoorLocationManager.shared.filterSettings
        
        let proc_sig = Float(settings.processUncertainty)
        let dist_sig = Float(settings.distanceUncertainty)
        numberOfParticles = settings.numberOfParticles
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
        
        A = [Float]()
        for i in 0..<stateDim {
            for j in 0..<2 {
                if (i == j) {
                    A.append(dt ^^ 2 / 2)
                } else if (i == j + 2) {
                    A.append(dt)
                } else {
                    A.append(0)
                }
            }
        }
        
        // Compute G = A * sqrt(proc_sig)
        G = [Float](repeating: 0, count: A.count)
        var sqrtProcSig = sqrt(proc_sig)
        vDSP_vsmul(A, 1, &sqrtProcSig, &G, 1, vDSP_Length(A.count))
        
        R = [Float]()
        for i in 0..<anchors.count {
            for j in 0..<anchors.count {
                if (i == j && i < anchors.count) {
                    R.append(dist_sig)
                } else {
                    R.append(0)
                }
            }
        }
        
        // Store inverse of matrix R as well to avoid computing it in every step for every particle
        R_inv = R.inverse()
        
        particles = [Particle]()
        
        u = [0, 0]
        
        super.init()
        
        // If at least 3 anchors are active for the linear least squares algorithm to work, we use it to initialize all particles around that position.
        if let position = leastSquares(anchors: activeAnchors.map { $0.position }, distances: distances) {
            for _ in 0..<numberOfParticles {
                let (r1, r2) = Float.randomGaussian()
                let randomizedPosition = [Float(position.x) + dist_sig * r1, Float(position.y) + dist_sig * r2]
                let randomizedState = randomizedPosition + [Float](repeating: 0, count: stateDim - 2)
                let particle = Particle(state: randomizedState, weight: log(1 / Float(numberOfParticles)), filter: self)
                particles.append(particle)
            }
        } else {
            // If there were not enough anchors for the linear least squares algorithm, all particles are initialized on a circle around one anchor.
            // Determine the nearest distance and the associated anchor
            let nearestDistance = distances.min()!
            let nearestAnchor = activeAnchors[distances.index(of: nearestDistance)!]
            
            for _ in 0..<numberOfParticles {
                let phi = Float.random(upperBound: 2 * Float.pi)
                let (r1, _) = Float.randomGaussian()
                let radius = nearestDistance + dist_sig * r1
                let randomizedPosition = [cos(phi) * radius + Float(nearestAnchor.position.x), sin(phi) * radius + Float(nearestAnchor.position.y)]
                let randomizedState = randomizedPosition + [Float](repeating: 0, count: stateDim - 2)
                let particle = Particle(state: randomizedState, weight: log(1 / Float(numberOfParticles)), filter: self)
                particles.append(particle)
            }
        }
    }
    
    override func executeAlgorithm(anchors: [Anchor], distances: [Float], acceleration: [Float], successCallback: @escaping (_ position: CGPoint) -> Void) {
        // Request semaphore. Wait in case the algorithm is still in execution
        semaphore.wait()
        
        // Determine whether the active anchors have changed
        if (activeAnchors.map { $0.id } != anchors.map { $0.id }) {
            didChangeAnchors(anchors)
        }
        
        // Using a DispatchGroup to continue execution of algorithm only after the functions on each particle were executed
        let dispatchGroup = DispatchGroup()
        for particle in particles {
            // Execute the following functions on all particles concurrently
            DispatchQueue.global().async(group: dispatchGroup) {
                // Execute prediction step
                particle.updateState(u: self.u)
                // Execute update step
                particle.updateWeight(anchors: anchors, measurements: distances)
            }
        }
        
        // Execute the following code after the previous 2 steps have been executed on all particles
        dispatchGroup.notify(queue: DispatchQueue.global()) {
            // Store current acceleration for next iteration
            self.u = acceleration

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
                    if k < j {
                        let s_jk = S[k * meanState.count + j]
                        S.append(s_jk)
                    } else {
                        let s_jk = (1 / 1 - sumOfSquaredWeights) * self.particles.reduce(0, { $0 + $1.weight * ($1.state[j] - meanState[j]) * ($1.state[k] - meanState[k]) })
                        S.append(s_jk)
                    }
                }
            }

            var D = S.computeCholeskyDecomposition()
            if D == nil {
                // Algorithm could not be executed because matrix was not positive definite. Make matrix positive definite and execute algorithm again
                let A = S.positiveDefiniteMatrix()
                D = A.computeCholeskyDecomposition()
            }
            
            //TODO: Check if N_thr should be defined as the algorithm from the book says so
//            let N_eff = 1 / sumOfSquaredWeights
//            if N_eff < Float(self.numberOfParticles) / 10 {
                // Execute resampling algorithm
                self.resample()
//            }
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

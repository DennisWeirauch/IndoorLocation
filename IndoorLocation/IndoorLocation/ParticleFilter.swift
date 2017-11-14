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
    
    /// The inverse of matrix R
    private(set) var R_inv: [Float]
    
    // The set of particles
    private(set) var particles: [Particle]
    
    /// The optimal bandwith for the regularization step
    var h_opt: Float {
        return pow(4/(Float(stateDim) + 2), 1/(Float(stateDim) + 4)) * pow(Float(numberOfParticles), -1/(Float(stateDim) + 4))
    }
    
    init?(anchors: [Anchor], distances: [Float]) {
        // Make sure at least one anchor is within range. Otherwise initialization is not possible.
        guard anchors.count > 0 else { return nil }
        
        let settings = IndoorLocationManager.shared.filterSettings
        numberOfParticles = settings.numberOfParticles
        let dist_sig = Float(settings.distanceUncertainty)
        
        particles = [Particle]()
        
        R_inv = [Float]()
        
        super.init()
        
        didChangeAnchors(anchors)
        
        // If at least 3 anchors are active for the linear least squares algorithm to work, we use it to initialize all particles around that position.
        if let position = linearLeastSquares(anchors: activeAnchors.map { $0.position }, distances: distances) {
            for _ in 0..<numberOfParticles {
                let (r1, r2) = Float.randomGaussian()
                let randomizedPosition = [Float(position.x) + sqrt(dist_sig) * r1, Float(position.y) + sqrt(dist_sig) * r2]
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
                let radius = nearestDistance + sqrt(dist_sig) * r1
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

            // Rescale weights for numerical stability and transform to normal domain. Also determine total weight
            let maxWeight = self.particles.map { $0.weight }.max()!
            var totalWeight = Float(0)
            for particle in self.particles {
                particle.weight = exp(particle.weight - maxWeight)
                totalWeight += particle.weight
            }
            
            // Normalize weights of all particles, determine position and determine effective sample size
            var position = (x: Float(0), y: Float(0))
            var N_eff_inv = Float(0)
            for particle in self.particles {
                particle.weight = particle.weight / totalWeight
                position.x += Float(particle.position.x) * particle.weight
                position.y += Float(particle.position.y) * particle.weight
                N_eff_inv += particle.weight ^^ 2
            }

            // Execute resampling if N_eff is below N_thr
            let N_eff = 1 / N_eff_inv
            if N_eff < IndoorLocationManager.shared.filterSettings.N_thr {
                if (IndoorLocationManager.shared.filterSettings.particleFilterType == .regularized) {
                    // Execute regularization step
                    self.regularize()
                } else {
                    // Execute resampling step
                    self.resample()
                }
            }
            
            // Transform weights back to log domain
            self.particles.forEach { $0.weight = log($0.weight) }
            
            // Release semaphore
            self.semaphore.signal()
            
            // Return with position on main thread
            DispatchQueue.main.async(){
                successCallback(CGPoint(x: CGFloat(position.x), y: CGFloat(position.y)))
            }
        }
    }
    
    override func didChangeAnchors(_ anchors: [Anchor]) {
        super.didChangeAnchors(anchors)
        
        // Store inverse of matrix R as well to avoid computing it in every step for every particle
        R_inv = R.inverse()
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
    
    private func regularize() {
        // Determine mean state
        var meanState = [Float](repeating: 0, count: self.stateDim)
        var sumOfSquaredWeights = Float(0)
        for particle in self.particles {
            var weightedState = [Float](repeating: 0, count: particle.state.count)
            vDSP_vsmul(particle.state, 1, &particle.weight, &weightedState, 1, vDSP_Length(meanState.count))
            vDSP_vadd(meanState, 1, weightedState, 1, &meanState, 1, vDSP_Length(meanState.count))
            
            sumOfSquaredWeights += particle.weight ^^ 2
        }
        
        // Determine empirical covariance matrix S
        var S = [Float]()
        for j in 0..<meanState.count {
            for k in 0..<meanState.count {
                if k < j {
                    // As covariance matrix is symmetric, take already determined value
                    let s_jk = S[k * meanState.count + j]
                    S.append(s_jk)
                } else {
                    var s_jk = Float(0)
                    for particle in self.particles {
                        s_jk += particle.weight * (particle.state[j] - meanState[j]) * (particle.state[k] - meanState[k])
                    }
                    s_jk *= (1 / 1 - sumOfSquaredWeights)
                    S.append(s_jk)
                }
            }
        }
        
        // Factorize S, such that D * D' = S. For this the eigenvalue decomposition of S is determined with S = Q * Λ * Q' = Q * Λ^(1/2) * Λ^(1/2) * Q'.
        // Such that D = Q * Λ^(1/2)
        var (eigenvalues, Q) = S.computeEigenvalueDecomposition()
        
        // Fix small negative eigenvalues that might occur due to numerical errors
        eigenvalues = eigenvalues.map { $0 < 0 ? 0 : $0 }
        
        var Λ = [Float]()
        for i in 0..<meanState.count {
            for j in 0..<meanState.count {
                if (i == j) {
                    Λ.append(sqrt(eigenvalues[i]))
                } else {
                    Λ.append(0)
                }
            }
        }
        
        var D = [Float](repeating: 0, count: Q.count)
        vDSP_mmul(Q, 1, Λ, 1, &D, 1, vDSP_Length(meanState.count), vDSP_Length(meanState.count), vDSP_Length(meanState.count))
        
        // Execute resampling step
        self.resample()
        
        // Execute regularization on all particles
        self.particles.forEach { $0.regularize(D: D) }
    }
}

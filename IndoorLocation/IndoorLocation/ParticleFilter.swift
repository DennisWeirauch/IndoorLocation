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
    private var state: [Double]
    var weight: Double
    
    var position: CGPoint {
        return CGPoint(x: state[0], y: state[1])
    }
    
    var filter: ParticleFilter
    
    init(state: [Double], weight: Double, filter: ParticleFilter) {
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
        var mean = [Double](repeating: 0, count: 6)
        vDSP_mmulD(filter.F, 1, state, 1, &mean, 1, 6, 1, 6)
        
        state = [Double].randomGaussianVector(mean: mean, A: filter.G)
    }
    
    func updateWeight(measurements: [Double]) {
        
        // Compute new weight = weight * p(z|x), where p(z|x) = N(z; h(x), R)
        let normalDist = computeNormalDistribution(x: measurements, m: h(state), forTriangularCovariance: filter.R, withInverse: filter.R_inv)
        weight = weight * normalDist
    }
    
    //MARK: Private API
    private func h(_ state: [Double]) -> [Double] {
        guard let anchors = IndoorLocationManager.shared.anchors else {
            fatalError("No anchors found!")
        }
        
        let anchorCoordinates = anchors.map { $0.position }
        
        let xPos = state[0]
        let yPos = state[1]
        let xAcc = state[4]
        let yAcc = state[5]
        
        var h = [Double]()
        for i in 0..<anchors.count {
            h.append(sqrt(pow(Double(anchorCoordinates[i].x) - xPos, 2) + pow(Double(anchorCoordinates[i].y) - yPos, 2)))
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
    private(set) var F: [Double]
    private(set) var G: [Double]
    private(set) var R: [Double]
    private(set) var R_inv: [Double]
    
    init(position: CGPoint) {
        
        let settings = IndoorLocationManager.shared.filterSettings
        
        let acc_sig = Double(settings.accelerationUncertainty)
        let pos_sig = Double(settings.distanceUncertainty)
        let proc_fac = sqrt(Double(settings.processingUncertainty))
        let dt = settings.updateTime
        numberOfParticles = settings.numberOfParticles
        
        guard let anchors = IndoorLocationManager.shared.anchors else {
            fatalError("No anchors found!")
        }
        
        // Initialize matrices
        // F is a 6x6 matrix with '1's in main diagonal, 'dt's in second positive side diagonal and '(dt^2)/2's in fourth positive side diagonal
        F = [Double]()
        for i in 0..<6 {
            for j in 0..<6 {
                if (i == j) {
                    F.append(1)
                } else if (i + 2 == j) {
                    F.append(dt)
                } else if (i + 4 == j) {
                    F.append(pow(dt, 2)/2)
                } else {
                    F.append(0)
                }
            }
        }
        
        // G is a 6x2 matrix with '(dt^2)/2's in main diagonal and '1's in second and fourth negative side diagonal
        G = [Double]()
        for i in 0..<6 {
            for j in 0..<2 {
                if (i == j) {
                    G.append(proc_fac)
                } else if (i == j + 2 || i == j + 4) {
                    G.append(1)
                } else {
                    G.append(0)
                }
            }
        }
        
        // R is a (numAnchors + 2)x(numAnchors + 2) diagonal matrix with 'pos_sig's in first numAnchors entries and 'acc_sig's in the remaining entries
        R = [Double]()
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
        
        // Store inverse of matrix R as well to avoid computing it in every step for every particle.
        R_inv = R.invert()
        
        particles = [Particle]()
        
        super.init()
        
        for _ in 0..<numberOfParticles {
            let particle = Particle(state: [Double(position.x), Double(position.y), 0, 0, 0, 0], weight: 1 / Double(numberOfParticles), filter: self)
            particles.append(particle)
        }
    }
    
    override func computeAlgorithm(measurements: [Double], successCallback: @escaping (CGPoint) -> Void) {
        var totalWeight = 0.0
        let dispatchGroup = DispatchGroup()
        for particle in particles {
            DispatchQueue.global().async(group: dispatchGroup) {
                // Draw new state from importance density
                particle.updateState()
                
                // Evaluate the importance weight up to a normalizing constant
                particle.updateWeight(measurements: measurements)
                totalWeight += particle.weight
            }
        }
        
        dispatchGroup.notify(queue: DispatchQueue.global()) {
            // Normalize weights of all particles
            self.particles.forEach { $0.weight = $0.weight / totalWeight }
            
            // Execute resampling algorithm
            self.resample()
            
            // Determine current position
            var meanX = 0.0
            var meanY = 0.0
            for particle in self.particles {
                meanX += Double(particle.position.x) * particle.weight
                meanY += Double(particle.position.y) * particle.weight
            }
            
            DispatchQueue.main.async(){
                successCallback(CGPoint(x: meanX, y: meanY))
            }
        }
    }
    
    //MARK: Private API
    private func resample() {
        var resampledParticles = [Particle]()
        let N_inv = 1 / Double(numberOfParticles)

        // Construct cumulative sum of weights (CSW) c
        var c = [particles[0].weight]
        for i in 1..<particles.count {
            c.append(c.last! + particles[i].weight)
        }
        var i = 0
        // Draw a starting point u_0 from uniform distribution U[0, 1/numberOfParticles]
        let u_0 = Double.random(upperBound: N_inv)
        var u = [Double]()
        
        for j in 0..<numberOfParticles {
            // Move along the CSW
            u.append(u_0 + (N_inv) * Double(j))
            
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

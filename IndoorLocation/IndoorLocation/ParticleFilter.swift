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
    var state: [Double]
    var weight: Double
    
    // Matrices
    var F: [Double]
    var G: [Double]
    var R: [Double]
    
    init?(state: [Double], weight: Double) {
        
        let settings = IndoorLocationManager.shared.filterSettings
        
        let acc_sig = Double(settings.accelerationUncertainty)
        let pos_sig = Double(settings.distanceUncertainty)
        var proc_fac = sqrt(Double(settings.processingUncertainty))
        let dt = settings.updateTime
        
        guard let anchors = IndoorLocationManager.shared.anchors else {
            print("No anchors found. Calibration has to be executed first!")
            return nil
        }
        
        self.state = state
        self.weight = weight
        
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
        
        // G is a 6x2 matrix with '(dt^2)/2's in main diagonal, 'dt's in second negative side diagonal and '1's in fourth negative side diagonal
        G = [Double]()
        for i in 0..<6 {
            for j in 0..<2 {
                if (i == j) {
                    G.append(pow(dt, 2)/2)
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
        vDSP_vsmulD(G, 1, &proc_fac, &G, 1, vDSP_Length(G.count))
        
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
    }
    
    //MARK: Public API
    // Update state by drawing a value from the importance density of this particle
    func updateState() {
        
        // Compute mean = F * state
        var mean = [Double](repeating: 0, count: 6)
        vDSP_mmulD(F, 1, state, 1, &mean, 1, 6, 1, 6)
        
        state = randomGaussianVector(mean: mean, A: G)
    }
    
    func updateWeight(measurements: [Double]) {
        
        // Compute new weight = weight * p(z|x), where p(z|x) = N(z; h(x), R)
        weight = weight * computeNormalDistribution(x: measurements, m: h(state), forTriangularCovariance: R)
    }
    
    //MARK: Private API
    private func h(_ state: [Double]) -> [Double] {
        guard let anchors = IndoorLocationManager.shared.anchors else {
            print("No anchors found!")
            return []
        }
        
        let anchorCoordinates = anchors.map { $0.coordinates }
        
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
    
    var particles: [Particle]
    
    init?(position: CGPoint) {
        numberOfParticles = IndoorLocationManager.shared.filterSettings.numberOfParticles
        
        particles = [Particle]()
        
        for _ in 0..<numberOfParticles {
            guard let particle = Particle(state: [Double(position.x), Double(position.y), 0, 0, 0, 0], weight: 1 / Double(numberOfParticles)) else { return }
            particles.append(particle)
        }
    }
    
    override func predict() {
        for particle in particles {
            particle.updateState()
        }
    }
    
    override func update(measurements: [Double], successCallback: (CGPoint) -> Void) {
        // Evaluate the importance weight up to a normalizing constant of all particles
        var totalWeight = 0.0
        for particle in particles {
            particle.updateWeight(measurements: measurements)
            totalWeight += particle.weight
        }
        
        if (totalWeight == 0) {
            //TODO: Remove this if-clause
            // All weights are 0. Reset weights to 1 / numberOfParticles
            for particle in particles {
                particle.weight = 1 / Double(numberOfParticles)
            }
            totalWeight = 1
        }
        
        var N_eff_inv = 0.0
        // Normalize weights of all particles
        for particle in particles {
            particle.weight = particle.weight / totalWeight
            N_eff_inv += pow(particle.weight, 2)
        }
        
        //TODO: Move this to filterSettings
        let N_thr = Double(numberOfParticles) / 2
        
        // Resample if N_eff is below N_thr
        if (1 / Double(N_eff_inv) < N_thr) {
            resample()
        }
        
        // Determine current position
        var meanX = 0.0
        var meanY = 0.0
        for particle in particles {
            meanX += particle.state[0] * particle.weight
            meanY += particle.state[1] * particle.weight
        }
        
        successCallback(CGPoint(x: meanX, y: meanY))
    }
    
    private func resample() {
        var resampledParticles = [Particle]()
        
        // Construct cumulative sum of weights (CSW) c
        var c = [particles[0].weight]
        for i in 1..<particles.count {
            c.append(c.last! + particles[i].weight)
        }
        var i = 0
        
        // Draw a starting point u_0 from uniform distribution U[0, 1/numberOfParticles]
        let u_0 = randomDouble(upperBound: 1 / (Double(numberOfParticles)))
        var u = [Double]()
        
        for j in 0..<numberOfParticles {
            // Move along the CSW
            u.append(u_0 + (1 / Double(numberOfParticles)) * Double(j))
            
            while (u[j] > c[i]) {
                i += 1
            }
            // Assign new sample and update weight
            particles[i].weight = 1 / Double(numberOfParticles)
            resampledParticles.append(particles[i])
        }
        
        particles = resampledParticles
    }
}

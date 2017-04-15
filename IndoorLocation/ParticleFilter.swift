//
//  ParticleFilter.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 06/04/2017.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit
import GameplayKit

class Particle: NSObject {
    var x: Double = 0.0
    var y: Double = 0.0
    
    var weight: Double = 1.0
    
    init(x: Double, y: Double, weight: Double) {
        self.x = x
        self.y = y
        self.weight = weight
    }
}

class ParticleFilter: BayesianFilter {
    
    let numberOfParticles = 100
    
    var particles: [Particle]
    
    init() {
        particles = [Particle]()
        let randomGenerator = GKGaussianDistribution(randomSource: GKRandomSource(), mean: 0, deviation: 15)
        
        for _ in 0..<numberOfParticles {
            let noisyXCoordinate = 500 + randomGenerator.nextInt()
            let noisyYCoordinate = 80 + randomGenerator.nextInt()
            let particle = Particle(x: Double(noisyXCoordinate), y: Double(noisyYCoordinate), weight: 1.0)
            particles.append(particle)
        }
    }
    
    func predict() {
        print("Predict")
    }
    
    func update(measurements: [Double]) {
        print("Update with measurements \(measurements)")
    }
    
    func getPosition() -> CGPoint {
        var totalX = 0.0
        var totalY = 0.0
        for i in 0..<particles.count {
            totalX += particles[i].x
            totalY += particles[i].y
        }
        let meanX = totalX / Double(particles.count)
        let meanY = totalY / Double(particles.count)
        return CGPoint(x: meanX, y: meanY)
    }
}

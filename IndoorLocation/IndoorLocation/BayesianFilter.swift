//
//  BayesianFilter.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 14.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit
import Accelerate

class BayesianFilter {
    
    var position = CGPoint(x: 0, y: 0)
    
    func predict() {}
    
    func update(measurements: [Double], successCallback: () -> Void) {
        position.x = CGFloat(measurements[0])
        position.y = CGFloat(measurements[1])
        
        // Least squares algorithm:
        guard let anchors = IndoorLocationManager.shared.anchors else {
            print("Not yet calibrated")
            return
        }
        
        let distances = measurements.dropLast(2)
        
        var A = [Double]()
        var b = [Double]()
        
        for i in 0..<anchors.count - 1 {
            b.append(pow(distances[i], 2) - Double(pow(anchors[i].x, 2)) - Double(pow(anchors[i].y, 2))
                - pow(distances.last!, 2) + Double(pow(anchors.last!.x, 2)) + Double(pow(anchors.last!.y, 2)))
            A.append(-2 * Double(anchors[i].x - anchors.last!.x))
            A.append(-2 * Double(anchors[i].y - anchors.last!.y))
        }
        
        let A_inv = invertMatrix(A)
        
        var pos = [0.0, 0.0]
        vDSP_mmulD(A_inv, 1, b, 1, &pos, 1, 2, 1, 2)
        
        position = CGPoint(x: pos[0], y: pos[1])
        
        successCallback()
    }
}

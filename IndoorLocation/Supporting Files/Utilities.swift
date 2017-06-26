//
//  Utilities.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 30/03/2017.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit
import Accelerate

extension Double {
    static func random() -> Double {
        return Double(arc4random()) / Double(UINT32_MAX)
    }
    
    static func random(upperBound: Double) -> Double {
        return upperBound * random()
    }
    
    static func randomGaussian() -> (Double, Double) {
        // Using Marsaglia's polar method to generate a normal distributed random variable
        var u = 0.0
        var v = 0.0
        var s = 0.0
        
        repeat {
            u = random(upperBound: 2) - 1
            v = random(upperBound: 2) - 1
            s = pow(u, 2) + pow(v, 2)
        } while (s >= 1 || s == 0)
        
        let mul = sqrt(-2.0 * log(s) / s)
        
        let z1 = u * mul
        let z2 = v * mul
        return (z1, z2)
    }
}

extension Array where Iterator.Element == Double {
    func invert() -> [Double] {
        var matrix = self
        
        // Get the dimensions of the matrix
        var N = __CLPK_integer(sqrt(Double(matrix.count)))
        
        var pivots = [__CLPK_integer](repeating: 0, count: Int(N))
        var workspace = [Double](repeating: 0, count: Int(N))
        var error = __CLPK_integer(0)
        
        // Perform LU factorization
        dgetrf_(&N, &N, &matrix, &N, &pivots, &error)
        
        if error != 0 {
            return matrix
        }
        
        // Calculate inverse from LU factorization
        dgetri_(&N, &matrix, &N, &pivots, &workspace, &N, &error)
        return matrix
    }
    
    func pprint(numRows: Int, numCols: Int) {
        for i in 0..<numRows {
            print(self[(i * numCols)..<((i + 1) * numCols)], separator: ", ")
        }
    }
    
    // Generate a random gaussian distributed vector with specified mean and matrix A where A*A_T = Covariance matrix.
    static func randomGaussianVector(mean: [Double], A: [Double]) -> [Double] {
        let (z1, z2) = Double.randomGaussian()
        
        let z = [z1, z2]
        
        // Compute and return result = mean + A * z
        var result = [Double](repeating: 0, count: mean.count)
        vDSP_mmulD(A, 1, z, 1, &result, 1, 6, 1, 2)
        
        vDSP_vaddD(mean, 1, result, 1, &result, 1, vDSP_Length(mean.count))
        
        return result
    }
}

func leastSquares(anchors: [CGPoint], distances: [Double]) -> CGPoint {
    var A = [Double]()
    var b = [Double]()
    
    for i in 0..<anchors.count - 1 {
        b.append(pow(distances[i], 2) - Double(pow(anchors[i].x, 2)) - Double(pow(anchors[i].y, 2))
            - pow(distances.last!, 2) + Double(pow(anchors.last!.x, 2)) + Double(pow(anchors.last!.y, 2)))
        A.append(-2 * Double(anchors[i].x - anchors.last!.x))
        A.append(-2 * Double(anchors[i].y - anchors.last!.y))
    }
    
    let A_inv = A.invert()
    
    var pos = [0.0, 0.0]
    vDSP_mmulD(A_inv, 1, b, 1, &pos, 1, 2, 1, 2)
    
    return CGPoint(x: pos[0], y: pos[1])
}

func computeNormalDistribution(x: [Double], m: [Double], forTriangularCovariance P: [Double], withInverse P_inv: [Double]) -> Double {
    // Compute the determinant by multiplying the diagonal elements. This is sufficient as we only deal with triangular matrices
    var determinant = 1.0
    for i in 0..<m.count {
        determinant *= P[(m.count + 1) * i]
    }
    let prefactor = 1 / sqrt(pow(2 * Double.pi, Double(m.count)) * determinant)
    
    // Compute the exponent = (-0.5 * (x-m)_T * P_inv * (x-m))
    var diff = [Double](repeating: 0, count: x.count)
    vDSP_vsubD(m, 1, x, 1, &diff, 1, vDSP_Length(x.count))
    
    var P_diff = [Double](repeating: 0, count: x.count)
    vDSP_mmulD(P_inv, 1, diff, 1, &P_diff, 1, vDSP_Length(x.count), 1, vDSP_Length(x.count))
    
    var diff_P_diff = 0.0
    vDSP_dotprD(diff, 1, P_diff, 1, &diff_P_diff, vDSP_Length(x.count))
    
    let exponent = -0.5 * diff_P_diff
    
    return prefactor * pow(M_E, exponent)
}

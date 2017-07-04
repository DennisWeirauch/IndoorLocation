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
    func inverse() -> [Double] {
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
    
    // Generate a random gaussian distributed vector with specified mean and matrix A where A*A_T = Covariance matrix.
    static func randomGaussianVector(mean: [Double], A: [Double]) -> [Double] {
        let dim = A.count / mean.count
        let z = randomGaussianVector(dim: dim)
        
        // Compute and return result = mean + A * z
        var result = [Double](repeating: 0, count: mean.count)
        vDSP_mmulD(A, 1, z, 1, &result, 1, vDSP_Length(mean.count), 1, vDSP_Length(dim))
        
        vDSP_vaddD(mean, 1, result, 1, &result, 1, vDSP_Length(mean.count))
        
        return result
    }
    
    // Generate a random normal distributed vector
    static func randomGaussianVector(dim: Int) -> [Double] {
        var rand = [Double]()
        while rand.count < dim {
            let (z1, z2) = Double.randomGaussian()
            rand.append(z1)
            if rand.count < dim {
                rand.append(z2)
            }
        }
        return rand
    }
    
    func computeCholeskyDecomposition() -> [Double] {
        var isPositiveDefinite = true
        let n = Int(sqrt(Double(self.count)))
        var L = [Double](repeating: 0, count: self.count)
        
        for i in 0..<n {
            for j in 0..<(i + 1) {
                var sum = 0.0
                for k in 0..<j {
                    sum += L[i * n + k] * L[j * n + k]
                }
                if (i == j) {
                    // Check if we are trying to compute the square root of a negative number here. If so, the input matrix is not positive definite.
                    let diagonalEntry = sqrt(self[j * n + j] - sum)
                    if diagonalEntry.isNaN {
                        isPositiveDefinite = false
                        break
                    }
                    L[i * n + j] = diagonalEntry
                } else {
                    L[i * n + j] = (self[i * n + j] - sum) / L[j * n + j]
                }
            }
        }
        
        if !isPositiveDefinite {
            // Algorithm could not be executed because matrix was not positive definite. Make matrix positive definite and execute algorithm again
            let A = self.positiveDefiniteMatrix()
            return A.computeCholeskyDecomposition()
        }
        return L
    }
    
    // Return a positive definite matrix from a positive semidefinite matrix by setting zero eigenvalues to small values.
    func positiveDefiniteMatrix() -> [Double] {
        // Execute eigenvalue decomposition
        let dim = Int(sqrt(Double(self.count)))
        
        let jobvl = UnsafeMutablePointer(mutating: ("N" as NSString).utf8String)
        let jobvr = UnsafeMutablePointer(mutating: ("V" as NSString).utf8String)
        var n = __CLPK_integer(dim)
        var a = self
        // Real parts of eigenvalues
        var wr = [Double](repeating: 0.0, count: dim)
        // Imaginary parts of eigenvalues
        var wi = [Double](repeating: 0.0, count: dim)
        // Left eigenvectors
        var vl = [Double](repeating: 0.0, count: dim * dim)
        // Right eigenvectors
        var vr = [Double](repeating: 0.0, count: dim * dim)
        
        var workspaceQuery: Double = 0.0
        var lwork = __CLPK_integer(-1)
        var info: __CLPK_integer = 0
        
        // Execute LAPACK function dgeev() to obtain the workspace size
        dgeev_(jobvl, jobvr, &n, &a, &n, &wr, &wi, &vl, &n, &vr, &n, &workspaceQuery, &lwork, &info)
        
        var work = [Double](repeating: 0.0, count: Int(workspaceQuery))
        lwork = __CLPK_integer(workspaceQuery)
        
        // Execute dgeev() again to compute eigenvalues and eigenvectors
        dgeev_(jobvl, jobvr, &n, &a, &n, &wr, &wi, &vl, &n, &vr, &n, &work, &lwork, &info)
        
        // Fix zero or negative eigenvalues
        let fixedEigenvalues = wr.map { $0 < 1e-10 ? 1e-6 : $0 }
        
        var D = [Double]()
        for i in 0..<dim {
            for j in 0..<dim {
                if (i == j) {
                    D.append(fixedEigenvalues[i])
                } else {
                    D.append(0)
                }
            }
        }
        
        // Compute and return A = V * D * inv(V)
        var A = [Double](repeating: 0, count: vr.count)
        vDSP_mmulD(vr, 1, D, 1, &A, 1, vDSP_Length(dim), vDSP_Length(dim), vDSP_Length(dim))
        
        vDSP_mmulD(A, 1, vr.inverse(), 1, &A, 1, vDSP_Length(dim), vDSP_Length(dim), vDSP_Length(dim))
        
        return A
    }
    
    func pprint(numRows: Int, numCols: Int) {
        for i in 0..<numRows {
            print(self[(i * numCols)..<((i + 1) * numCols)], separator: ", ")
        }
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
    
    let A_inv = A.inverse()
    
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

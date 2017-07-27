//
//  Utilities.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 30/03/2017.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import Accelerate
import UIKit

precedencegroup PowerPrecedence { higherThan: MultiplicationPrecedence }
infix operator ^^ : PowerPrecedence
/**
 Implements the power function
 - Returns: The result of pow(radix, power)
 */
func ^^ (radix: Float, power: Float) -> Float {
    return pow(Float(radix), Float(power))
}

extension Float {
    /**
     Generate a random sample from a uniform distribution in the range [0, 1]
     - Returns: A random uniform distributed Float in the range [0, 1]
     */
    static func random() -> Float {
        return Float(arc4random()) / Float(UINT32_MAX)
    }
    
    /**
     Generate a random sample from a uniform distribution in the range [0, upperBound]
     - Parameter upperBound: The upperbound for the random sample
     - Returns: A random uniform distributed Float in the range [0, upperBound]
     */
    static func random(upperBound: Float) -> Float {
        return upperBound * random()
    }
    
    /**
     Generate a random sample from a standard normal distribution
     - Returns: A pair of random samples from a standard normal distribution
     */
    static func randomGaussian() -> (Float, Float) {
        // Using Marsaglia's polar method to generate a normal distributed random variable
        var u: Float = 0
        var v: Float = 0
        var s: Float = 0
        
        repeat {
            u = random(upperBound: 2) - 1
            v = random(upperBound: 2) - 1
            s = u ^^ 2 + v ^^ 2
        } while (s >= 1 || s == 0)
        
        let mul = sqrt(-2.0 * log(s) / s)
        
        let z1 = u * mul
        let z2 = v * mul
        return (z1, z2)
    }
}

extension Array where Iterator.Element == Float {
    /**
     Generate a random gaussian distributed vector with specified mean and covariance
     - Parameter mean: The mean of the random vector
     - Parameter A: A matrix for which holds `A` * `A_T` = Covariance matrix
     - Returns: A random gaussian distributed vector with specified mean and covariance
     */
    static func randomGaussianVector(mean: [Float], A: [Float]) -> [Float] {
        let dim = A.count / mean.count
        let z = randomGaussianVector(dim: dim)
        
        // Compute and return result = mean + A * z
        var result = [Float](repeating: 0, count: mean.count)
        vDSP_mmul(A, 1, z, 1, &result, 1, vDSP_Length(mean.count), 1, vDSP_Length(dim))
        
        vDSP_vadd(mean, 1, result, 1, &result, 1, vDSP_Length(mean.count))
        
        return result
    }
    
    /**
      Generate a random normal distributed vector
     - Parameter dim: The number of dimensions for the vector
     - Returns: A random normal distributed vector of `dim` dimensions
     */
    static func randomGaussianVector(dim: Int) -> [Float] {
        var rand = [Float]()
        while rand.count < dim {
            let (z1, z2) = Float.randomGaussian()
            rand.append(z1)
            if rand.count < dim {
                rand.append(z2)
            }
        }
        return rand
    }
    
    /**
     Determine the inverse of a matrix
     - Returns: The inverse of the matrix
     */
    func inverse() -> [Float] {
        var matrix = self
        
        // Get the dimensions of the matrix
        var N = __CLPK_integer(sqrt(Float(matrix.count)))
        
        var pivots = [__CLPK_integer](repeating: 0, count: Int(N))
        var workspace = [Float](repeating: 0, count: Int(N))
        var error = __CLPK_integer(0)
        
        // Perform LU factorization
        sgetrf_(&N, &N, &matrix, &N, &pivots, &error)
        
        if error != 0 {
            return matrix
        }
        
        // Calculate inverse from LU factorization
        sgetri_(&N, &matrix, &N, &pivots, &workspace, &N, &error)
        return matrix
    }
    
    /**
     Computes the cholesky decomposition of the matrix
     - Returns: Returns the cholesky decomposition if the matrix was positive definite. Otherwise returns `nil`
     */
    func computeCholeskyDecomposition() -> [Float]? {
        let n = Int(sqrt(Float(self.count)))
        var L = [Float](repeating: 0, count: self.count)
        
        for i in 0..<n {
            for j in 0..<(i + 1) {
                var sum: Float = 0
                for k in 0..<j {
                    sum += L[i * n + k] * L[j * n + k]
                }
                if (i == j) {
                    // Check if we are trying to compute the square root of a negative number here. If so, the input matrix is not positive definite.
                    let diagonalEntry = sqrt(self[j * n + j] - sum)
                    if diagonalEntry.isNaN {
                        return nil
                    }
                    L[i * n + j] = diagonalEntry
                } else {
                    L[i * n + j] = (self[i * n + j] - sum) / L[j * n + j]
                }
            }
        }
        
        return L
    }
    
    func computeEigenvalueDecomposition() -> (eigenvalues: [Float], eigenvectors: [Float]) {
        // Execute eigenvalue decomposition
        let dim = Int(sqrt(Float(self.count)))
        
        let jobvl = UnsafeMutablePointer(mutating: ("N" as NSString).utf8String)
        let jobvr = UnsafeMutablePointer(mutating: ("V" as NSString).utf8String)
        var n = __CLPK_integer(dim)
        var a = self
        // Real parts of eigenvalues
        var wr = [Float](repeating: 0, count: dim)
        // Imaginary parts of eigenvalues
        var wi = [Float](repeating: 0, count: dim)
        // Left eigenvectors
        var vl = [Float](repeating: 0, count: dim * dim)
        // Right eigenvectors
        var vr = [Float](repeating: 0, count: dim * dim)
        
        var workspaceQuery: Float = 0
        var lwork = __CLPK_integer(-1)
        var info: __CLPK_integer = 0
        
        // Execute LAPACK function dgeev() to obtain the workspace size
        sgeev_(jobvl, jobvr, &n, &a, &n, &wr, &wi, &vl, &n, &vr, &n, &workspaceQuery, &lwork, &info)
        
        var work = [Float](repeating: 0, count: Int(workspaceQuery))
        lwork = __CLPK_integer(workspaceQuery)
        
        // Execute dgeev() again to compute eigenvalues and eigenvectors
        sgeev_(jobvl, jobvr, &n, &a, &n, &wr, &wi, &vl, &n, &vr, &n, &work, &lwork, &info)
        
        return (eigenvalues: wr, eigenvectors: vr)
    }
    
    /**
     Compute a positive definite matrix from a positive semidefinite matrix by setting zero eigenvalues to small values
     - Returns: A positive definite matrix
     */
    func positiveDefiniteMatrix() -> [Float] {
        let dim = Int(sqrt(Float(self.count)))

        let (eigenvalues, eigenvectors) = self.computeEigenvalueDecomposition()
        
        // Fix zero or negative eigenvalues
        let fixedEigenvalues = eigenvalues.map { $0 < 1e-10 ? 1e-6 : $0 }
        
        var D = [Float]()
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
        var A = [Float](repeating: 0, count: eigenvectors.count)
        vDSP_mmul(eigenvectors, 1, D, 1, &A, 1, vDSP_Length(dim), vDSP_Length(dim), vDSP_Length(dim))
        
        vDSP_mmul(A, 1, eigenvectors.inverse(), 1, &A, 1, vDSP_Length(dim), vDSP_Length(dim), vDSP_Length(dim))
        
        return A
    }
    
    /**
     Prints matrices nicely for debugging purposes
     - Parameter numRows: Number of rows of the matrix
     - Parameter numCols: Number of colums of the matrix
     */
    func pprint(numRows: Int, numCols: Int) {
        for i in 0..<numRows {
            print(self[(i * numCols)..<((i + 1) * numCols)], separator: ", ")
        }
    }
}

/**
 Executes the least squares algorithm
 - Parameter anchors: The set of active anchors
 - Parameter distances: The raw distances to the anchors
 - Returns: The position determined by the least squares algorithm or `nil` if too few anchors are available
 */
func leastSquares(anchors: [CGPoint], distances: [Float]) -> CGPoint? {
    guard anchors.count > 2 else {
        print("At least 3 anchors are necessary for the least squares algorithm.")
        return nil
    }
    
    var A = [Float]()
    var b = [Float]()
    
    for i in 0..<anchors.count - 1 {
        b.append(distances[i] ^^ 2 - Float(anchors[i].x) ^^ 2 - Float(anchors[i].y) ^^ 2 - distances.last! ^^ 2 + Float(anchors.last!.x) ^^ 2 + Float(anchors.last!.y) ^^ 2)
        A.append(-2 * Float(anchors[i].x - anchors.last!.x))
        A.append(-2 * Float(anchors[i].y - anchors.last!.y))
    }
    
    var A_inv: [Float]
    if anchors.count == 3 {
        A_inv = A.inverse()
    } else {
        // Determine the Moore-Penrose Pseudo-Inverse to solve the problem
        var A_T = [Float](repeating: 0, count: A.count)
        vDSP_mtrans(A, 1, &A_T, 1, 2, vDSP_Length(anchors.count - 1))
        
        var A_T_A = [Float](repeating: 0, count: 4)
        vDSP_mmul(A_T, 1, A, 1, &A_T_A, 1, 2, 2, vDSP_Length(anchors.count - 1))
        
        A_inv = [Float](repeating: 0, count: A.count)
        vDSP_mmul(A_T_A.inverse(), 1, A_T, 1, &A_inv, 1, 2, vDSP_Length(anchors.count - 1), 2)
    }
    
    var pos: [Float] = [0, 0]
    vDSP_mmul(A_inv, 1, b, 1, &pos, 1, 2, 1, vDSP_Length(anchors.count - 1))
    
    return CGPoint(x: CGFloat(pos[0]), y: CGFloat(pos[1]))
}

/**
 Computes the value of p(x) where p(X) = N(X, m, P) in a logarithmic scale.
 - Parameter x: Vector x
 - Parameter m: Vector of mean
 - Parameter
 - Returns: p(x) in logarithmic scale
 */
func computeNormalDistribution(x: [Float], m: [Float], forTriangularCovariance P: [Float], withInverse P_inv: [Float]) -> Float {
    // Compute the determinant by multiplying the diagonal elements. This is sufficient as we only deal with triangular matrices
    var determinant: Float = 1
    for i in 0..<m.count {
        determinant *= P[(m.count + 1) * i]
    }
    let prefactor = 1 / sqrt((2 * Float.pi) ^^ Float(m.count) * determinant)
    
    // Compute the exponent = (-0.5 * (x-m)_T * P_inv * (x-m))
    var diff = [Float](repeating: 0, count: x.count)
    vDSP_vsub(m, 1, x, 1, &diff, 1, vDSP_Length(x.count))
    
    var P_diff = [Float](repeating: 0, count: x.count)
    vDSP_mmul(P_inv, 1, diff, 1, &P_diff, 1, vDSP_Length(x.count), 1, vDSP_Length(x.count))
    
    var diff_P_diff: Float = 0
    vDSP_dotpr(diff, 1, P_diff, 1, &diff_P_diff, vDSP_Length(x.count))
    
    let exponent = -0.5 * diff_P_diff
    
    return log(prefactor) + exponent
}

func alertWithTitle(_ title: String, message: String? = nil, actions: [UIAlertAction]? = nil) {
    let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
    
    if let actions = actions {
        actions.forEach { action in alertController.addAction(action) }
    } else {
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
    }
    
    guard let mapViewController = UIApplication.shared.keyWindow?.rootViewController else { return }
    
    if let settingsViewController = mapViewController.presentedViewController {
        settingsViewController.present(alertController, animated: true, completion: nil)
    } else {
        mapViewController.present(alertController, animated: true, completion: nil)
    }
}

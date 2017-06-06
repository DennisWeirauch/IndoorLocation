//
//  Utilities.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 30/03/2017.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import Foundation
import MapKit
import Accelerate
import GameplayKit

extension MKMapPoint {
    /**
     - parameter a: Point A.
     - parameter b: Point B.
     - returns: An MKMapPoint object representing the midpoints of a and b.
     */
    static func midpoint(_ a: MKMapPoint, b: MKMapPoint) -> MKMapPoint {
        return MKMapPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
    }
}

extension CLLocationDistance {
    /**
     - parameter a: coordinate A.
     - parameter b: coordinate B.
     - returns: The distance between the two coordinates.
     */
    static func distanceBetweenLocationCoordinates2D(_ a: CLLocationCoordinate2D, b: CLLocationCoordinate2D) -> CLLocationDistance {
        
        let locA: CLLocation = CLLocation(latitude: a.latitude, longitude: a.longitude)
        let locB: CLLocation = CLLocation(latitude: b.latitude, longitude: b.longitude)
        
        return locA.distance(from: locB)
    }
}

extension CGPoint {
    /**
     - parameter a: point A.
     - parameter b: point B.
     - returns: the mean point of the two CGPoint objects.
     */
    static func pointAverage(_ a: CGPoint, b: CGPoint) -> CGPoint {
        return CGPoint(x:(a.x + b.x) * 0.5, y:(a.y + b.y) * 0.5)
    }
}

extension CGVector {
    /**
     - parameter other: a vector.
     - returns: the dot product of the other vector with this vector.
     */
    func dotProductWithVector(_ other: CGVector) -> CGFloat {
        return dx * other.dx + dy * other.dy
    }
    
    /**
     - parameter scale: how much to scale (e.g. 1.0, 1.5, 0.2, etc).
     - returns: a copy of this vector, rescaled by the amount given.
     */
    func scaledByFloat(_ scale: CGFloat) -> CGVector {
        return CGVector(dx: dx * scale, dy: dy * scale)
    }
    
    /**
     - parameter radians: how many radians you want to rotate by.
     - returns: a copy of this vector, after being rotated in the
     "positive radians" direction by the amount given.
     - note: If your coordinate frame is right-handed, positive radians
     is counter-clockwise.
     */
    func rotatedByRadians(_ radians: CGFloat) -> CGVector {
        let cosRadians = cos(radians)
        let sinRadians = sin(radians)
        
        return CGVector(dx: cosRadians * dx - sinRadians * dy, dy: sinRadians * dx + cosRadians * dy)
    }
}

extension MKMapRect {
    /**
     - returns: The point at the center of the rectangle.
     - parameter rect: A rectangle.
     */
    func getCenter() -> MKMapPoint {
        return MKMapPointMake(MKMapRectGetMidX(self), MKMapRectGetMidY(self))
    }
}

extension MKMapSize {
    /// - returns: The area of this MKMapSize object
    func area() -> Double {
        return height * width
    }
}

func invertMatrix(_ matrix: [Double]) -> [Double] {
    var inMatrix = matrix
    
    // Get the dimensions of the matrix
    var N = __CLPK_integer(sqrt(Double(matrix.count)))
    
    var pivots = [__CLPK_integer](repeating: 0, count: Int(N))
    var workspace = [Double](repeating: 0, count: Int(N))
    var error = __CLPK_integer(0)
    
    // Perform LU factorization
    dgetrf_(&N, &N, &inMatrix, &N, &pivots, &error)
    
    if error != 0 {
        return inMatrix
    }
    
    // Calculate inverse from LU factorization
    dgetri_(&N, &inMatrix, &N, &pivots, &workspace, &N, &error)
    return inMatrix
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
    
    let A_inv = invertMatrix(A)
    
    var pos = [0.0, 0.0]
    vDSP_mmulD(A_inv, 1, b, 1, &pos, 1, 2, 1, 2)
    
    return CGPoint(x: pos[0], y: pos[1])
}

func computeNormalDistribution(x: [Double], m: [Double], forTriangularCovariance P: [Double]) -> Double {
    // Compute the determinant by multiplying the diagonal elements. This is sufficient as we only deal with triangular matrices
    let rank = Int(sqrt(Double(P.count)))
    var determinant = 1.0
    for i in 0..<rank {
        determinant *= P[(rank + 1) * i]
    }
    let prefactor = 1 / sqrt(2 * Double.pi * determinant)
    
    // Compute the exponent = (-0.5 * (x-m)_T * P_inv * (x-m))
    var diff = [Double](repeating: 0, count: x.count)
    vDSP_vsubD(m, 1, x, 1, &diff, 1, vDSP_Length(x.count))
    
    var P_diff = [Double](repeating: 0, count: x.count)
    vDSP_mmulD(invertMatrix(P), 1, diff, 1, &P_diff, 1, 5, 1, 5)
    
    var diff_P_diff = [0.0]
    vDSP_mmulD(diff, 1, P_diff, 1, &diff_P_diff, 1, 1, 1, 5)
    
    let exponent = -0.5 * diff_P_diff[0]
    
    return prefactor * pow(M_E, exponent)
}

private func randomDouble() -> Double {
    return Double(arc4random()) / Double(UINT32_MAX)
}

public func randomDouble(upperBound: Double) -> Double {
    return upperBound * randomDouble()
}

// Generate a random gaussian distributed vector with specified mean and matrix A where A*A_T = Covariance matrix.
public func randomGaussianVector(mean: [Double], A: [Double]) -> [Double] {
    // Box Muller transform to generate 2 independent normal distributed random variables z1, z2
    let u1 = randomDouble()
    let u2 = randomDouble()
    
    let z1 = sqrt(-2.0 * log(u1)) * cos(2.0 * Double.pi * u2)
    let z2 = sqrt(-2.0 * log(u1)) * sin(2.0 * Double.pi * u2)
    
    let z = [z1, z2]
    
    var mult = [Double](repeating: 0, count: mean.count)
    vDSP_mmulD(A, 1, z, 1, &mult, 1, 6, 1, 2)
    
    var result = [Double](repeating: 0, count: mean.count)
    vDSP_vaddD(mean, 1, mult, 1, &result, 1, vDSP_Length(mean.count))
    
    return result
}

func pprint(matrix: [Double], numRows: Int, numCols: Int) {
    for i in 0..<numRows {
        print(matrix[(i * numCols)..<((i + 1) * numCols)], separator: ", ")
    }
}

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

func pprint(matrix: [Double], numRows: Int, numCols: Int) {
    for i in 0..<numRows {
        print(matrix[(i * numCols)..<((i + 1) * numCols)], separator: ", ")
    }
}

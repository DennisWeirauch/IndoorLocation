//
//  ExtendedKalmanFilter.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 17.05.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import Accelerate

/**
 Class that implements an Extended Kalman filter.
 */
class ExtendedKalmanFilter: BayesianFilter {
    
    /// State vector containing: [xPos, yPos, xVel, yVel]
    private var state: [Float]

    /// P is the covariance matrix for the state
    private(set) var P: [Float]
    
    init?(anchors: [Anchor], distances: [Float]) {
        // Make sure at least one anchor is within range. Otherwise initialization is not possible.
        guard anchors.count > 0 else { return nil }
        
        var position: CGPoint
        switch anchors.count {
        case 1:
            // Determine initial position by taking a random value from circle around anchor
            let phi = Float.random(upperBound: 2 * Float.pi)
            
            position = CGPoint(x: CGFloat(cos(phi) * distances[0]) + anchors[0].position.x, y: CGFloat(sin(phi) * distances[0]) + anchors[0].position.y)
        case 2:
            // Determine initial position by looking for intersections of circles. Solution is based on http://paulbourke.net/geometry/circlesphere/
            let x_0 = Float(anchors[0].position.x)
            let y_0 = Float(anchors[0].position.y)
            let r_0 = distances[0]
            let x_1 = Float(anchors[1].position.x)
            let y_1 = Float(anchors[1].position.y)
            let r_1 = distances[1]
            
            // Distance between anchor points
            let d = sqrt((x_0 - x_1)^^2 + (y_0 - y_1)^^2)
            
            // Check if intersection exists
            if (r_0 + r_1 < d) {
                // Circles not intersecting. Assign value on one circle in between anchor points
                position = CGPoint(x: CGFloat(x_0 + r_0 * (x_1 - x_0) / d), y: CGFloat(y_0 + r_0 * (y_1 - y_0) / d))
                break
            } else if (abs(r_0 - r_1) > d) {
                // One circle lies within the other circle. Assign random value one circle
                position = CGPoint(x: CGFloat(x_0 + r_0), y: CGFloat(y_0))
                break
            }
            
            // Two right triangles are constructed for which hold: a^2 + h^2 = r_0^2 and (d-a)^2 + h^2 = r_1^2
            let a = (r_0^^2 - r_1^^2 + d^^2) / (2 * d)
            
            let h = sqrt(r_0^^2 - a^^2)
            
            let x_2 = x_0 + a * (x_1 - x_0) / d
            let y_2 = y_0 + a * (y_1 - y_0) / d
            
            position = CGPoint(x: CGFloat(x_2 + h * (y_1 - y_0) / d), y: CGFloat(y_2 - h * (x_1 - x_0) / d))
        default:
            // Determine initial position by linear least squares estimate
            position = linearLeastSquares(anchors: anchors.map { $0.position }, distances: distances)!
        }
        
        let settings = IndoorLocationManager.shared.filterSettings

        let dist_sig = Float(settings.distanceUncertainty)
        
        // Initialize state vector with position from linear least squares algorithm and no motion.
        state = [Float(position.x), Float(position.y), 0, 0]
        
        // Initialize matrix P with the selected distance uncertainty
        P = [Float]()
        for i in 0..<state.count {
            for j in 0..<state.count {
                if (i == j) {
                    P.append(10 * dist_sig)
                } else {
                    P.append(0)
                }
            }
        }
        
        super.init()
    }
    
    override func executeAlgorithm(anchors: [Anchor], distances: [Float], acceleration: [Float], successCallback: @escaping (_ position: CGPoint) -> Void) {
        
        // Determine whether the active anchors have changed
        if (activeAnchors.map { $0.id } != anchors.map { $0.id }) {
            didChangeAnchors(anchors)
        }
        
        // Execute the prediction step of the algorithm
        predict(u: u)
        
        // Execute the update step of the algorithm
        update(anchors: anchors, measurements: distances)
        
        u = acceleration
        
        successCallback(CGPoint(x: CGFloat(state[0]), y: CGFloat(state[1])))
    }
    
    //MARK: Private API
    /**
     Execute the prediction step of the Kalman Filter. The state and its covariance are updated according to the physical model.
     - Parameter u: The control input from the previous time step
     */
    private func predict(u: [Float]) {
        // Compute new state from state = F * state + B * u
        var B_u = [Float](repeating: 0, count: state.count)
        vDSP_mmul(B, 1, u, 1, &B_u, 1, vDSP_Length(state.count), 1, 2)
        
        vDSP_mmul(F, 1, state, 1, &state, 1, vDSP_Length(state.count), 1, vDSP_Length(state.count))
        
        vDSP_vadd(B_u, 1, state, 1, &state, 1, vDSP_Length(state.count))
        
        // Compute new P from P = F * P * F_t + Q
        vDSP_mmul(F, 1, P, 1, &P, 1, vDSP_Length(state.count), vDSP_Length(state.count), vDSP_Length(state.count))
        
        var F_t = [Float](repeating: 0, count : F.count)
        vDSP_mtrans(F, 1, &F_t, 1, vDSP_Length(state.count), vDSP_Length(state.count))
        
        vDSP_mmul(P, 1, F_t, 1, &P, 1, vDSP_Length(state.count), vDSP_Length(state.count), vDSP_Length(state.count))
        
        vDSP_vadd(P, 1, Q, 1, &P, 1, vDSP_Length(Q.count))
    }
    
    /**
     Execute the update step of the Kalman Filter. The state and its covariance are updated according to the received measurement.
     - Parameter anchors: The current set of active anchors
     - Parameter measurements: The new measurement vector
     */
    private func update(anchors: [Anchor], measurements: [Float]) {
        
        let H = H_j(state, anchors: anchors)
        
        // Compute S from S = H * P * H_t + R
        var H_t = [Float](repeating: 0, count : H.count)
        vDSP_mtrans(H, 1, &H_t, 1, vDSP_Length(state.count), vDSP_Length(measurements.count))
        
        var P_H_t = [Float](repeating: 0, count: H_t.count)
        vDSP_mmul(P, 1, H_t, 1, &P_H_t, 1, vDSP_Length(state.count), vDSP_Length(measurements.count), vDSP_Length(state.count))
        
        var S = [Float](repeating: 0, count : R.count)
        vDSP_mmul(H, 1, P_H_t, 1, &S, 1, vDSP_Length(measurements.count), vDSP_Length(measurements.count), vDSP_Length(state.count))
        
        vDSP_vadd(S, 1, R, 1, &S, 1, vDSP_Length(R.count))
        
        // Compute K from K = P * H_t * S_inv
        var K = [Float](repeating: 0, count: state.count * measurements.count)
        vDSP_mmul(P_H_t, 1, S.inverse(), 1, &K, 1, vDSP_Length(state.count), vDSP_Length(measurements.count), vDSP_Length(measurements.count))
        
        // Compute new state = state + K * (measurements - h(state))
        var innovation = [Float](repeating: 0, count: measurements.count)
        vDSP_vsub(h(state, anchors: anchors), 1, measurements, 1, &innovation, 1, vDSP_Length(measurements.count))
        
        var update = [Float](repeating: 0, count: state.count)
        vDSP_mmul(K, 1, innovation, 1, &update, 1, vDSP_Length(state.count), 1, vDSP_Length(measurements.count))
        
        vDSP_vadd(state, 1, update, 1, &state, 1, vDSP_Length(state.count))
        
        // Compute new P from P = P - K * H * P
        var cov_update = [Float](repeating: 0, count: P.count)
        vDSP_mmul(K, 1, H, 1, &cov_update, 1, vDSP_Length(state.count), vDSP_Length(state.count), vDSP_Length(measurements.count))
        
        vDSP_mmul(cov_update, 1, P, 1, &cov_update, 1, vDSP_Length(state.count), vDSP_Length(state.count), vDSP_Length(state.count))
        
        vDSP_vsub(cov_update, 1, P, 1, &P, 1, vDSP_Length(P.count))
    }
    
    /**
     Evaluates the measurement equation
     - Parameter state: The current state to evaluate
     - Parameter anchors: The set of anchors that are currently active
     - Returns: A vector containing the distances to all anchors: [dist0, ..., distN]
     */
    private func h(_ state: [Float], anchors: [Anchor]) -> [Float] {
        let anchorPositions = anchors.map { $0.position }

        var h = [Float]()
        for i in 0..<anchors.count {
            // Determine the euclidean distance to each anchor point
            h.append(sqrt((Float(anchorPositions[i].x) - state[0]) ^^ 2 + (Float(anchorPositions[i].y) - state[1]) ^^ 2))
        }
        return h
    }
    
    /**
     Determines the local linearization of function h, evaluated at the current state. This is defined by the Jacobian matrix H_j
     - Parameter state: The current state vector
     - Parameter anchors: The current set of active anchors
     - Returns: The Jacobian of function h, evaluated at the current state
     */
    private func H_j(_ state: [Float], anchors: [Anchor]) -> [Float] {
        
        let anchorPositions = anchors.map { $0.position }

        var H_j = [Float]()
        for i in 0..<anchors.count {
            if (state[0] == Float(anchorPositions[i].x) && state[1] == Float(anchorPositions[i].y)) {
                // If position is exactly the same as an anchor, we would divide by 0. Therefore this
                // case is treated here separately and zeros are added.
                H_j += [0, 0]
            } else {
                H_j.append((state[0] - Float(anchorPositions[i].x)) / sqrt((Float(anchorPositions[i].x) - state[0]) ^^ 2 + (Float(anchorPositions[i].y) - state[1]) ^^ 2))
                H_j.append((state[1] - Float(anchorPositions[i].y)) / sqrt((Float(anchorPositions[i].x) - state[0]) ^^ 2 + (Float(anchorPositions[i].y) - state[1]) ^^ 2))
            }
            // Append zeros for last two columns of H_j
            H_j += [0, 0]
        }
        return H_j
    }
}

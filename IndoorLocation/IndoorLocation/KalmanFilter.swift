//
//  KalmanFilter.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 17.05.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import Accelerate

class KalmanFilter: BayesianFilter {
    
    // State vector containing: [xPos, yPos, xVel, yVel, xAcc, yAcc]
    private var state: [Float]

    // Matrices
    private var F: [Float]
    private var Q: [Float]
    private var R: [Float]
    private(set) var P: [Float]
    
    init(position: CGPoint) {
        
        let settings = IndoorLocationManager.shared.filterSettings

        let acc_sig = Float(settings.accelerationUncertainty)
        let pos_sig = Float(settings.distanceUncertainty)
        var proc_fac = sqrt(Float(settings.processingUncertainty))
        let dt = settings.updateTime
        
        guard let anchors = IndoorLocationManager.shared.anchors else {
            fatalError("No anchors found!")
        }
        
        state = [Float(position.x), Float(position.y), 0, 0, 0, 0]
        
        // Initialize matrices
        // F is a 6x6 matrix with '1's in main diagonal, 'dt's in second positive side diagonal and '(dt^2)/2's in fourth positive side diagonal
        F = [Float]()
        for i in 0..<6 {
            for j in 0..<6 {
                if (i == j) {
                    F.append(1)
                } else if (i + 2 == j) {
                    F.append(dt)
                } else if (i + 4 == j) {
                    F.append(dt ^^ 2 / 2)
                } else {
                    F.append(0)
                }
            }
        }

        // G is a 6x2 matrix with '(dt^2)/2's in main diagonal, 'dt's in second negative side diagonal and '1's in fourth negative side diagonal
        var G = [Float]()
        for i in 0..<6 {
            for j in 0..<2 {
                if (i == j) {
                    G.append(dt ^^ 2 / 2)
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
        vDSP_vsmul(G, 1, &proc_fac, &G, 1, vDSP_Length(G.count))
        
        var G_t = [Float](repeating: 0, count: G.count)
        vDSP_mtrans(G, 1, &G_t, 1, 2, 6)
        
        // Compute Q from Q = G * G_t. Q is a 6x6 matrix
        Q = [Float](repeating: 0, count: 36)
        vDSP_mmul(G, 1, G_t, 1, &Q, 1, 6, 6, 1)
        
        // R is a (numAnchors + 2)x(numAnchors + 2) diagonal matrix with 'pos_sig's in first numAnchors entries and 'acc_sig's in the remaining entries
        R = [Float]()
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
        
        // P is a 6x6 diagonal matrix with pos_sig entries
        P = [Float]()
        for i in 0..<6 {
            for j in 0..<6 {
                if (i == j) {
                    P.append(pos_sig)
                } else {
                    P.append(0)
                }
            }
        }
    }
    
    override func computeAlgorithm(measurements: [Float], successCallback: @escaping (CGPoint) -> Void) {
        predict()
        
        update(measurements: measurements, successCallback: successCallback)
    }
    
    //MARK: Private API
    private func predict() {
        // Compute new state from state = F * state
        vDSP_mmul(F, 1, state, 1, &state, 1, 6, 1, 6)
        
        // Compute new P from P = F * P * F_t + Q
        vDSP_mmul(F, 1, P, 1, &P, 1, 6, 6, 6)
        
        var F_t = [Float](repeating: 0, count : F.count)
        vDSP_mtrans(F, 1, &F_t, 1, 6, 6)
        
        vDSP_mmul(P, 1, F_t, 1, &P, 1, 6, 6, 6)
        
        vDSP_vadd(P, 1, Q, 1, &P, 1, vDSP_Length(Q.count))
    }
    
    private func update(measurements: [Float], successCallback: (CGPoint) -> Void) {
        guard let anchors = IndoorLocationManager.shared.anchors else {
            fatalError("No anchors found!")
        }
        
        let H = H_j(state)
        
        let numAnchPlus2 = vDSP_Length(anchors.count + 2)
        
        // Compute S from S = H * P * H_t + R
        var H_t = [Float](repeating: 0, count : H.count)
        vDSP_mtrans(H, 1, &H_t, 1, 6, numAnchPlus2)
        
        var P_H_t = [Float](repeating: 0, count: H_t.count)
        vDSP_mmul(P, 1, H_t, 1, &P_H_t, 1, 6, numAnchPlus2, 6)
        
        var S = [Float](repeating: 0, count : R.count)
        vDSP_mmul(H, 1, P_H_t, 1, &S, 1, numAnchPlus2, numAnchPlus2, 6)
        
        vDSP_vadd(S, 1, R, 1, &S, 1, vDSP_Length(R.count))
        
        // Compute K from K = P * H_t * S_inv
        var K = [Float](repeating: 0, count: 6 * (anchors.count + 2))
        vDSP_mmul(P_H_t, 1, S.inverse(), 1, &K, 1, 6, numAnchPlus2, numAnchPlus2)
        
        // Compute new state = state + K * (measurements - h(state))
        var innovation = [Float](repeating: 0, count: anchors.count + 2)
        vDSP_vsub(h(state), 1, measurements, 1, &innovation, 1, numAnchPlus2)
        
        var update = [Float](repeating: 0, count: 6)
        vDSP_mmul(K, 1, innovation, 1, &update, 1, 6, 1, numAnchPlus2)
        
        vDSP_vadd(state, 1, update, 1, &state, 1, 6)
        
        // Compute new P from P = P - K * H * P
        var K_H = [Float](repeating: 0, count: 36)
        vDSP_mmul(K, 1, H, 1, &K_H, 1, 6, 6, numAnchPlus2)
        
        var K_H_P = [Float](repeating: 0, count: 36)
        vDSP_mmul(K_H, 1, P, 1, &K_H_P, 1, 6, 6, 6)
        
        vDSP_vsub(K_H_P, 1, P, 1, &P, 1, 36)
        
        let position = CGPoint(x: CGFloat(state[0]), y: CGFloat(state[1]))
        
        successCallback(position)
    }
    
    private func h(_ state: [Float]) -> [Float] {
        guard let anchors = IndoorLocationManager.shared.anchors else {
            fatalError("No anchors found!")
        }
        
        let anchorCoordinates = anchors.map { $0.position }
        
        let xPos = state[0]
        let yPos = state[1]
        let xAcc = state[4]
        let yAcc = state[5]
        
        var h = [Float]()
        for i in 0..<anchors.count {
            h.append(sqrt((Float(anchorCoordinates[i].x) - xPos) ^^ 2 + (Float(anchorCoordinates[i].y) - yPos) ^^ 2))
        }
        h.append(xAcc)
        h.append(yAcc)
        
        return h
    }
    
    private func H_j(_ state: [Float]) -> [Float] {
        guard let anchors = IndoorLocationManager.shared.anchors else {
            fatalError("No anchors found!")
        }
        
        let anchorCoordinates = anchors.map { $0.position }

        var H_j = [Float]()
        for i in 0..<anchors.count {
            if (state[0] == Float(anchorCoordinates[i].x) && state[1] == Float(anchorCoordinates[i].y)) {
                // If position is exactly the same as an anchor, we would divide by 0. Therefore this
                // case is treated here separately and zeros are added.
                H_j += [0, 0]
            } else {
                H_j.append((state[0] - Float(anchorCoordinates[i].x)) / sqrt((Float(anchorCoordinates[i].x) - state[0]) ^^ 2 + (Float(anchorCoordinates[i].y) - state[1]) ^^ 2))
                H_j.append((state[1] - Float(anchorCoordinates[i].y)) / sqrt((Float(anchorCoordinates[i].x) - state[0]) ^^ 2 + (Float(anchorCoordinates[i].y) - state[1]) ^^ 2))
            }
            H_j += [0, 0, 0, 0]
        }
        H_j += [0, 0, 0, 0, 1, 0]
        H_j += [0, 0, 0, 0, 0, 1]
        
        return H_j
    }
}

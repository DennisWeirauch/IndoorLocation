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
    private var state: [Double]

    // Matrices
    private var F: [Double]
    private var Q: [Double]
    private var R: [Double]
    private(set) var P: [Double]
    
    init(position: CGPoint) {
        
        let settings = IndoorLocationManager.shared.filterSettings

        let acc_sig = Double(settings.accelerationUncertainty)
        let pos_sig = Double(settings.distanceUncertainty)
        var proc_fac = Double(settings.processingUncertainty)
        let dt = settings.updateTime
        
        guard let anchors = IndoorLocationManager.shared.anchors else {
            fatalError("No anchors found!")
        }
        
        state = [Double(position.x), Double(position.y), 0, 0, 0, 0]
        
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
        
        // G is a 6x1 vector with '(dt^2)/2's in the first 2 entries, 'dt's in second two entries and '1's in the last two entries
        let G = [pow(dt, 2)/2, pow(dt, 2)/2, dt, dt, 1, 1]
        
        // Compute Q from Q = G * G_t * proc_fac. Q is a 6x6 matrix
        var G_G_t = [Double](repeating: 0, count: 36)
        vDSP_mmulD(G, 1, G, 1, &G_G_t, 1, 6, 6, 1)
        
        Q = [Double](repeating: 0, count: 36)
        vDSP_vsmulD(G_G_t, 1, &proc_fac, &Q, 1, 36)
        
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
        
        // P is a 6x6 diagonal matrix with pos_sig entries
        P = [Double]()
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
    
    override func computeAlgorithm(measurements: [Double], successCallback: @escaping (CGPoint) -> Void) {
        predict()
        
        update(measurements: measurements, successCallback: successCallback)
    }
    
    //MARK: Private API
    private func predict() {
        // Compute new state from state = F * state
        vDSP_mmulD(F, 1, state, 1, &state, 1, 6, 1, 6)
        
        // Compute new P from P = F * P * F_t + Q
        var F_P = [Double](repeating: 0, count: F.count)
        vDSP_mmulD(F, 1, P, 1, &F_P, 1, 6, 6, 6)
        
        var F_t = [Double](repeating: 0, count : F.count)
        vDSP_mtransD(F, 1, &F_t, 1, 6, 6)
        
        var F_P_F_t = [Double](repeating: 0, count : F.count)
        vDSP_mmulD(F_P, 1, F_t, 1, &F_P_F_t, 1, 6, 6, 6)
        
        vDSP_vaddD(F_P_F_t, 1, Q, 1, &P, 1, vDSP_Length(Q.count))
    }
    
    private func update(measurements: [Double], successCallback: (CGPoint) -> Void) {
        guard let anchors = IndoorLocationManager.shared.anchors else {
            fatalError("No anchors found!")
        }
        
        let H = H_j(state)
        
        let numAnchPlus2 = vDSP_Length(anchors.count + 2)
        
        // Compute S from S = H * P * H_t + R
        var H_t = [Double](repeating: 0, count : H.count)
        vDSP_mtransD(H, 1, &H_t, 1, 6, numAnchPlus2)
        
        var P_H_t = [Double](repeating: 0, count: H_t.count)
        vDSP_mmulD(P, 1, H_t, 1, &P_H_t, 1, 6, numAnchPlus2, 6)
        
        var H_P_H_t = [Double](repeating: 0, count : 25)
        vDSP_mmulD(H, 1, P_H_t, 1, &H_P_H_t, 1, numAnchPlus2, numAnchPlus2, 6)
        
        var S = [Double](repeating: 0, count : R.count)
        vDSP_vaddD(H_P_H_t, 1, R, 1, &S, 1, vDSP_Length(R.count))
        
        // Compute K from K = P * H_t * S_inv
        var K = [Double](repeating: 0, count: 6 * (anchors.count + 2))
        vDSP_mmulD(P_H_t, 1, S.invert(), 1, &K, 1, 6, numAnchPlus2, numAnchPlus2)
        
        // Compute new state = state + K * (measurements - h(state))
        var innovation = [Double](repeating: 0, count: anchors.count + 2)
        vDSP_vsubD(h(state), 1, measurements, 1, &innovation, 1, numAnchPlus2)
        
        var update = [Double](repeating: 0, count: 6)
        vDSP_mmulD(K, 1, innovation, 1, &update, 1, 6, 1, numAnchPlus2)
        
        vDSP_vaddD(state, 1, update, 1, &state, 1, 6)
        
        // Compute new P from P = P - K * H * P
        var K_H = [Double](repeating: 0, count: 36)
        vDSP_mmulD(K, 1, H, 1, &K_H, 1, 6, 6, numAnchPlus2)
        
        var K_H_P = [Double](repeating: 0, count: 36)
        vDSP_mmulD(K_H, 1, P, 1, &K_H_P, 1, 6, 6, 6)
        
        vDSP_vsubD(K_H_P, 1, P, 1, &P, 1, 36)
        
        let position = CGPoint(x: state[0], y: state[1])
        
        successCallback(position)
    }
    
    private func h(_ state: [Double]) -> [Double] {
        guard let anchors = IndoorLocationManager.shared.anchors else {
            fatalError("No anchors found!")
        }
        
        let anchorCoordinates = anchors.map { $0.position }
        
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
    
    private func H_j(_ state: [Double]) -> [Double] {
        guard let anchors = IndoorLocationManager.shared.anchors else {
            fatalError("No anchors found!")
        }
        
        let anchorCoordinates = anchors.map { $0.position }

        var H_j = [Double]()
        for i in 0..<anchors.count {
            if (state[0] == Double(anchorCoordinates[i].x) && state[1] == Double(anchorCoordinates[i].y)) {
                // If position is exactly the same as an anchor, we would divide by 0. Therefore this
                // case is treated here separately and zeros are added.
                H_j += [0, 0]
            } else {
                H_j.append((state[0] - Double(anchorCoordinates[i].x)) / sqrt(pow(Double(anchorCoordinates[i].x) - state[0], 2) + pow(Double(anchorCoordinates[i].y) - state[1], 2)))
                H_j.append((state[1] - Double(anchorCoordinates[i].y)) / sqrt(pow(Double(anchorCoordinates[i].x) - state[0], 2) + pow(Double(anchorCoordinates[i].y) - state[1], 2)))
            }
            H_j += [0, 0, 0, 0]
        }
        H_j += [0, 0, 0, 0, 1, 0]
        H_j += [0, 0, 0, 0, 0, 1]
        
        return H_j
    }
}

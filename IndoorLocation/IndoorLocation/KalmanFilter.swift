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
    var state: [Double]

    // Matrices
    var F: [Double]
    var Q: [Double]
    var R: [Double]
    var P: [Double]
    
    //TODO: Check how to remove updateTime here without getting a segmentation fault 11
    init?(updateTime: Int? = nil) {
        
        let settings = IndoorLocationManager.shared.filterSettings

        let acc_sig = Double(settings.accelerationUncertainty)
        let pos_sig = Double(settings.distanceUncertainty)
        var proc_fac = Double(settings.processingUncertainty)
        let dt = settings.updateTime
        
        guard let anchors = IndoorLocationManager.shared.anchors,
            let position = IndoorLocationManager.shared.position else {
                print("No anchors found. Calibration has to be executed first!")
                return nil
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
        
        // G is a 6x2 matrix with '(dt^2)/2's in main diagonal, 'dt's in second negative side diagonal and '1's in fourth negative side diagonal
        var G = [Double]()
        for i in 0..<6 {
            for j in 0..<2 {
                if (i == j) {
                    G.append(pow(dt, 2)/2)
                } else if (i == j + 2) {
                    G.append(dt)
                } else if (i == j + 4) {
                    G.append(1)
                } else {
                    G.append(0)
                }
            }
        }
        
        // Compute Q from Q = G * G_t * proc_fac. Q is a 6x6 matrix
        var G_t = [Double](repeating: 0, count : G.count)
        vDSP_mtransD(G, 1, &G_t, 1, 2, 6)
        
        var G_G_t = [Double](repeating: 0, count: 36)
        vDSP_mmulD(G, 1, G_t, 1, &G_G_t, 1, 6, 6, 2)
        
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
    
    override func predict() {
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
    
    override func update(measurements: [Double], successCallback: (CGPoint) -> Void) {
        guard let anchors = IndoorLocationManager.shared.anchors else {
            print("No anchors found!")
            return
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
        vDSP_mmulD(P_H_t, 1, invertMatrix(S), 1, &K, 1, 6, numAnchPlus2, numAnchPlus2)
        
        // Compute new state = state + K * (measurements - h(state))
        var diff = [Double](repeating: 0, count: anchors.count + 2)
        vDSP_vsubD(h(state), 1, measurements, 1, &diff, 1, numAnchPlus2)
        
        var update = [Double](repeating: 0, count: 6)
        vDSP_mmulD(K, 1, diff, 1, &update, 1, 6, 1, numAnchPlus2)
        
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
    
    //MARK: Private API
    private func h(_ state: [Double]) -> [Double] {
        guard let anchors = IndoorLocationManager.shared.anchors else {
            print("No anchors found!")
            return []
        }
        
        let anchorValues = Array(anchors.values)
        
        let xPos = state[0]
        let yPos = state[1]
        let xAcc = state[4]
        let yAcc = state[5]
        
        var h = [Double]()
        for i in 0..<anchors.count {
            h.append(sqrt(pow(Double(anchorValues[i].x) - xPos, 2) + pow(Double(anchorValues[i].y) - yPos, 2)))
        }
        h.append(xAcc)
        h.append(yAcc)
        
        return h
    }
    
    private func H_j(_ state: [Double]) -> [Double] {
        guard let anchors = IndoorLocationManager.shared.anchors else {
            print("No anchors found!")
            return []
        }
        
        let anchorValues = Array(anchors.values)

        var H_j = [Double]()
        for i in 0..<anchors.count {
            if (state[0] == Double(anchorValues[i].x) && state[1] == Double(anchorValues[i].y)) {
                // If position is exactly the same as an anchor, we would divide by 0. Therefore this
                // case is treated here separately and zeros are added.
                H_j += [0, 0]
            } else {
                H_j.append((state[0] - Double(anchorValues[i].x)) / sqrt(pow(Double(anchorValues[i].x) - state[0], 2) + pow(Double(anchorValues[i].y) - state[1], 2)))
                H_j.append((state[1] - Double(anchorValues[i].y)) / sqrt(pow(Double(anchorValues[i].x) - state[0], 2) + pow(Double(anchorValues[i].y) - state[1], 2)))
            }
            H_j += [0, 0, 0, 0]
        }
        H_j += [0, 0, 0, 0, 1, 0]
        H_j += [0, 0, 0, 0, 0, 1]
        
        return H_j
    }
}

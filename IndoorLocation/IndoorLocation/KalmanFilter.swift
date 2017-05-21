//
//  KalmanFilter.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 17.05.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit
import Accelerate

class KalmanFilter: BayesianFilter {
    
    var state: [Double]

    // Matrices
    var F: [Double]
    var Q: [Double]
    var R: [Double]
    var P: [Double]
    
    init?(updateTime: Double, initX: [Double] = [0, 0, 0, 0]) {
        
        let settings = IndoorLocationManager.shared.filterSettings

        let acc_sig = settings.accelerationUncertainty
        let pos_sig = settings.distanceUncertainty
        var proc_fac = settings.processingUncertainty
        
        guard let anchors = IndoorLocationManager.shared.anchors else {
            print("No anchors found. Calibration has to be executed first!")
            return nil
        }
        
        let dt = updateTime
        state = initX + [0, 0]
        
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
                if (i == j && i <= anchors.count) {
                    R.append(pos_sig)
                } else if (i == j && i > anchors.count) {
                    R.append(acc_sig)
                } else {
                    R.append(0)
                }
            }
        }
        
        // P is a 6x6 identity matrix
        P = [Double]()
        for i in 0..<6 {
            for j in 0..<6 {
                if (i == j) {
                    P.append(1)
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
        
        print("Pred pos: \(CGPoint(x: state[0], y: state[1]))")
    }
    
    override func update(measurements: [Double], successCallback: () -> Void) {
        let H = H_j(state)
        
        // Compute S from S = H * P * H_t + R
        var H_t = [Double](repeating: 0, count : H.count)
        vDSP_mtransD(H, 1, &H_t, 1, 6, 5)
        
        var P_H_t = [Double](repeating: 0, count: H_t.count)
        vDSP_mmulD(P, 1, H_t, 1, &P_H_t, 1, 6, 5, 6)
        
        var H_P_H_t = [Double](repeating: 0, count : 25)
        vDSP_mmulD(H, 1, P_H_t, 1, &H_P_H_t, 1, 5, 5, 6)
        
        var S = [Double](repeating: 0, count : R.count)
        vDSP_vaddD(H_P_H_t, 1, R, 1, &S, 1, vDSP_Length(R.count))
        
        // Compute K from K = P * H_t * S_inv
        var K = [Double](repeating: 0, count: 30)
        vDSP_mmulD(P_H_t, 1, invertMatrix(S), 1, &K, 1, 6, 5, 5)
        
        // Compute new state = state + K * (measurements - h(state))
        var diff = [Double](repeating: 0, count: 5)
        vDSP_vsubD(measurements, 1, h(state), 1, &diff, 1, 5)
        
        var update = [Double](repeating: 0, count: 5)
        vDSP_mmulD(K, 1, diff, 1, &update, 1, 6, 1, 5)
        
        vDSP_vaddD(state, 1, update, 1, &state, 1, 5)
        
        // Compute new P from P = P - K * H * P
        var K_H = [Double](repeating: 0, count: 36)
        vDSP_mmulD(K, 1, H, 1, &K_H, 1, 6, 6, 5)
        
        var K_H_P = [Double](repeating: 0, count: 36)
        vDSP_mmulD(K_H, 1, P, 1, &K_H_P, 1, 6, 6, 6)
        
        vDSP_vsubD(P, 1, K_H_P, 1, &P, 1, 36)
        
        position = CGPoint(x: state[0], y: state[1])
        
        print("New pos:  \(position)")
        
        print("Covar. x: \(P[0])")
        print("Covar. y: \(P[6])")
        
        successCallback()
    }
    
    //MARK: Private API
    private func h(_ state: [Double]) -> [Double] {
        let anchors = IndoorLocationManager.shared.anchors!
        
        var h = [Double]()
        for i in 0..<anchors.count {
            h.append(sqrt(pow(Double(anchors[i].x) - state[0], 2) + pow(Double(anchors[i].y) - state[1], 2)))
        }
        h.append(state[4])
        h.append(state[5])
        
        return h
    }
    
    private func H_j(_ state: [Double]) -> [Double] {
        let anchors = IndoorLocationManager.shared.anchors!

        var H_j = [Double]()
        for i in 0..<anchors.count {
            if (state[0] == Double(anchors[i].x) && state[1] == Double(anchors[i].y)) {
                H_j += [0, 0]
            } else {
                H_j.append((state[0] - Double(anchors[i].x)) / sqrt(pow(Double(anchors[i].x) - state[0], 2) + pow(Double(anchors[i].y) - state[1], 2)))
                H_j.append((state[1] - Double(anchors[i].y)) / sqrt(pow(Double(anchors[i].x) - state[0], 2) + pow(Double(anchors[i].y) - state[1], 2)))
            }
            H_j += [0, 0, 0, 0]
        }
        H_j += [0, 0, 0, 0, 1, 0]
        H_j += [0, 0, 0, 0, 0, 1]
        
        return H_j
    }
}

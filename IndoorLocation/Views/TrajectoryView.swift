//
//  TrajectoryView.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 29.06.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

class TrajectoryView: UIView {
    
    var trajectory: [CGPoint]
    
    private var trajectoryLayer = CAShapeLayer()
    
    init(trajectory: [CGPoint]) {
        self.trajectory = trajectory
        
        var width: CGFloat = 0
        var height: CGFloat = 0
        if !trajectory.isEmpty {
            width = trajectory.map { $0.x }.max()! - trajectory.map { $0.x }.min()!
            height = trajectory.map { $0.y }.max()! - trajectory.map { $0.y }.min()!
        }
        
        let frameRect = CGRect(x: 0, y: 0, width: width, height: height)
        
        super.init(frame: frameRect)
        
        backgroundColor = .clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        
        let trajectoryPath = UIBezierPath()
        trajectoryPath.move(to: trajectory[0])
        trajectory.forEach { trajectoryPath.addLine(to: $0) }
        
        trajectoryLayer = CAShapeLayer()
        trajectoryLayer.path = trajectoryPath.cgPath
        trajectoryLayer.fillColor = UIColor.clear.cgColor
        trajectoryLayer.strokeColor = UIColor.black.cgColor
        trajectoryLayer.lineWidth = 1
        
        layer.addSublayer(trajectoryLayer)
    }
    
    func updateTrajectory(_ trajectory: [CGPoint]) {
        let width = trajectory.map { $0.x }.max()! - trajectory.map { $0.x }.min()!
        let height = trajectory.map { $0.y }.max()! - trajectory.map { $0.y }.min()!
        
        frame = CGRect(x: 0, y: 0, width: width, height: height)
        
        trajectoryLayer.removeFromSuperlayer()
        
        let trajectoryPath = UIBezierPath()
        trajectoryPath.move(to: trajectory[0])
        trajectory.forEach { trajectoryPath.addLine(to: $0) }
        
        trajectoryLayer = CAShapeLayer()
        trajectoryLayer.path = trajectoryPath.cgPath
        trajectoryLayer.fillColor = UIColor.clear.cgColor
        trajectoryLayer.strokeColor = UIColor.black.cgColor
        trajectoryLayer.lineWidth = 1
        
        layer.addSublayer(trajectoryLayer)
    }
}

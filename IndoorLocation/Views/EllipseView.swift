//
//  CovarianceView.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 29.06.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

enum EllipseType {
    case covariance((a: CGFloat, b: CGFloat, angle: CGFloat))
    case distance(radius: CGFloat)
}

/**
 View that displays an ellipse. This can be the measured distances of an anchor or the covariance of the Kalman filter.
 */
class EllipseView: UIView {
    
    let ellipseType: EllipseType
    private var ellipseLayer = CAShapeLayer()
    
    init(ellipseType: EllipseType, position: CGPoint) {
        self.ellipseType = ellipseType
        
        // Set the frame of the view
        var width: CGFloat
        var height: CGFloat
        var rotationAngle: CGFloat?
        
        switch ellipseType {
        case .covariance(let covariance):
            width = covariance.a
            height = covariance.b
            rotationAngle = covariance.angle
        case .distance(let radius):
            width = 2 * radius
            height = 2 * radius
        }
        
        let frameRect = CGRect(x: position.x - width / 2, y: position.y - height / 2, width: width, height: height)
        
        super.init(frame: frameRect)
        
        backgroundColor = .clear
        
        if let rotationAngle = rotationAngle {
            transform = CGAffineTransform(rotationAngle: rotationAngle)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        // Draw the ellipse within the frame's bounds
        let ellipsePath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        
        ellipseLayer = CAShapeLayer()
        ellipseLayer.path = ellipsePath.cgPath
        ellipseLayer.fillColor = UIColor.clear.cgColor
        // Choose the line color depending on the ellipse type
        switch ellipseType {
        case .covariance(_):
            ellipseLayer.strokeColor = UIColor.Application.orange.cgColor
            ellipseLayer.lineWidth = 2
        case .distance(_):
            ellipseLayer.strokeColor = UIColor.Application.darkRed.cgColor
            ellipseLayer.lineWidth = 1
        }
        
        layer.addSublayer(ellipseLayer)
    }
    
    /**
     Updates the shape and position of the ellipse. 
     */
    func updateEllipse(withEllipseType ellipseType: EllipseType, position: CGPoint? = nil) {
        
        var width: CGFloat
        var height: CGFloat
        var rotationAngle: CGFloat?
        
        switch ellipseType {
        case .covariance(let covariance):
            width = covariance.a
            height = covariance.b
            rotationAngle = covariance.angle
        case .distance(let radius):
            width = 2 * radius
            height = 2 * radius
        }

        bounds.size = CGSize(width: width, height: height)

        center = position ?? center
        
        if let rotationAngle = rotationAngle {
            transform.rotated(by: rotationAngle)
        }
        
        let ellipsePath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
        ellipseLayer.path = ellipsePath.cgPath
    }
}

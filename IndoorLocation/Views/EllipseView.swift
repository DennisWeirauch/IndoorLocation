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

class EllipseView: UIView {
    
    let ellipseType: EllipseType
    private var ellipseLayer = CAShapeLayer()
    
    init(ellipseType: EllipseType, position: CGPoint) {
        self.ellipseType = ellipseType
        
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
        let ellipsePath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        
        ellipseLayer = CAShapeLayer()
        ellipseLayer.path = ellipsePath.cgPath
        ellipseLayer.fillColor = UIColor.clear.cgColor
        switch ellipseType {
        case .covariance(_):
            ellipseLayer.strokeColor = UIColor.orange.cgColor
            ellipseLayer.lineWidth = 2
        case .distance(_):
            ellipseLayer.strokeColor = UIColor.red.cgColor
            ellipseLayer.lineWidth = 1
        }
        
        layer.addSublayer(ellipseLayer)
    }
    
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
        
        let frameCenter = position ?? center
        frame = CGRect(x: frameCenter.x - width / 2, y: frameCenter.y - height / 2, width: width, height: height)
        
        let ellipsePath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: width, height: height))
        ellipseLayer.path = ellipsePath.cgPath
        
        if let rotationAngle = rotationAngle {
            transform = CGAffineTransform(rotationAngle: rotationAngle)
        }
    }
}

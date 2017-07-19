//
//  CovarianceView.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 29.06.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

enum EllipseType {
    case covariance((x: Float, y: Float))
    case distance(radius: Float)
}

class EllipseView: UIView {
    
    let ellipseType: EllipseType
    private var ellipseLayer = CAShapeLayer()
    
    init(ellipseType: EllipseType, position: CGPoint) {
        self.ellipseType = ellipseType
        
        var width: CGFloat
        var height: CGFloat
        
        switch ellipseType {
        case .covariance(let covariance):
            width = 2 * CGFloat(covariance.x)
            height = 2 * CGFloat(covariance.y)
        case .distance(let radius):
            width = 2 * CGFloat(radius)
            height = 2 * CGFloat(radius)
        }
        
        let frameRect = CGRect(x: position.x - width / 2, y: position.y - height / 2, width: width, height: height)
        
        super.init(frame: frameRect)
        
        backgroundColor = .clear
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
        
        switch ellipseType {
        case .covariance(let covariance):
            //FIXME: Remove multiplication by 5
            width = 2 * CGFloat(covariance.x * 5)
            height = 2 * CGFloat(covariance.y * 5)
        case .distance(let radius):
            width = 2 * CGFloat(radius)
            height = 2 * CGFloat(radius)
        }
        
        let frameCenter = position ?? center
        frame = CGRect(x: frameCenter.x - width / 2, y: frameCenter.y - height / 2, width: width, height: height)
        
        let ellipsePath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: width, height: height))
        ellipseLayer.path = ellipsePath.cgPath
    }
}

//
//  CovarianceView.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 29.06.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

class CovarianceView: UIView {
    
    var covariance: (x: Float, y: Float)
    private var covarianceLayer = CAShapeLayer()
    
    init(position: CGPoint, covariance: (x: Float, y: Float)) {
        self.covariance = covariance
        
        let width = CGFloat(covariance.x)
        let height = CGFloat(covariance.y)
        
        let frameRect = CGRect(x: position.x - width / 2, y: position.y - height / 2, width: width, height: height)
        
        super.init(frame: frameRect)
        
        backgroundColor = .clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        
        let covariancePath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        
        covarianceLayer = CAShapeLayer()
        covarianceLayer.path = covariancePath.cgPath
        covarianceLayer.strokeColor = UIColor.orange.cgColor
        covarianceLayer.fillColor = UIColor.clear.cgColor
        covarianceLayer.lineWidth = 2
        
        layer.addSublayer(covarianceLayer)
    }
    
    func updateCovariance(position: CGPoint, covariance: (x: Float, y: Float)) {
        
        let width = CGFloat(covariance.x * 10)
        let height = CGFloat(covariance.y * 10)
        frame = CGRect(x: position.x - width / 2, y: position.y - height / 2, width: width, height: height)
        
        // Redraw covariance
        covarianceLayer.removeFromSuperlayer()
        
        let covariancePath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: width, height: height))
        
        covarianceLayer = CAShapeLayer()
        covarianceLayer.path = covariancePath.cgPath
        covarianceLayer.strokeColor = UIColor.orange.cgColor
        covarianceLayer.fillColor = UIColor.clear.cgColor
        covarianceLayer.lineWidth = 2
        
        layer.addSublayer(covarianceLayer)
    }
}

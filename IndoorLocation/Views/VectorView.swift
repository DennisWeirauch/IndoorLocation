//
//  VectorView.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 26.07.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

class VectorView: UIView {
    
    let pointSize: CGFloat = 6
    private var vectorLayer = CAShapeLayer()
    
    init(origin: CGPoint, vector: CGSize) {
        
        var frameOrigin: CGPoint
        var frameSize: CGSize
        
        if vector.height == 0 {
            frameOrigin = CGPoint(x: origin.x, y: origin.y - pointSize / 2)
            frameSize = CGSize(width: 10, height: pointSize)
        } else if vector.width == 0 {
            frameOrigin = CGPoint(x: origin.x - pointSize / 2, y: origin.y)
            frameSize = CGSize(width: pointSize, height: 10)
        } else {
            fatalError("Vector has to be initialized with unit vector!")
        }
        
        let frameRect = CGRect(origin: frameOrigin, size: frameSize)
        super.init(frame: frameRect)
        
        backgroundColor = .clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        
        let vectorPath = UIBezierPath(roundedRect: CGRect(origin: CGPoint.zero, size: rect.size), cornerRadius: pointSize / 2)
        
        vectorLayer = CAShapeLayer()
        vectorLayer.path = vectorPath.cgPath
        
        vectorLayer.fillColor = UIColor.blue.cgColor
        
        layer.addSublayer(vectorLayer)
    }
    
    func updateVector(withOrigin origin: CGPoint, vector: CGSize) {

        var frameOrigin: CGPoint
        var frameSize: CGSize

        if vector.height == 0 {
            frameOrigin = CGPoint(x: origin.x, y: origin.y - pointSize / 2)
            frameSize = CGSize(width: vector.width, height: pointSize)
        } else if vector.width == 0 {
            frameOrigin = CGPoint(x: origin.x - pointSize / 2, y: origin.y)
            frameSize = CGSize(width: pointSize, height: vector.height)
        } else {
            return
        }
        
        frame.origin = frameOrigin
        frame.size = frameSize
        
        let vectorPath = UIBezierPath(roundedRect: CGRect(origin: CGPoint.zero, size: frame.size), cornerRadius: pointSize / 2)
        vectorLayer.path = vectorPath.cgPath
    }
}

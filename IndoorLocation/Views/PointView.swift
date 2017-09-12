//
//  PointView.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 27.06.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

enum PointType {
    case position(CGPoint)
    case anchor(Anchor)
    case particle(Particle)
}

/**
 View that displays a point. This can be the position of the agent, the anchors or the particles.
 */
class PointView: UIView {
    
    private(set) var pointSize: CGFloat
    let pointType: PointType
    
    init(pointType: PointType) {
        self.pointType = pointType
        
        // Set the frame of the view
        var width: CGFloat
        var pointPosition: CGPoint
        
        switch pointType {
        case .position(let position):
            pointSize = 20
            width = pointSize
            pointPosition = position
        case .anchor(let anchor):
            pointSize = 20
            width = 5 * pointSize
            pointPosition = anchor.position
        case .particle(let particle):
            pointSize = 5
            width = pointSize
            pointPosition = particle.position
        }
        
        let frameRect = CGRect(x: pointPosition.x - pointSize / 2, y: pointPosition.y - pointSize / 2, width: width, height: pointSize)
        super.init(frame: frameRect)
        
        backgroundColor = .clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        // Draw the point with the specified point size
        let pointPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: pointSize, height: pointSize))
        
        let pointLayer = CAShapeLayer()
        pointLayer.path = pointPath.cgPath
        
        switch pointType {
        case .position:
            pointLayer.fillColor = UIColor.Application.darkBlue.cgColor
            
        case .anchor(let anchor):
            pointLayer.fillColor = anchor.isActive ? UIColor.Application.darkRed.cgColor : UIColor.gray.cgColor
            
            // Draw the ID Label of an anchor
            let attributes = [
                NSFontAttributeName: UIFont.systemFont(ofSize: pointSize),
                NSForegroundColorAttributeName: anchor.isActive ? UIColor.Application.darkRed : UIColor.gray,
                ] as [String : Any]
            
            let idString = NSString(format: "%2X", anchor.id)
            idString.draw(at: CGPoint(x: 1.25 * pointSize, y: 0), withAttributes: attributes)
            
        case .particle:
            pointLayer.fillColor = UIColor.Application.orange.cgColor
        }
        
        layer.addSublayer(pointLayer)
    }
    
    /**
     Updates the position of the point.
     */
    func updatePoint(withPointType pointType: PointType) {
        var pointPosition: CGPoint
        
        switch pointType {
        case .position(let position):
            pointPosition = position
        case .anchor(let anchor):
            pointPosition = anchor.position
        case .particle(let particle):
            pointPosition = particle.position
        }
        
        frame.origin = CGPoint(x: pointPosition.x - pointSize / 2, y: pointPosition.y - pointSize / 2)
    }
}

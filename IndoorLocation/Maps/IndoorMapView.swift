//
//  IndoorMapView.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 13.06.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

class IndoorMapView: UIView, UIGestureRecognizerDelegate {

    var mapView: UIView!

    var tx: CGFloat = 0.0
    var ty: CGFloat = 0.0
    var scale: CGFloat = 1.0
    var angle: CGFloat = 0.0
    var initScale: CGFloat = 1.0
    var initAngle: CGFloat = 0.0
    
    override init(frame: CGRect) {
        
        super.init(frame: frame)
        
        backgroundColor = .white
        
        setupMapView()
        addSubview(mapView)
        
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        rotationGesture.delegate = self
        addGestureRecognizer(rotationGesture)
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinchGesture.delegate = self
        addGestureRecognizer(pinchGesture)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        panGesture.maximumNumberOfTouches = 1
        addGestureRecognizer(panGesture)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: UIGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if (gestureRecognizer.view != otherGestureRecognizer.view) {
            return false
        }
        if (!gestureRecognizer.isKind(of: UITapGestureRecognizer.self) && !otherGestureRecognizer.isKind(of: UITapGestureRecognizer.self)) {
            return true
        }
        return false
    }
    
    //MARK: Private API
    private func setupMapView() {
        mapView = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 600))
        
        // Just for debugging
        mapView.backgroundColor = .lightGray
        
        UIGraphicsGetCurrentContext()
        
        let firstDotPath = UIBezierPath(ovalIn: CGRect(x: 100, y: 200, width: 8, height: 8))
        
        let firstDotLayer = CAShapeLayer()
        firstDotLayer.path = firstDotPath.cgPath
        firstDotLayer.strokeColor = UIColor.blue.cgColor
        
        mapView.layer.addSublayer(firstDotLayer)
        
        let secondDotPath = UIBezierPath(ovalIn: CGRect(x: 200, y: 200, width: 8, height: 8))
        
        let secondDotLayer = CAShapeLayer()
        secondDotLayer.path = secondDotPath.cgPath
        secondDotLayer.strokeColor = UIColor.blue.cgColor
        
        mapView.layer.addSublayer(secondDotLayer)
    }
    
    private func setAnchor(_ anchorPoint: CGPoint, forView view: UIView) {
        let oldOrigin: CGPoint = view.frame.origin
        view.layer.anchorPoint = anchorPoint
        let newOrigin = view.frame.origin
        let transition = CGPoint(x: newOrigin.x - oldOrigin.x, y: newOrigin.y - oldOrigin.y)
        let newCenter = CGPoint(x: view.center.x - transition.x, y: view.center.y - transition.y)
        view.center = newCenter
    }
    
    private func updateTransformWithOffset(_ offset: CGPoint) {
        mapView.transform = CGAffineTransform(translationX: offset.x + tx, y: offset.y + ty)
        mapView.transform = mapView.transform.rotated(by: angle)
        mapView.transform = mapView.transform.scaledBy(x: scale, y: scale)
    }
    
    private func adjustAnchorPointForGestureRecognizer(_ recognizer: UIGestureRecognizer) {
        if (recognizer.state == .began) {
            tx = mapView.transform.tx
            ty = mapView.transform.ty
            let locationInView = recognizer.location(in: mapView)
            let newAnchor = CGPoint(x: (locationInView.x / mapView.bounds.size.width), y: (locationInView.y / mapView.bounds.size.height))
            setAnchor(newAnchor, forView: mapView)
        }
    }
    
    func handleRotation(_ recognizer: UIRotationGestureRecognizer) {
        if (recognizer.state == .began) {
            initAngle = angle
        }
        angle = initAngle + recognizer.rotation
        adjustAnchorPointForGestureRecognizer(recognizer)
        updateTransformWithOffset(CGPoint.zero)
    }
    
    func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        if recognizer.state == .began {
            initScale = scale
        }
        scale = initScale * recognizer.scale
        adjustAnchorPointForGestureRecognizer(recognizer)
        updateTransformWithOffset(CGPoint.zero)
    }
    
    func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: mapView.superview)
        adjustAnchorPointForGestureRecognizer(recognizer)
        updateTransformWithOffset(translation)
    }
}

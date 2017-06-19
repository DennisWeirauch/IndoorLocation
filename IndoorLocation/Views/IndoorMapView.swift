//
//  IndoorMapView.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 13.06.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

enum PointType {
    case position
    case anchor
    case covariance
    case particle
}

class IndoorMapView: UIView, UIGestureRecognizerDelegate {

    var mapView: UIView!
    
    var filterType = FilterType.none {
        didSet {
            switch filterType {
            case .none:
                covarianceLayer.removeFromSuperlayer()
                particleLayers.forEach { $0.removeFromSuperlayer() }
            case .kalman:
                particleLayers.forEach { $0.removeFromSuperlayer() }
            case .particle:
                covarianceLayer.removeFromSuperlayer()
            }
        }
    }

    var lastPositions = [CGPoint]()
    
    var position: CGPoint? {
        didSet {
            if lastPositions.count >= 20 {
                lastPositions.removeFirst()
            }
            if let oldValue = oldValue {
                lastPositions.append(oldValue)
            }
            updatePosition()
        }
    }
    
    var anchors: [Anchor]? {
        didSet {
            updateAnchors()
        }
    }
    
    var covariance: (x: Double, y: Double)? {
        didSet {
            updateCovariance()
        }
    }
    
    var particles: [Particle]? {
        didSet {
            updateParticles()
        }
    }
    
    var positionLayer = CAShapeLayer()
    var anchorLayers = [CAShapeLayer]()
    var covarianceLayer = CAShapeLayer()
    var particleLayers = [CAShapeLayer]()
    var trajectoryLayer = CAShapeLayer()

    // Variables used for zooming, rotating and panning the mapView
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
        
        setupGestureRecognizers()
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
        mapView = UIView(frame: CGRect(x: 0, y: 0, width: 1000, height: 1000))
        addSubview(mapView)
    }
    
    private func setupGestureRecognizers() {
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
    
    private func adjustedSizeForType(_ pointType: PointType) -> CGFloat {
        switch pointType {
        case .position:
            return min(50 / scale, 250)
        case .anchor:
            return min(50 / scale, 250)
        case .covariance:
            return min(30 / scale, 150)
        case .particle:
            return min(30 / scale, 150)
        }
    }
    
    private func updatePoints() {
        updatePosition()
        updateAnchors()
        
        switch filterType {
        case .kalman:
            updateCovariance()
        case .particle:
            updateParticles()
        default:
            break
        }
    }
    
    private func updatePosition() {
        guard let position = position else { return }
        
        UIGraphicsGetCurrentContext()
        
        // Update trajectory
        trajectoryLayer.removeFromSuperlayer()
        
        let trajectory = UIBezierPath()
        trajectory.move(to: position)
        lastPositions.reversed().forEach { trajectory.addLine(to: $0) }
        
        trajectoryLayer = CAShapeLayer()
        trajectoryLayer.path = trajectory.cgPath
        trajectoryLayer.fillColor = UIColor.clear.cgColor
        trajectoryLayer.strokeColor = UIColor.black.cgColor
        trajectoryLayer.lineWidth = 15
        
        mapView.layer.addSublayer(trajectoryLayer)
        
        // Update point
        positionLayer.removeFromSuperlayer()
        
        let pointSize = adjustedSizeForType(.position)
        let positionPath = UIBezierPath(ovalIn: CGRect(x: position.x - pointSize / 2, y: position.y - pointSize / 2, width: pointSize, height: pointSize))
        
        positionLayer = CAShapeLayer()
        positionLayer.path = positionPath.cgPath
        positionLayer.fillColor = UIColor.green.cgColor
        
        mapView.layer.addSublayer(positionLayer)
    }
    
    private func updateAnchors() {
        guard let anchors = anchors else { return }
        
        UIGraphicsGetCurrentContext()
        
        anchorLayers.forEach { $0.removeFromSuperlayer() }
        anchorLayers.removeAll()
        
        for anchor in anchors {
            let pointSize = adjustedSizeForType(.anchor)
            let anchorPath = UIBezierPath(ovalIn: CGRect(x: anchor.position.x - pointSize / 2, y: anchor.position.y - pointSize / 2, width: pointSize, height: pointSize))
            
            let anchorLayer = CAShapeLayer()
            anchorLayer.path = anchorPath.cgPath
            anchorLayer.fillColor = UIColor.red.cgColor
            
            mapView.layer.addSublayer(anchorLayer)
            anchorLayers.append(anchorLayer)
        }
    }
    
    private func updateCovariance() {
        guard let position = position, let covariance = covariance else { return }
        
        UIGraphicsGetCurrentContext()
        
        covarianceLayer.removeFromSuperlayer()
        
        let width = adjustedSizeForType(.covariance) * CGFloat(covariance.x)
        let height = adjustedSizeForType(.covariance) * CGFloat(covariance.y)
        let covariancePath = UIBezierPath(ovalIn: CGRect(x: position.x - width / 2, y: position.y - height / 2, width: width, height: height))
        
        covarianceLayer = CAShapeLayer()
        covarianceLayer.path = covariancePath.cgPath
        covarianceLayer.strokeColor = UIColor.yellow.cgColor
        covarianceLayer.fillColor = UIColor.clear.cgColor
        covarianceLayer.lineWidth = 15
        
        mapView.layer.addSublayer(covarianceLayer)
    }
    
    private func updateParticles() {
        guard let particles = particles else { return }
        
        UIGraphicsGetCurrentContext()
        
        particleLayers.forEach { $0.removeFromSuperlayer() }
        particleLayers.removeAll()
        
        for particle in particles {
            let pointSize: CGFloat = adjustedSizeForType(.particle)
            let particlePath = UIBezierPath(ovalIn: CGRect(x: particle.position.x - pointSize / 2, y: particle.position.y - pointSize / 2, width: pointSize, height: pointSize))
            
            let particleLayer = CAShapeLayer()
            particleLayer.path = particlePath.cgPath
            particleLayer.fillColor = UIColor.blue.cgColor
            
            mapView.layer.addSublayer(particleLayer)
            particleLayers.append(particleLayer)
        }
    }
    
    //MARK: IBActions
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
        updatePoints()
    }
    
    func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: mapView.superview)
        adjustAnchorPointForGestureRecognizer(recognizer)
        updateTransformWithOffset(translation)
    }
}

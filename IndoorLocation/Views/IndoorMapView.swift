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
    
    var isFloorPlanVisible = false {
        didSet {
            floorplanView?.isHidden = !isFloorPlanVisible
        }
    }
    
    var floorplanView: UIImageView?
    
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
    var anchorLabels = [UILabel]()
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
        setupFloorplan()
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
    
    private func setupFloorplan() {
        // Initialize floorplanView
        guard let url = Bundle.main.url(forResource: "room_10_blueprint", withExtension: "pdf") else { return }
        guard let pdfPage = CGPDFDocument(url as CFURL)?.page(at: 1) else { return }
        
        let pageRect = pdfPage.getBoxRect(.trimBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        let floorplan = renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(pageRect)
            
            ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height);
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0);
            
            ctx.cgContext.drawPDFPage(pdfPage);
        }
        floorplanView = UIImageView(image: floorplan)
        floorplanView?.isHidden = true
        mapView.addSubview(floorplanView!)
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
            return min(10 / scale, 50)
        case .anchor:
            return min(10 / scale, 50)
        case .covariance:
            return min(5 / scale, 25)
        case .particle:
            return min(5 / scale, 25)
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
                
        // Update trajectory
        trajectoryLayer.removeFromSuperlayer()
        
        let trajectory = UIBezierPath()
        trajectory.move(to: position)
        lastPositions.reversed().forEach { trajectory.addLine(to: $0) }
        
        trajectoryLayer = CAShapeLayer()
        trajectoryLayer.path = trajectory.cgPath
        trajectoryLayer.fillColor = UIColor.clear.cgColor
        trajectoryLayer.strokeColor = UIColor.black.cgColor
        trajectoryLayer.lineWidth = 1
        
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
        
        anchorLayers.forEach { $0.removeFromSuperlayer() }
        anchorLayers.removeAll()
        
        anchorLabels.forEach { $0.removeFromSuperview() }
        anchorLabels.removeAll()
        
        for anchor in anchors {
            let pointSize = adjustedSizeForType(.anchor)
            let anchorPath = UIBezierPath(ovalIn: CGRect(x: anchor.position.x - pointSize / 2, y: anchor.position.y - pointSize / 2, width: pointSize, height: pointSize))
            
            let anchorLayer = CAShapeLayer()
            anchorLayer.path = anchorPath.cgPath
            anchorLayer.fillColor = UIColor.red.cgColor
            
            mapView.layer.addSublayer(anchorLayer)
            anchorLayers.append(anchorLayer)
            
            // Label
            let idLabel = UILabel(frame: CGRect(x: anchor.position.x + pointSize / 2, y: anchor.position.y - pointSize / 2, width: 30, height: 20))
            LabelHelper.setupLabel(idLabel, withText: String(format: "%2X", anchor.id), fontSize: 13, textColor: .red, alignment: .left)
            mapView.addSubview(idLabel)
            anchorLabels.append(idLabel)
        }
    }
    
    private func updateCovariance() {
        guard let position = position, let covariance = covariance else { return }
        
        covarianceLayer.removeFromSuperlayer()
        
        let width = adjustedSizeForType(.covariance) * CGFloat(covariance.x)
        let height = adjustedSizeForType(.covariance) * CGFloat(covariance.y)
        let covariancePath = UIBezierPath(ovalIn: CGRect(x: position.x - width / 2, y: position.y - height / 2, width: width, height: height))
        
        covarianceLayer = CAShapeLayer()
        covarianceLayer.path = covariancePath.cgPath
        covarianceLayer.strokeColor = UIColor.yellow.cgColor
        covarianceLayer.fillColor = UIColor.clear.cgColor
        covarianceLayer.lineWidth = 2
        
        mapView.layer.addSublayer(covarianceLayer)
    }
    
    private func updateParticles() {
        guard let particles = particles else { return }
        
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

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
                covarianceView?.removeFromSuperview()
                covarianceView = nil
                particleViews?.forEach { $0.removeFromSuperview() }
                particleViews = nil
            case .kalman:
                particleViews?.forEach { $0.removeFromSuperview() }
                particleViews = nil
            case .particle:
                covarianceView?.removeFromSuperview()
                covarianceView = nil
            }
        }
    }

    var lastPositions = [CGPoint]()
    
    var position: CGPoint? {
        didSet {
            if lastPositions.count >= 20 {
                lastPositions.removeFirst()
            }
            if let position = position {
                lastPositions.append(position)
            }
            updatePosition()
        }
    }
    
    var anchors: [Anchor]? {
        didSet {
            setAnchors()
        }
    }
    
    var covariance: (x: Float, y: Float)? {
        didSet {
            updateCovariance()
        }
    }
    
    var particles: [Particle]? {
        didSet {
            updateParticles()
        }
    }
    
    var positionView: PointView?
    var anchorViews: [PointView]?
    var particleViews: [PointView]?
    var covarianceView: CovarianceView?
    var trajectoryView: TrajectoryView?

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
    
    private func setAnchors() {
        guard let anchors = anchors else { return }
        
        if let anchorViews = anchorViews {
            anchorViews.forEach { $0.removeFromSuperview() }
        }
        
        anchorViews = [PointView]()
        
        for anchor in anchors {
            let anchorView = PointView(pointType: .anchor(anchor))
            mapView.addSubview(anchorView)
            anchorViews?.append(anchorView)
        }
    }
    
    private func updatePosition() {
        guard let position = position else { return }
        
        if let positionView = positionView {
            positionView.updatePoint(withPointType: .position(position))
        } else {
            positionView = PointView(pointType: .position(position))
            mapView.addSubview(positionView!)
        }
        
        mapView.bringSubview(toFront: positionView!)
        
        // Update trajectory
        if let trajectoryView = trajectoryView {
            trajectoryView.updateTrajectory(lastPositions.reversed())
        } else {
            trajectoryView = TrajectoryView(trajectory: lastPositions.reversed())
            mapView.addSubview(trajectoryView!)
        }
    }
    
    private func updateCovariance() {
        guard let position = position, let covariance = covariance else { return }
        
        if let covarianceView = covarianceView {
            covarianceView.updateCovariance(position: position, covariance: covariance)
        } else {
            covarianceView = CovarianceView(position: position, covariance: covariance)
            mapView.addSubview(covarianceView!)
        }
    }
    
    private func updateParticles() {
        guard let particles = particles else { return }
        
        if particles.count == particleViews?.count {
            for i in 0..<particles.count {
                particleViews?[i].updatePoint(withPointType: .particle(particles[i]))
            }
        } else {
            particleViews?.forEach { $0.removeFromSuperview() }
            particleViews = [PointView]()
            
            for particle in particles {
                let particleView = PointView(pointType: .particle(particle))
                mapView.addSubview(particleView)
                mapView.sendSubview(toBack: particleView)
                particleViews?.append(particleView)
            }
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
    }
    
    func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: mapView.superview)
        adjustAnchorPointForGestureRecognizer(recognizer)
        updateTransformWithOffset(translation)
    }
}

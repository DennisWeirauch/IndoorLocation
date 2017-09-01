//
//  IndoorMapView.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 13.06.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

protocol IndoorMapViewDelegate {
    func didDoCalibrationFromView(newAnchors: [Anchor])
}

/**
 This class manages the display of the indoor positioning system.
 */
class IndoorMapView: UIView, UIGestureRecognizerDelegate {

    //MARK: Public variables
    var isFloorplanVisible = false {
        didSet {
            floorplanView.isHidden = !isFloorplanVisible
        }
    }
    
    var areMeasurementsVisible = true {
        didSet {
            if !areMeasurementsVisible {
                distanceViews?.forEach { $0.removeFromSuperview() }
                distanceViews = nil
            } else {
                updateAnchorDistances()
            }
        }
    }
    
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
    
    var covariance: (a: CGFloat, b: CGFloat, angle: CGFloat)? {
        didSet {
            updateCovariance()
        }
    }
    
    var particles: [Particle]? {
        didSet {
            updateParticles()
        }
    }
    
    var anchorDistances: [CGFloat]? {
        didSet {
            if areMeasurementsVisible {
                updateAnchorDistances()
            }
        }
    }
    
    var acceleration: [CGFloat]? {
        didSet {
            if areMeasurementsVisible {
                updateAcceleration()
            }
        }
    }
    
    var delegate: IndoorMapViewDelegate?

    //MARK: Private variables
    private var mapView: UIView!

    private var floorplanView: UIImageView!

    private var positionView: PointView?
    private var anchorViews: [PointView]?
    private var particleViews: [PointView]?
    private var covarianceView: EllipseView?
    private var trajectoryView: TrajectoryView?
    private var distanceViews: [EllipseView]?
    private var accelerationViews: [VectorView]?
    
    private var calibrationButton: UIButton!
    private var cancelCalibrationButton: UIButton!
    
    private var lastPositions = [CGPoint]()
    
    // Variables used for zooming, rotating and panning the mapView
    private var tx: CGFloat = 0.0
    private var ty: CGFloat = 0.0
    private var scale: CGFloat = 1.0
    private var angle: CGFloat = 0.0
    private var initScale: CGFloat = 1.0
    private var initAngle: CGFloat = 0.0
    
    //MARK: Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = .white
        
        setupView()
        setupGestureRecognizers()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: Private API
    /**
     Sets up the view. Initializes the mapView, floorplanView and calibrationButtons.
     */
    private func setupView() {
        // Set up mapView
        mapView = UIView(frame: CGRect(x: 0, y: 0, width: 10000, height: 10000))
        addSubview(mapView)
        
        // Set up floorplanView
        guard let url = Bundle.main.url(forResource: "floorplan", withExtension: "pdf") else { return }
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
        floorplanView.isHidden = !isFloorplanVisible
        mapView.addSubview(floorplanView)
        
        // Set up cancelCalibrationButton
        cancelCalibrationButton = UIButton(frame: CGRect(x: frame.width / 8, y: frame.maxY - 120, width: 50, height: 50))
        cancelCalibrationButton.setImage(UIImage(named: "cancelIcon"), for: .normal)
        cancelCalibrationButton.addTarget(self, action: #selector(didTapCancelCalibrationButton(_:)), for: .touchUpInside)
        cancelCalibrationButton.isHidden = true
        addSubview(cancelCalibrationButton)
        
        // Set up calibrationButton
        calibrationButton = UIButton(frame: CGRect(x: cancelCalibrationButton.frame.maxX + 5, y: frame.maxY - 120, width: 3 * frame.width / 4 - 55, height: 50))
        calibrationButton.layer.cornerRadius = calibrationButton.frame.height / 2
        calibrationButton.backgroundColor = .blue
        calibrationButton.setTitle("Calibrate from view", for: .normal)
        calibrationButton.addTarget(self, action: #selector(didTapCalibrationButton(_:)), for: .touchUpInside)
        calibrationButton.isHidden = true
        addSubview(calibrationButton)
    }
    
    /**
     Sets up the gesture recognizers for panning, rotating and zooming the map.
     */
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
    
    // Functions used for zooming, rotating and panning the mapView
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
    
    private func setAnchor(_ anchorPoint: CGPoint, forView view: UIView) {
        let oldOrigin: CGPoint = view.frame.origin
        view.layer.anchorPoint = anchorPoint
        let newOrigin = view.frame.origin
        let transition = CGPoint(x: newOrigin.x - oldOrigin.x, y: newOrigin.y - oldOrigin.y)
        let newCenter = CGPoint(x: view.center.x - transition.x, y: view.center.y - transition.y)
        view.center = newCenter
    }
    
    // Functions to show views for indoor location tracking
    /**
     Function that is called when the set of anchors was changed. The anchorViews array is replaced with new views.
     */
    private func setAnchors() {
        guard let anchors = anchors else { return }
        
        // Clear anchorViews
        if let anchorViews = anchorViews {
            anchorViews.forEach { $0.removeFromSuperview() }
        }
        anchorViews = [PointView]()
        
        // Create new PointViews and add them to anchorViews
        for anchor in anchors {
            let anchorView = PointView(pointType: .anchor(anchor))
            mapView.addSubview(anchorView)
            anchorViews?.append(anchorView)
            
            // Add Gesture Recognizer
            anchorView.isUserInteractionEnabled = true
            let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(draggedAnchor(_:)))
            anchorView.addGestureRecognizer(panGestureRecognizer)
        }
    }
    
    /**
     Function that is called when the position of the agent has changed. The positionView and the trajectoryView are updated.
     */
    private func updatePosition() {
        guard let position = position else { return }
        
        // Update position
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
    
    /**
     Function that is called when the covariance of the Kalman filter has changed. The covarianceView is updated.
     */
    private func updateCovariance() {
        guard let position = position, let covariance = covariance else { return }
        
        if let covarianceView = covarianceView {
            covarianceView.updateEllipse(withEllipseType: .covariance(covariance), position: position)
        } else {
            covarianceView = EllipseView(ellipseType: .covariance(covariance), position: position)
            mapView.addSubview(covarianceView!)
        }
    }
    
    /**
     Function that is called when the set of particles has changed. All particleViews are updated.
     */
    private func updateParticles() {
        guard let particles = particles else { return }
        
        // Check if the amount of particles has changed. If not, update all views
        if particles.count == particleViews?.count {
            for i in 0..<particles.count {
                particleViews?[i].updatePoint(withPointType: .particle(particles[i]))
            }
        } else {
            // If the number of particles is different from the number of views for them, all views are redrawn
            particleViews?.forEach { $0.removeFromSuperview() }
            particleViews = [PointView]()
            
            for particle in particles {
                let particleView = PointView(pointType: .particle(particle))
                mapView.addSubview(particleView)
                mapView.sendSubview(toBack: particleView)
                particleViews?.append(particleView)
            }
            mapView.sendSubview(toBack: floorplanView)
        }
    }
    
    /**
     Function that is called when the distance measurements for active anchors have changed. The distanceViews are updated.
     */
    private func updateAnchorDistances() {
        guard let anchorDistances = anchorDistances,
            let anchors = anchors?.filter({ $0.isActive }) else { return }
        
        if anchorDistances.count == distanceViews?.count {
            for i in 0..<anchorDistances.count {
                distanceViews?[i].updateEllipse(withEllipseType: .distance(radius: anchorDistances[i]))
            }
        } else {
            distanceViews?.forEach { $0.removeFromSuperview() }
            distanceViews = [EllipseView]()
            
            for i in 0..<anchorDistances.count {
                let distanceView = EllipseView(ellipseType: .distance(radius: anchorDistances[i]), position: anchors[i].position)
                mapView.addSubview(distanceView)
                distanceViews?.append(distanceView)
            }
        }
    }
    
    /**
     Function that is called when the acceleration measurements have changed. The accelerationViews are updated.
     */
    private func updateAcceleration() {
        guard let acceleration = acceleration,
            let position = position else { return }
        
        if accelerationViews != nil {
            accelerationViews?[0].updateVector(withOrigin: position, vector: CGSize(width: acceleration[0], height: 0))
            accelerationViews?[1].updateVector(withOrigin: position, vector: CGSize(width: 0, height: acceleration[1]))
        } else {
            accelerationViews?.forEach { $0.removeFromSuperview() }
            
            // Initialize vectors with unit vectors
            let xVector = VectorView(origin: position, vector: CGSize(width: 1, height: 0))
            let yVector = VectorView(origin: position, vector: CGSize(width: 0, height: 1))
            mapView.addSubview(xVector)
            mapView.addSubview(yVector)
            
            accelerationViews = [xVector, yVector]
        }
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
    
    //MARK: User interaction
    // Functions used for zooming, rotating and panning the mapView
    /**
     Function that is called when a rotating gesture is recognized in the mapView. The view is rotated accordingly.
     */
    func handleRotation(_ recognizer: UIRotationGestureRecognizer) {
        if (recognizer.state == .began) {
            initAngle = angle
        }
        angle = initAngle + recognizer.rotation
        adjustAnchorPointForGestureRecognizer(recognizer)
        updateTransformWithOffset(CGPoint.zero)
    }
    
    /**
     Function that is called when a pinch gesture is recognized in the mapView. The view is zoomed accordingly.
     */
    func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        if recognizer.state == .began {
            initScale = scale
        }
        scale = initScale * recognizer.scale
        adjustAnchorPointForGestureRecognizer(recognizer)
        updateTransformWithOffset(CGPoint.zero)
    }
    
    /**
     Function that is called when a pan gesture is recognized in the mapView. The view is translated accordingly.
     */
    func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: mapView.superview)
        adjustAnchorPointForGestureRecognizer(recognizer)
        updateTransformWithOffset(translation)
    }
    
    // Functions for calibration from view
    /**
     Function that is called when an anchor is dragged by the user. This initiates calibration from view.
     */
    func draggedAnchor(_ sender: UIPanGestureRecognizer) {
        // Move anchor on mapView
        let translation = sender.translation(in: mapView)
        sender.view?.center = CGPoint(x: (sender.view?.center.x)! + translation.x, y: (sender.view?.center.y)! + translation.y)
        sender.setTranslation(CGPoint.zero, in: mapView)
        
        // Show calibration buttons
        calibrationButton.isHidden = false
        cancelCalibrationButton.isHidden = false
    }
    
    /**
     Function that is called when then calibration button is tapped. The new array of anchors and their positions is passed to the delegate.
     */
    func didTapCalibrationButton(_ sender: UIButton) {
        // Determine anchor positions
        guard let anchorViews = anchorViews else { return }
        
        var newAnchors = [Anchor]()
        for anchorView in anchorViews {
            switch anchorView.pointType {
            case .anchor(let anchor):
                let newPosition = CGPoint(x: anchorView.frame.minX + anchorView.pointSize / 2, y: anchorView.frame.midY)
                newAnchors.append(Anchor(id: anchor.id, position: newPosition, isActive: anchor.isActive))
            default:
                break
            }
        }
        
        // Tell the delegate that calibration was initiated
        delegate?.didDoCalibrationFromView(newAnchors: newAnchors)
        
        // Hide calibration buttons
        calibrationButton.isHidden = true
        cancelCalibrationButton.isHidden = true
    }
    
    /**
     Function that is called when the cancel calibration button is tapped. The view is restored to the previous state.
     */
    func didTapCancelCalibrationButton(_ sender: UIButton) {
        // Restore view from stored anchors
        setAnchors()
        
        // Hide calibration buttons
        calibrationButton.isHidden = true
        cancelCalibrationButton.isHidden = true
    }
}

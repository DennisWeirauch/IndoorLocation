//
//  MapViewController.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 29/03/2017.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import Foundation
import MapKit

class MapViewController: UIViewController, UIPopoverPresentationControllerDelegate, IndoorLocationManagerDelegate, SettingsTableViewControllerDelegate {
    
    //MARK: Private variables
//    var mapView: MKMapView!
    var settingsButton: UIButton!
    var startButton: UIButton!
    var indoorMapView: IndoorMapView!
    
//    var positionLabel: UILabel!
    
    /// Store the data about our floorplan here.
//    var floorplan: FloorplanOverlay!
    
//    var coordinateConverter: CoordinateConverter!
    
    //MARK: State machine
    fileprivate enum IndoorLocationState {
        case idle
        case positioning
    }
    
    fileprivate var state = IndoorLocationState.idle {
        didSet {
            switch state {
            case .idle:
                let startButtonImage = UIImage(named: "start.png")
                startButton.setImage(startButtonImage, for: .normal)

            case .positioning:
                let startButtonImage = UIImage(named: "stop.png")
                startButton.setImage(startButtonImage, for: .normal)
            }
        }
    }

    //MARK: ViewController lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()

        state = .idle
        
        IndoorLocationManager.shared.delegate = self
        
//        /*
//         We setup a pair of anchors that will define how the floorplan image
//         maps to geographic co-ordinates.
//         */
//        let mapAnchor1 = GeoAnchor(latitudeLongitudeCoordinate: CLLocationCoordinate2DMake(53.45963, 9.9696), pdfPoint: CGPoint(x: 20, y: 20))
//        
//        let mapAnchor2 = GeoAnchor(latitudeLongitudeCoordinate: CLLocationCoordinate2DMake(53.45959, 9.96975), pdfPoint: CGPoint(x: 570, y: 320))
//        
//        let anchorPair = GeoAnchorPair(fromAnchor: mapAnchor1, toAnchor: mapAnchor2)
//
//        coordinateConverter = CoordinateConverter(anchors: anchorPair)
//
//        let pdfUrl = Bundle.main.url(forResource: "room_10_blueprint", withExtension: "pdf")!
//        
//        floorplan = FloorplanOverlay(floorplanUrl: pdfUrl, withPDFBox: CGPDFBox.trimBox, andCoordinateConverter: coordinateConverter)
//        
//        // Disable tileset.
//        mapView.add(HideBackgroundOverlay.hideBackgroundOverlay(), level: .aboveRoads)
//        
//        setupCamera()
    }

//    //MARK: MKMapViewDelegate
//    // Produce each type of renderer that might exist in our mapView.
//    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
//        
//        if (overlay.isKind(of: FloorplanOverlay.self)) {
//            let renderer: FloorplanOverlayRenderer = FloorplanOverlayRenderer(overlay: overlay as MKOverlay)
//            return renderer
//        }
//        
//        if (overlay.isKind(of: HideBackgroundOverlay.self) == true) {
//            let renderer = MKPolygonRenderer(overlay: overlay as MKOverlay)
//            
//            /*
//             HideBackgroundOverlay covers the entire world, so this means all
//             of MapKit's tiles will be replaced with a solid white background
//             */
//            renderer.fillColor = UIColor.white.withAlphaComponent(1)
//            
//            // No border.
//            renderer.lineWidth = 0.0
//            renderer.strokeColor = UIColor.white.withAlphaComponent(0.0)
//            
//            return renderer
//        }
//        
//        NSException(name:NSExceptionName(rawValue: "InvalidMKOverlay"), reason:"Did you add an overlay but forget to provide a matching renderer here? The class was type \(type(of: overlay))", userInfo:["wasClass": type(of: overlay)]).raise()
//        return MKOverlayRenderer()
//    }
//    
//    // Produce each type of annotation view that might exist in our MapView.
//    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
//        if let customAnnotation = annotation as? CustomAnnotation {
//            let annotationView = MKAnnotationView()
//            
//            var image: UIImage?
//            var resizeRect: CGRect
//            
//            switch customAnnotation.annotationType {
//            case .anchor:
//                image = UIImage(named: "anchor.png")
//                resizeRect = CGRect(x: 0, y: 0, width: 30, height: 30)
//                annotationView.canShowCallout = true
//                annotationView.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
//                annotationView.isDraggable = true
//                
//            case .position:
//                image = UIImage(named: "position.png")
//                resizeRect = CGRect(x: 0, y: 0, width: 30, height: 30)
//                annotationView.canShowCallout = false
//                
//            case .particle:
//                image = UIImage(named: "particle.png")
//                resizeRect = CGRect(x: 0, y: 0, width: 4, height: 4)
//                annotationView.canShowCallout = false
//                
//            default:
//                return nil
//            }
//            
//            UIGraphicsBeginImageContext(resizeRect.size)
//            image?.draw(in: resizeRect)
//            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
//            UIGraphicsEndImageContext()
//            
//            annotationView.image = resizedImage
//            return annotationView
//        }
//        return nil
//    }
//    
//    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
//        let anchorSettingsVC = AnchorSettingsViewController(nibName: "AnchorSettingsViewController", bundle: nil)
//        
//        anchorSettingsVC.name = (view.annotation?.title)!
//        
//        anchorSettingsVC.point = CGPoint(x: (view.annotation?.coordinate.latitude)!, y: (view.annotation?.coordinate.longitude)!)
//
//        anchorSettingsVC.modalPresentationStyle = .popover
//        let frame = self.view.frame
//
//        anchorSettingsVC.preferredContentSize = CGSize(width: frame.width - 20, height: 180)
//        
//        let popoverVC = anchorSettingsVC.popoverPresentationController
//        popoverVC?.permittedArrowDirections = UIPopoverArrowDirection(rawValue: 0)
//        popoverVC?.delegate = self
//        popoverVC?.sourceView = self.view
//        popoverVC?.sourceRect = CGRect(x: frame.width / 2, y: frame.height, width: 1, height: 1)
//        
//        self.present(anchorSettingsVC, animated: true, completion: nil)
//    }
    
    //MARK: UIPopoverPresentationConrollerDelegate
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
    //MARK: IndoorLocationManagerDelegate
    func updateAnnotationsFor(_ annotationType: AnnotationType) {
        return
    }
//    func updateAnnotationsFor(_ annotationType: AnnotationType) {
//        
//        // Create array of annotations to change
//        var annotations = [CustomAnnotation]()
//        
//        for annotation in mapView.annotations {
//            guard let customAnnotation = annotation as? CustomAnnotation else { return }
//            
//            if customAnnotation.annotationType == annotationType {
//                annotations.append(customAnnotation)
//            }
//        }
//        
//        switch annotationType {
//        case .anchor:
//            guard let anchors = IndoorLocationManager.shared.anchors else { return }
//
//            // Remove all previous anchorAnnotations and create new ones
//            mapView.removeAnnotations(annotations)
//            
//            for anchor in anchors {
//                let anchorAnnotation = CustomAnnotation(.anchor)
//                anchorAnnotation.title = String(format:"Anchor %2X", anchor.id)
//                anchorAnnotation.coordinate = coordinateConverter.coordinateFromPDFPoint(anchor.coordinates)
//                mapView.addAnnotation(anchorAnnotation)
//            }
//            
//        case .position:
//            guard let position = IndoorLocationManager.shared.position else { return }
//
//            // Update coordinate or create new annotation if none exists
//            if (!annotations.isEmpty) {
//                annotations[0].coordinate = coordinateConverter.coordinateFromPDFPoint(position)
//            } else {
//                let positionAnnotation = CustomAnnotation(.position)
//                positionAnnotation.coordinate = coordinateConverter.coordinateFromPDFPoint(position)
//                mapView.addAnnotation(positionAnnotation)
//            }
//            
//        case .particle:
//            guard let filter = IndoorLocationManager.shared.filter as? ParticleFilter else { return }
//            
//            // Update coordinates or create new annotations if the number of annotations and particles is different
//            if (filter.particles.count == annotations.count) {
//                DispatchQueue.global().async {
//                    for i in 0..<filter.particles.count {
//                        annotations[i].coordinate = self.coordinateConverter.coordinateFromPDFPoint(CGPoint(x: CGFloat(filter.particles[i].state[0]), y: CGFloat(filter.particles[i].state[1])))
//                    }
//                }
//            } else {
//                mapView.removeAnnotations(annotations)
//                
//                for particle in filter.particles {
//                    let particleAnnotation = CustomAnnotation(.particle)
//                    particleAnnotation.coordinate = coordinateConverter.coordinateFromPDFPoint(CGPoint(x: CGFloat(particle.state[0]), y: CGFloat(particle.state[1])))
//                    mapView.addAnnotation(particleAnnotation)
//                }
//            }
//            
//        default:
//            break
//        }
//    }
    
//    //MARK: FilterSettingsTableViewControllerDelegate
    func toggleFloorplanVisible(_ floorPlanVisible: Bool) {
        return
    }
//    func toggleFloorplanVisible(_ floorPlanVisible: Bool) {
//        if floorPlanVisible {
//            mapView.add(floorplan)
//        } else {
//            mapView.remove(floorplan)
//        }
//    }
    
    //MARK: IBActions
    func onSettingsButtonTapped(_ sender: Any) {
        let settingsVC = SettingsTableViewController()
        
        settingsVC.modalPresentationStyle = .popover
        let frame = self.view.frame
        
        settingsVC.preferredContentSize = CGSize(width: 200, height: frame.height)
        settingsVC.settingsDelegate = self
        
        let popoverVC = settingsVC.popoverPresentationController
        popoverVC?.permittedArrowDirections = UIPopoverArrowDirection(rawValue: 0)
        popoverVC?.delegate = self
        popoverVC?.sourceView = self.view
        popoverVC?
            .sourceRect = CGRect(x: frame.width, y: frame.height / 2, width: 1, height: 1)
        
        self.present(settingsVC, animated: true, completion: nil)
    }
    
    func onStartButtonTapped(_ sender: Any) {
        switch state {
        case .idle:
            state = .positioning
            IndoorLocationManager.shared.beginRanging()
        default:
            state = .idle
            IndoorLocationManager.shared.stopRanging()
        }
    }
    
    //MARK: Private API
    private func setupView() {
        // Set up mapView
//        mapView = MKMapView(frame: view.frame)
//        mapView.showsCompass = false
//        mapView.showsPointsOfInterest = false
//        mapView.showsBuildings = false
//        
//        mapView.delegate = self
//        view.addSubview(mapView)
        
        // Set up indoorMapView
        indoorMapView = IndoorMapView(frame: view.frame)
        view.addSubview(indoorMapView)
        
        // Set up settingsButton
        settingsButton = UIButton(frame: CGRect(x: view.frame.width - 50, y: 30, width: 40, height: 40))
        let settingsButtonImage = UIImage(named: "settings.png")
        settingsButton.setImage(settingsButtonImage, for: .normal)
        settingsButton.addTarget(self, action: #selector(onSettingsButtonTapped(_:)), for: .touchUpInside)
        view.addSubview(settingsButton)
        
        // Set up startButton
        startButton = UIButton(frame: CGRect(x: 10, y: 30, width: 40, height: 40))
        startButton.addTarget(self, action: #selector(onStartButtonTapped(_:)), for: .touchUpInside)
        view.addSubview(startButton)
        
//        positionLabel = UILabel(frame: CGRect(x: 80, y: 40, width: 160, height: 30))
//        LabelHelper.setupLabel(positionLabel, withText: "Position", fontSize: 17, textColor: .black, alignment: .center)
//        view.addSubview(positionLabel)
    }
    
//    private func setupCamera() {
//        
//        let mapViewVisibleMapRectArea: Double = mapView.visibleMapRect.size.area()
//        
//        let maxZoomedOut: MKMapRect = mapView.mapRectThatFits(floorplan.boundingMapRect)
//        let maxZoomedOutArea: Double = maxZoomedOut.size.area()
//        
//        let zoomFactor: Double = sqrt(maxZoomedOutArea / mapViewVisibleMapRectArea)
//        let currentAltitude: CLLocationDistance = mapView.camera.altitude
//        let newAltitude: CLLocationDistance = currentAltitude * zoomFactor
//        
//        let newCamera: MKMapCamera = mapView.camera.copy() as! MKMapCamera
//        
//        newCamera.altitude = newAltitude
//        
//        newCamera.centerCoordinate = floorplan.coordinate
//        
//        newCamera.heading = floorplan.getFloorplanUprightMKMapCameraHeading()
//        
//        mapView.setCamera(newCamera, animated: false)
//    }
}

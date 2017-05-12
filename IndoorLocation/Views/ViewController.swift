//
//  ViewController.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 29/03/2017.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import Foundation
import MapKit

class ViewController: UIViewController, MKMapViewDelegate, UIPopoverPresentationControllerDelegate, FilterSettingViewControllerDelegate {
    
    //MARK: IBOutlets and private variables
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var filterSettingsButton: UIButton!
    @IBOutlet weak var startButton: UIButton!
    
    /// Helper class for managing the scroll & zoom of the MapView camera.
    var visibleMapRegionDelegate: VisibleMapRegionDelegate!
    
    /// Store the data about our floorplan here.
    var floorplan: FloorplanOverlay!
    
    var coordinateConverter: CoordinateConverter!
    
    //MARK: State machine
    fileprivate enum IndoorLocationState {
        case idle
        case ranging
        case positioning
    }
    
    fileprivate var state = IndoorLocationState.idle {
        didSet {
            switch state {
            case .idle:
                let startButtonImage = UIImage(named: "start.png")
                startButton.setImage(startButtonImage, for: .normal)

            case .positioning, .ranging:
                let startButtonImage = UIImage(named: "stop.png")
                startButton.setImage(startButtonImage, for: .normal)
            }
        }
    }

    //MARK: ViewController lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let settingsButtonImage = UIImage(named: "settings.png")
        filterSettingsButton.setImage(settingsButtonImage, for: .normal)

        state = .idle
        
        /*
         We setup a pair of anchors that will define how the floorplan image
         maps to geographic co-ordinates.
         */
        let mapAnchor1 = GeoAnchor(latitudeLongitudeCoordinate: CLLocationCoordinate2DMake(53.45963, 9.9696), pdfPoint: CGPoint(x: 20, y: 20))
        
        let mapAnchor2 = GeoAnchor(latitudeLongitudeCoordinate: CLLocationCoordinate2DMake(53.45959, 9.96975), pdfPoint: CGPoint(x: 570, y: 320))
        
        let anchorPair = GeoAnchorPair(fromAnchor: mapAnchor1, toAnchor: mapAnchor2)

        coordinateConverter = CoordinateConverter(anchors: anchorPair)
        
        // === Initialize our assets
        
        /*
         We have to specify subdirectory here since we copy our folder
         reference during "Copy Bundle Resources" section under target
         settings build phases.
         */
        let pdfUrl = Bundle.main.url(forResource: "room_10_blueprint", withExtension: "pdf")!
        
        floorplan = FloorplanOverlay(floorplanUrl: pdfUrl, withPDFBox: CGPDFBox.trimBox, andCoordinateConverter: coordinateConverter)
        
        visibleMapRegionDelegate = VisibleMapRegionDelegate(floorplanBounds: floorplan.boundingMapRectIncludingRotations,
                                                            boundingPDFBox: floorplan.floorplanPDFBox,
                                                            floorplanCenter: floorplan.coordinate,
                                                            floorplanUprightMKMapCameraHeading: floorplan.getFloorplanUprightMKMapCameraHeading())
        
        // Disable tileset.
        mapView.add(HideBackgroundOverlay.hideBackgroundOverlay(), level: .aboveRoads)
        
        // Draw the floorplan!
        mapView.add(floorplan)
        
        createAnnotations()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //MARK: MKMapViewDelegate
    /**
     Check for when the MKMapView is zoomed or scrolled in case we need to
     bounce back to the floorplan. If, instead, you're using e.g.
     MKUserTrackingModeFollow then you'll want to disable
     snapMapViewToFloorplan since it will conflict with the user-follow
     scroll/zoom.
     */
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        visibleMapRegionDelegate.mapView(mapView, regionDidChangeAnimated:animated)
    }
    
    /// Produce each type of renderer that might exist in our mapView.
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        if (overlay.isKind(of: FloorplanOverlay.self)) {
            let renderer: FloorplanOverlayRenderer = FloorplanOverlayRenderer(overlay: overlay as MKOverlay)
            return renderer
        }
        
        if (overlay.isKind(of: HideBackgroundOverlay.self) == true) {
            let renderer = MKPolygonRenderer(overlay: overlay as MKOverlay)
            
            /*
             HideBackgroundOverlay covers the entire world, so this means all
             of MapKit's tiles will be replaced with a solid white background
             */
            renderer.fillColor = UIColor.white.withAlphaComponent(1)
            
            // No border.
            renderer.lineWidth = 0.0
            renderer.strokeColor = UIColor.white.withAlphaComponent(0.0)
            
            return renderer
        }
        
        NSException(name:NSExceptionName(rawValue: "InvalidMKOverlay"), reason:"Did you add an overlay but forget to provide a matching renderer here? The class was type \(type(of: overlay))", userInfo:["wasClass": type(of: overlay)]).raise()
        return MKOverlayRenderer()
    }
    
    /// Produce each type of annotation view that might exist in our MapView.
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        /*
         For now, all we have are some quick and dirty pins for viewing debug
         annotations. To learn more about showing annotations,
         see "Annotating Maps".
         */
        if let subtitle = annotation.subtitle {
            let annotationView = MKAnnotationView()
            
            var image: UIImage?
            var resizeRect: CGRect
            
            switch subtitle! {
            case "Anchor":
                image = UIImage(named: "anchor.png")
                resizeRect = CGRect(x: 0, y: 0, width: 30, height: 30)
                annotationView.canShowCallout = true
                annotationView.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
                annotationView.isDraggable = true
                
            case "Position":
                image = UIImage(named: "position.png")
                resizeRect = CGRect(x: 0, y: 0, width: 30, height: 30)
                annotationView.canShowCallout = false
                
            case "Particle":
                image = UIImage(named: "particle.png")
                resizeRect = CGRect(x: 0, y: 0, width: 4, height: 4)
                annotationView.canShowCallout = false
                
            default:
                return nil
            }
            
            UIGraphicsBeginImageContext(resizeRect.size)
            image?.draw(in: resizeRect)
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            annotationView.image = resizedImage
            return annotationView
        }
        return nil
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        let popoverVC = AnchorSettingsViewController(nibName: "AnchorSettingsViewController", bundle: nil)
        
        popoverVC.name = (view.annotation?.title)!
        
        popoverVC.point = CGPoint(x: (view.annotation?.coordinate.latitude)!, y: (view.annotation?.coordinate.longitude)!)

        popoverVC.modalPresentationStyle = .popover
        let frame = self.view.frame

        popoverVC.preferredContentSize = CGSize(width: frame.width - 20, height: 180)
        
        popoverVC.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection(rawValue: 0)
        popoverVC.popoverPresentationController?.delegate = self
        popoverVC.popoverPresentationController?.sourceView = self.view
        popoverVC.popoverPresentationController?.sourceRect = CGRect(x: frame.width / 2, y: frame.height, width: 1, height: 1)
        
        self.present(popoverVC, animated: true, completion: nil)
    }
    
    //MARK: UIPopoverPresentationConrollerDelegate
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
    //MARK: FilterSettingsViewControllerDelegate
    func updateAnnotationsForAnchors() {
        var annotations = [MKPointAnnotation]()
        
        if let anchors = IndoorLocationManager.shared.anchors {
            
            for (index, anchor) in anchors.enumerated() {
                let anchorAnnotation = MKPointAnnotation()
                anchorAnnotation.title = "Anchor \(index)"
                anchorAnnotation.subtitle = "Anchor"
                anchorAnnotation.coordinate = coordinateConverter.coordinateFromPDFPoint(anchor)
                annotations.append(anchorAnnotation)
            }
        }
        mapView.addAnnotations(annotations)
        //TODO: Refresh map view
    }
    
    //MARK: IBActions
    @IBAction func onMenuButtonTapped(_ sender: Any) {
        let popoverVC = FilterSettingsViewController(nibName: "FilterSettingsViewController", bundle: nil)
        
        popoverVC.modalPresentationStyle = .popover
        let frame = self.view.frame
        
        popoverVC.preferredContentSize = CGSize(width: 200, height: frame.height)
        
        popoverVC.popoverPresentationController?.permittedArrowDirections = UIPopoverArrowDirection(rawValue: 0)
        popoverVC.popoverPresentationController?.delegate = self
        popoverVC.popoverPresentationController?.sourceView = self.view
        popoverVC.popoverPresentationController?.sourceRect = CGRect(x: frame.width, y: frame.height / 2, width: 1, height: 1)
        
        popoverVC.delegate = self
        
        self.present(popoverVC, animated: true, completion: nil)
    }
    
    @IBAction func onStartButtonTapped(_ sender: Any) {
        switch state {
        case .idle:
            state = .positioning
            IndoorLocationManager.shared.beginPositioning()
        default:
            state = .idle
            IndoorLocationManager.shared.stopPositioning()
        }
    }
    
    //MARK: Private API
    private func createAnnotations() {
        
        var annotations = [MKPointAnnotation]()

        if let position = IndoorLocationManager.shared.position {
            
            let positionAnnotation = MKPointAnnotation()
            positionAnnotation.title = "Position"
            positionAnnotation.subtitle = "Position"
            positionAnnotation.coordinate = coordinateConverter.coordinateFromPDFPoint(position)
            annotations.append(positionAnnotation)
        }
        
        switch IndoorLocationManager.shared.filterSettings.filterType {
            
        case .none, .kalman:
            break
            
        case .particle:
            let filter = IndoorLocationManager.shared.filter as! ParticleFilter
            let particles = filter.particles
            for i in 0..<particles.count {
                let particleAnnotation = MKPointAnnotation()
                particleAnnotation.title = "Particle \(i)"
                particleAnnotation.subtitle = "Particle"
                particleAnnotation.coordinate = coordinateConverter.coordinateFromPDFPoint(CGPoint(x: CGFloat(particles[i].x), y: CGFloat(particles[i].y)))
                annotations.append(particleAnnotation)
            }
        }
        
        mapView.addAnnotations(annotations)
    }
}

//
//  ViewController.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 29/03/2017.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import Foundation
import MapKit
import GameplayKit

class ViewController: UIViewController, MKMapViewDelegate, UIPopoverPresentationControllerDelegate {
    
    
    //MARK: IBOutlets and private variables
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var filterSettingsButton: UIButton!
    
    /// Helper class for managing the scroll & zoom of the MapView camera.
    var visibleMapRegionDelegate: VisibleMapRegionDelegate!
    
    /// Store the data about our floorplan here.
    var floorplan: FloorplanOverlay!
    
    var coordinateConverter: CoordinateConverter!
    
    // Anchors and Tags
    var anchor1: CGPoint!
    var anchor2: CGPoint!
    var anchor3: CGPoint!

    var mean: CGPoint!
    
    let numberParticles = 100
    var particles = [Particle]()

    //MARK: ViewController lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let buttonImage = UIImage(named: "settings.png")
        filterSettingsButton.imageRect(forContentRect: CGRect(x: 0, y: 0, width: 10, height: 10))
        filterSettingsButton.setImage(buttonImage, for: .normal)

        /*
         We setup a pair of anchors that will define how the floorplan image
         maps to geographic co-ordinates.
         */
        let mapAnchor1 = GeoAnchor(latitudeLongitudeCoordinate: CLLocationCoordinate2DMake(53.45963, 9.9696), pdfPoint: CGPoint(x: 20, y: 20))
        
        let mapAnchor2 = GeoAnchor(latitudeLongitudeCoordinate: CLLocationCoordinate2DMake(53.45959, 9.96975), pdfPoint: CGPoint(x: 570, y: 320))
        
        let anchorPair = GeoAnchorPair(fromAnchor: mapAnchor1, toAnchor: mapAnchor2)

        coordinateConverter = CoordinateConverter(anchors: anchorPair)

        anchor1 = CGPoint(x: 290, y: 300)
        anchor2 = CGPoint(x: 550, y: 300)
        anchor3 = CGPoint(x: 550, y: 30)
        
        particles = []
        let randomGenerator = GKGaussianDistribution(randomSource: GKRandomSource(), mean: 0, deviation: 15)
        for _ in 0..<numberParticles {
            // Roll the dice...
            let noisyXCoordinate = 500 + randomGenerator.nextInt()
            let noisyYCoordinate = 80 + randomGenerator.nextInt()
            let particle = Particle(x: Double(noisyXCoordinate), y: Double(noisyYCoordinate), weight: 1.0)
            particles.append(particle)
        }
        
        mean = calculateMeanOfParticles(particles: particles)
        
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
        
        let annotations = createAnnotationsForMapView(mapView!, aboutFloorplan: floorplan)

        // Draw the floorplan!
        mapView.add(floorplan)
        mapView.addAnnotations(annotations)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //MARK: MKMapViewDelegate functions
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
                
            case "Mean":
                image = UIImage(named: "particle_mean.png")
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
    
    //MARK: UIPopoverPresentationConrollerDelegate functions
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
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
        
        self.present(popoverVC, animated: true, completion: nil)
    }
    
    //MARK: Private API
    func createAnnotationsForMapView(_ mapView: MKMapView, aboutFloorplan floorplan: FloorplanOverlay) -> [MKPointAnnotation] {
        // Drop pins at the Anchor's positions.
        let anchor1Annotation = MKPointAnnotation()
        anchor1Annotation.title = "Anchor 1"
        anchor1Annotation.subtitle = "Anchor"
        anchor1Annotation.coordinate = coordinateConverter.coordinateFromPDFPoint(self.anchor1)
        
        let anchor2Annotation = MKPointAnnotation()
        anchor2Annotation.title = "Anchor 2"
        anchor2Annotation.subtitle = "Anchor"
        anchor2Annotation.coordinate = coordinateConverter.coordinateFromPDFPoint(self.anchor2)
        
        let anchor3Annotation = MKPointAnnotation()
        anchor3Annotation.title = "Anchor 3"
        anchor3Annotation.subtitle = "Anchor"
        anchor3Annotation.coordinate = coordinateConverter.coordinateFromPDFPoint(self.anchor3)

        let meanAnnotation = MKPointAnnotation()
        meanAnnotation.title = "Mean"
        meanAnnotation.subtitle = "Mean"
        meanAnnotation.coordinate = coordinateConverter.coordinateFromPDFPoint(self.mean)
        
        var particleAnnotations = [MKPointAnnotation]()
        for i in 0..<numberParticles {
            let particleAnnotation = MKPointAnnotation()
            particleAnnotation.title = "Particle \(i)"
            particleAnnotation.subtitle = "Particle"
            particleAnnotation.coordinate = coordinateConverter.coordinateFromPDFPoint(CGPoint(x: CGFloat(particles[i].x), y: CGFloat(particles[i].y)))
            particleAnnotations.append(particleAnnotation)
        }
        return [anchor1Annotation, anchor2Annotation, anchor3Annotation, meanAnnotation] + particleAnnotations
    }
    
    func calculateMeanOfParticles(particles: [Particle]) -> CGPoint {
        var totalX = 0.0
        var totalY = 0.0
        for i in 0..<particles.count {
            totalX += particles[i].x
            totalY += particles[i].y
        }
        let meanX = totalX / Double(particles.count)
        let meanY = totalY / Double(particles.count)
        return CGPoint(x: meanX, y: meanY)
    }
}

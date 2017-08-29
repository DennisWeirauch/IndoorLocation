//
//  MapViewController.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 29/03/2017.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import Foundation
import MapKit

class MapViewController: UIViewController, UIPopoverPresentationControllerDelegate, IndoorLocationManagerDelegate, SettingsTableViewControllerDelegate, IndoorMapViewDelegate {
    
    //MARK: Private variables
    var settingsButton: UIButton!
    var startButton: UIButton!
    var activityIndicatorView: UIActivityIndicatorView!
    var indoorMapView: IndoorMapView!
    
    //MARK: ViewController lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        
        // Receive updates from IndoorLocationManager
        IndoorLocationManager.shared.delegate = self
    }
    
    //MARK: UIPopoverPresentationConrollerDelegate
    // Necessary for popup style of SettingsTableViewController
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
    //MARK: IndoorLocationManagerDelegate
    /**
     IndoorLocationManagerDelegate function that is called when a new position is available
     - Parameter position: The new position
     */
    func updatePosition(_ position: CGPoint) {
        indoorMapView.position = position
    }
    
    /**
     IndoorLocationManagerDelegate function that is called after new anchors have been calibrated.
     - Parameter anchors: The new anchors
     */
    func setAnchors(_ anchors: [Anchor]) {
        indoorMapView.anchors = anchors
    }
    
    /**
     IndoorLocationManagerDelegate function that is called when the set of active anchors has changed or new measurements are available.
     - Parameter anchors: The set of calibrated anchors
     - Parameter distances: The distance measurements of each anchor
     - Parameter acceleration: The acceleration measurements
     */
    func updateActiveAnchors(_ anchors: [Anchor], distances: [Float], acceleration: [Float]) {
        // Update the set of active anchors in the indoorMapView if necessary
        if (indoorMapView.anchors == nil || (indoorMapView.anchors!.map { $0.isActive } != anchors.map { $0.isActive })) {
            indoorMapView.anchors = anchors
        }
        // Pass new measurements as CGFloat to indoorMapView
        indoorMapView.anchorDistances = distances.map { CGFloat($0) }
        indoorMapView.acceleration = acceleration.map { CGFloat($0) }
    }
    
    /**
     IndoorLocationManagerDelegate function that is called when a new covariance for the Kalman filter is available.
     - Parameter eigenvalue1: The first eigenvalue of the covariance matrix. It defines the width of the displayed ellipse
     - Parameter eigenvalue2: The second eigenvalue of the covariance matrix. It defines the height of the displayed ellipse
     - Parameter angle: The rotation angle of the ellipse
     */
    func updateCovariance(eigenvalue1: Float, eigenvalue2: Float, angle: Float) {
        // Determine the width and height of the ellipse and pass it to the indoorMapView
        let a = CGFloat(2 * sqrt(5.991) * eigenvalue1)
        let b = CGFloat(2 * sqrt(5.991) * eigenvalue2)
        indoorMapView.covariance = (a: a, b: b, angle: CGFloat(angle))
    }
    
    /**
     IndoorLocationManagerDelegate function that is called when a new state for all particles is available.
     - Parameter particles: The set of particles
     */
    func updateParticles(_ particles: [Particle]) {
        indoorMapView.particles = particles
    }
    
    //MARK: SettingsTableViewControllerDelegate
    /**
     SettingsTableViewControllerDelegate function that is called when the settings for displaying the floorplan have changed.
     The `isFloorplanVisible` attribute of indoorMapView is changed accordingly.
     - Parameter isFloorplanVisible: A flag indicating whether the floorplan has to be displayed.
     */
    func toggleFloorplanVisible(_ isFloorplanVisible: Bool) {
        indoorMapView.isFloorplanVisible = isFloorplanVisible
    }
    
    /**
     SettingsTableViewControllerDelegate function that is called when the settings for displaying the measurements have changed.
     The `areMeasurementsVisible` attribute of indoorMapView is changed accordingly.
     - Parameter areMeasurementsVisible: A flag indicating whether the measurements have to be displayed.
     */
    func toggleMeasurementsVisible(_ areMeasurementsVisible: Bool) {
        indoorMapView.areMeasurementsVisible = areMeasurementsVisible
    }
    
    /**
     SettingsTableViewControllerDelegate function that is called when the settings for the filterType have changed.
     The `filterType` attribute of indoorMapView is changed accordingly.
     - Parameter filterType: The selected type of filter
     */
    func changeFilterType(_ filterType: FilterType) {
        indoorMapView.filterType = filterType
    }
    
    //MARK: IndoorMapViewDelegate
    /**
     IndoorMapViewDelegate function that is called when calibration from view is requested by the user.
     - Parameter newAnchors: The new positions of anchors to be calibrated
     */
    func didDoCalibrationFromView(newAnchors: [Anchor]) {        
        // Replace anchors array with newAnchors and perform calibration
        IndoorLocationManager.shared.anchors = newAnchors
        IndoorLocationManager.shared.calibrate() { error in
            if let error = error {
                alertWithTitle("Error", message: error.localizedDescription)
            } else {
                alertWithTitle("Success", message: "Calibration Successful!")
            }
        }
    }
    
    //MARK: Public API
    /**
     Function that is called when the settings button is tapped. It presents the SettingsViewController as popover.
     */
    func onSettingsButtonTapped(_ sender: Any) {
        let settingsVC = SettingsTableViewController()
        
        settingsVC.modalPresentationStyle = .popover
        let frame = self.view.frame
        
        settingsVC.preferredContentSize = CGSize(width: 220, height: frame.height)
        settingsVC.settingsDelegate = self
        
        let popoverVC = settingsVC.popoverPresentationController
        popoverVC?.permittedArrowDirections = UIPopoverArrowDirection(rawValue: 0)
        popoverVC?.delegate = self
        popoverVC?.sourceView = self.view
        popoverVC?.sourceRect = CGRect(x: frame.width, y: frame.height / 2, width: 1, height: 1)
        
        self.present(settingsVC, animated: true, completion: nil)
    }
    
    /**
     Function that is called when the start button is tapped. It begins and stops ranging and changes its image accordingly.
     */
    func onStartButtonTapped(_ sender: Any) {
        // Show activity indicator
        activityIndicatorView.startAnimating()
        view.bringSubview(toFront: activityIndicatorView)
        
        if IndoorLocationManager.shared.isRanging {
            IndoorLocationManager.shared.stopRanging() { error in
                if let error = error {
                    alertWithTitle("Error", message: error.localizedDescription)
                } else {
                    self.startButton.setImage(UIImage(named: "startIcon"), for: .normal)
                }
                self.activityIndicatorView.stopAnimating()
            }
        } else {
            IndoorLocationManager.shared.beginRanging() { error in
                if let error = error {
                    alertWithTitle("Error", message: error.localizedDescription)
                } else {
                    self.startButton.setImage(UIImage(named: "stopIcon"), for: .normal)
                }
                self.activityIndicatorView.stopAnimating()
            }
        }
    }
    
    //MARK: Private API
    /**
     Function to set up the view. The indoorMapView, settingsButton, startButton and its activityIndicatorView are initialized.
     */
    private func setupView() {
        // Set up indoorMapView
        indoorMapView = IndoorMapView(frame: view.frame)
        indoorMapView.delegate = self
        view.addSubview(indoorMapView)
        
        // Set up settingsButton
        settingsButton = UIButton(frame: CGRect(x: view.frame.width - 50, y: 30, width: 40, height: 40))
        settingsButton.setImage(UIImage(named: "settingsIcon"), for: .normal)
        settingsButton.addTarget(self, action: #selector(onSettingsButtonTapped(_:)), for: .touchUpInside)
        view.addSubview(settingsButton)
        
        // Set up startButton
        startButton = UIButton(frame: CGRect(x: 10, y: 30, width: 40, height: 40))
        startButton.setImage(UIImage(named: "startIcon"), for: .normal)
        startButton.addTarget(self, action: #selector(onStartButtonTapped(_:)), for: .touchUpInside)
        view.addSubview(startButton)
        
        // Set up activityIndicatorView
        activityIndicatorView = UIActivityIndicatorView(frame: startButton.frame)
        activityIndicatorView.hidesWhenStopped = true
        activityIndicatorView.color = .black
        view.addSubview(activityIndicatorView)
    }
}

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
    var settingsButton: UIButton!
    var startButton: UIButton!
    var activityIndicatorView: UIActivityIndicatorView!
    var indoorMapView: IndoorMapView!
    
    //MARK: ViewController lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
        
        IndoorLocationManager.shared.delegate = self
    }
    
    //MARK: UIPopoverPresentationConrollerDelegate
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.none
    }
    
    //MARK: IndoorLocationManagerDelegate
    func updatePosition(_ position: CGPoint) {
        indoorMapView.position = position
    }
    
    func updateAnchors(_ anchors: [Anchor]) {
        indoorMapView.anchors = anchors
    }
    
    func updateCovariance(covX: Float, covY: Float) {
        indoorMapView.covariance = (x: covX, y: covY)
    }
    
    func updateParticles(_ particles: [Particle]) {
        indoorMapView.particles = particles
    }
    
    func showAlertWithTitle(_ title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alert.addAction(action)
        
        if let presentedViewController = presentedViewController {
            presentedViewController.present(alert, animated: true)
        } else {
            self.present(alert, animated: true)
        }
    }
    
    //MARK: SettingsTableViewControllerDelegate
    func toggleFloorplanVisible(_ isFloorPlanVisible: Bool) {
        indoorMapView.isFloorPlanVisible = isFloorPlanVisible
    }
    
    func changeFilterType(_ filterType: FilterType) {
        indoorMapView.filterType = filterType
    }
    
    //MARK: Public API
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
        popoverVC?.sourceRect = CGRect(x: frame.width, y: frame.height / 2, width: 1, height: 1)
        
        self.present(settingsVC, animated: true, completion: nil)
    }
    
    func onStartButtonTapped(_ sender: Any) {
        activityIndicatorView.startAnimating()
        view.bringSubview(toFront: activityIndicatorView)

        if IndoorLocationManager.shared.isRanging {
            IndoorLocationManager.shared.stopRanging() {
                self.startButton.setImage(UIImage(named: "start.png"), for: .normal)
                self.activityIndicatorView.stopAnimating()
            }
        } else {
            IndoorLocationManager.shared.beginRanging() {
                self.startButton.setImage(UIImage(named: "stop.png"), for: .normal)
                self.activityIndicatorView.stopAnimating()
            }
        }
    }
    
    //MARK: Private API
    private func setupView() {
        // Set up indoorMapView
        indoorMapView = IndoorMapView(frame: view.frame)
        view.addSubview(indoorMapView)
        
        // Set up settingsButton
        settingsButton = UIButton(frame: CGRect(x: view.frame.width - 50, y: 30, width: 40, height: 40))
        settingsButton.setImage(UIImage(named: "settings.png"), for: .normal)
        settingsButton.addTarget(self, action: #selector(onSettingsButtonTapped(_:)), for: .touchUpInside)
        view.addSubview(settingsButton)
        
        // Set up startButton
        startButton = UIButton(frame: CGRect(x: 10, y: 30, width: 40, height: 40))
        startButton.setImage(UIImage(named: "start.png"), for: .normal)
        startButton.addTarget(self, action: #selector(onStartButtonTapped(_:)), for: .touchUpInside)
        view.addSubview(startButton)
        
        // Set up activityIndicatorView
        activityIndicatorView = UIActivityIndicatorView(frame: startButton.frame)
        activityIndicatorView.hidesWhenStopped = true
        activityIndicatorView.color = .black
        view.addSubview(activityIndicatorView)
    }
}

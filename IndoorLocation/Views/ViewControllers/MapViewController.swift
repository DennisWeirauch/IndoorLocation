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
    var indoorMapView: IndoorMapView!
    
    private var isRunning = false {
        didSet {
            if isRunning {
                startButton.setImage(UIImage(named: "stop.png"), for: .normal)
            } else {
                startButton.setImage(UIImage(named: "start.png"), for: .normal)
            }
        }
    }

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
    
    func updateCovariance(covX: Double, covY: Double) {
        indoorMapView.covariance = (x: covX, y: covY)
    }
    
    func updateParticles(_ particles: [Particle]) {
        indoorMapView.particles = particles
    }
    
    //MARK: FilterSettingsTableViewControllerDelegate
    func toggleFloorplanVisible(_ floorPlanVisible: Bool) {
        //TODO: Implement this
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
        if isRunning {
            IndoorLocationManager.shared.stopRanging()
        } else {
            IndoorLocationManager.shared.beginRanging()
        }
        isRunning = !isRunning
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
    }
}

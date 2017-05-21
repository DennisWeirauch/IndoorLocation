//
//  FilterSettingsViewController.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 07/04/2017.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

protocol FilterSettingsViewControllerDelegate {
    func toggleFloorplanVisible(_ floorPlanVisible: Bool)
}

class FilterSettingsViewController: UIViewController {

    //MARK: IBOutlets and private variables
    @IBOutlet weak var accelerationUncertaintyLabel: UILabel!
    @IBOutlet weak var accelerationUncertaintySlider: UISlider!
    
    @IBOutlet weak var distanceUncertaintyLabel: UILabel!
    @IBOutlet weak var distanceUncertaintySlider: UISlider!
    
    @IBOutlet weak var positioningModeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var calibrationModeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var dataSinkSegmentedControl: UISegmentedControl!
    @IBOutlet weak var filterTypeSegmentedControl: UISegmentedControl!
        
    let filterSettings = IndoorLocationManager.shared.filterSettings
    var delegate: FilterSettingsViewControllerDelegate?
    
    //MARK: ViewController lifecyle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up UISliders
        let accelerationUncertainty = filterSettings.accelerationUncertainty
            accelerationUncertaintyLabel.text = "Acc. Uncertainty: \(Int(accelerationUncertainty))"
            accelerationUncertaintySlider.value = Float(accelerationUncertainty)
        
        let distanceUncertainty = filterSettings.distanceUncertainty
            distanceUncertaintyLabel.text = "Dist. Uncertainty: \(Int(distanceUncertainty))"
            distanceUncertaintySlider.value = Float(distanceUncertainty)
        
        // Set up UISegmentedControls
        positioningModeSegmentedControl.selectedSegmentIndex = filterSettings.positioningModeIsRelative ? 0 : 1
        
        calibrationModeSegmentedControl.selectedSegmentIndex = filterSettings.calibrationModeIsAutomatic ? 0 : 1
        
        dataSinkSegmentedControl.selectedSegmentIndex = filterSettings.dataSinkIsLocal ? 0 : 1
        
        switch filterSettings.filterType {
        case .none:
            filterTypeSegmentedControl.selectedSegmentIndex = 0
        case .kalman:
            filterTypeSegmentedControl.selectedSegmentIndex = 1
        case .particle:
            filterTypeSegmentedControl.selectedSegmentIndex = 2
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // Initialize Filter
        switch filterSettings.filterType {
        case .none:
            IndoorLocationManager.shared.filter = BayesianFilter()
        case .kalman:
            IndoorLocationManager.shared.filter = KalmanFilter(updateTime: 0.5)
        case .particle:
            IndoorLocationManager.shared.filter = ParticleFilter()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: IBActions
    @IBAction func onSliderValueChanged(_ sender: UISlider) {
        switch sender.tag {
        case 1:
            filterSettings.accelerationUncertainty = Double(accelerationUncertaintySlider.value)
            accelerationUncertaintyLabel.text = "Acc. Uncertainty: \(Int(filterSettings.accelerationUncertainty))"
        
        case 2:
            filterSettings.distanceUncertainty = Double(distanceUncertaintySlider.value)
            distanceUncertaintyLabel.text = "Dist. Uncertainty: \(Int(filterSettings.distanceUncertainty))"
            
        default:
            break
        }
    }
    
    @IBAction func onSegmentedControlValueChanged(_ sender: UISegmentedControl) {
        switch sender.tag {
        case 1:
            filterSettings.positioningModeIsRelative = sender.selectedSegmentIndex == 0
            delegate?.toggleFloorplanVisible(!filterSettings.positioningModeIsRelative)
        case 2:
            filterSettings.calibrationModeIsAutomatic = sender.selectedSegmentIndex == 0
        case 3:
            filterSettings.dataSinkIsLocal = sender.selectedSegmentIndex == 0
        case 4:
            switch sender.selectedSegmentIndex {
            case 0:
                filterSettings.filterType = .none
            case 1:
                filterSettings.filterType = .kalman
            case 2:
                filterSettings.filterType = .particle
            default:
                break
            }
        default:
            break
        }
    }
    
    @IBAction func onButtonTapped(_ sender: Any) {
        IndoorLocationManager.shared.calibrate()
    }
}

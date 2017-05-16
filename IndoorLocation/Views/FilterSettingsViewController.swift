//
//  FilterSettingsViewController.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 07/04/2017.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

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
    
    //MARK: ViewController lifecyle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let accelerationUncertainty = filterSettings.accelerationUncertainty {
            accelerationUncertaintyLabel.text = "Acceleration Uncertainty: \(accelerationUncertainty)"
            accelerationUncertaintySlider.value = Float(accelerationUncertainty)
        }
        
        if let distanceUncertainty = filterSettings.distanceUncertainty {
            distanceUncertaintyLabel.text = "Distance Uncertainty: \(distanceUncertainty)"
            distanceUncertaintySlider.value = Float(distanceUncertainty)
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
            accelerationUncertaintyLabel.text = "Acceleration Uncertainty: \(filterSettings.accelerationUncertainty!)"
        
        case 2:
            filterSettings.distanceUncertainty = Double(distanceUncertaintySlider.value)
            distanceUncertaintyLabel.text = "Distance Uncertainty: \(filterSettings.distanceUncertainty!)"
            
        default:
            break
        }
    }
    
    @IBAction func onSegmentedControlValueChanged(_ sender: UISegmentedControl) {
        switch sender.tag {
        case 1:
            filterSettings.positioningModeIsRelative = sender.selectedSegmentIndex == 0
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

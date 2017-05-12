//
//  FilterSettingsViewController.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 07/04/2017.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

protocol FilterSettingViewControllerDelegate {
    func updateAnnotationsForAnchors()
}

class FilterSettingsViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    //MARK: IBOutlets and private variables
    @IBOutlet weak var accelerationUncertaintyLabel: UILabel!
    @IBOutlet weak var accelerationUncertaintySlider: UISlider!
    
    @IBOutlet weak var distanceUncertaintyLabel: UILabel!
    @IBOutlet weak var distanceUncertaintySlider: UISlider!
    
    @IBOutlet weak var positioningModeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var calibrationModeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var dataSinkSegmentedControl: UISegmentedControl!
    @IBOutlet weak var filterTypeSegmentedControl: UISegmentedControl!
    
    @IBOutlet weak var devicePickerView: UIPickerView!
    
    var delegate: FilterSettingViewControllerDelegate?

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
        // Set up Picker View
        devicePickerView.dataSource = self
        devicePickerView.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: UIPickerViewDataSource
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return NetworkManager.shared.services.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return NetworkManager.shared.services[row].name
    }
    
    //MARK: UIPickerViewDelegate
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let service = NetworkManager.shared.services[row]
        NetworkManager.shared.selectedService = service
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
        IndoorLocationManager.shared.calibrate {
            print("Successfully calibrated!")
            self.delegate?.updateAnnotationsForAnchors()
        }
    }
}

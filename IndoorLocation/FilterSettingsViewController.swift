//
//  FilterSettingsViewController.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 07/04/2017.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

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
    
    @IBOutlet weak var startButton: UIButton!
    
    let settings = Settings.sharedInstance
    
    //MARK: ViewController lifecyle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        accelerationUncertaintyLabel.text = "Acceleration Uncertainty: \(settings.accelerationUncertainty)"
        accelerationUncertaintySlider.value = Float(settings.accelerationUncertainty)
        
        distanceUncertaintyLabel.text = "Distance Uncertainty: \(settings.distanceUncertainty)"
        distanceUncertaintySlider.value = Float(settings.distanceUncertainty)
        
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
        return NetworkManager.sharedInstance.services.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return NetworkManager.sharedInstance.services[row].name
    }
    
    //MARK: UIPickerViewDelegate
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let service = NetworkManager.sharedInstance.services[row]
        NetworkManager.sharedInstance.selectedService = service
    }
    
    //MARK: IBActions
    @IBAction func onSliderValueChanged(_ sender: UISlider) {
        switch sender.tag {
        case 1:
            settings.accelerationUncertainty = Int(accelerationUncertaintySlider.value)
            accelerationUncertaintyLabel.text = "Acceleration Uncertainty: \(settings.accelerationUncertainty)"
        
        case 2:
            settings.distanceUncertainty = Int(distanceUncertaintySlider.value)
            distanceUncertaintyLabel.text = "Distance Uncertainty: \(settings.distanceUncertainty)"
            
        default:
            break
        }
    }
    
    @IBAction func onSegmentedControlValueChanged(_ sender: UISegmentedControl) {
        switch sender.tag {
        case 1:
            settings.positioningModeIsRelative = sender.selectedSegmentIndex == 0
        case 2:
            settings.calibrationModeIsAutomatic = sender.selectedSegmentIndex == 0
        case 3:
            settings.dataSinkIsLocal = sender.selectedSegmentIndex == 0
        case 4:
            switch sender.selectedSegmentIndex {
            case 0:
                settings.filterType = .none
            case 1:
                settings.filterType = .kalman
            case 2:
                settings.filterType = .particle
            default:
                break
            }
        default:
            break
        }
    }
    
    @IBAction func onStartButtonTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: {
            //Begin tracking
        })
    }
}

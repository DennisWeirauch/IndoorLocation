////
////  FilterSettingsViewController.swift
////  IndoorLocation
////
////  Created by Dennis Hirschgänger on 07/04/2017.
////  Copyright © 2017 Hirschgaenger. All rights reserved.
////
//
//import UIKit
//
//protocol SettingsViewControllerDelegate {
//    func toggleFloorplanVisible(_ floorPlanVisible: Bool)
//}
//
//class SettingsViewController: UIViewController, UITextFieldDelegate {
//
//    //MARK: IBOutlets and private variables
//    @IBOutlet weak var positioningModeSegmentedControl: UISegmentedControl!
//    @IBOutlet weak var calibrationModeSegmentedControl: UISegmentedControl!
//    @IBOutlet weak var dataSinkSegmentedControl: UISegmentedControl!
//    @IBOutlet weak var filterTypeSegmentedControl: UISegmentedControl!
//    
//    @IBOutlet weak var contentView: UIView!
//    @IBOutlet weak var filterSettingsView: UIView!
//    @IBOutlet weak var calibrationView: UIView!
//    
//    let filterSettings = IndoorLocationManager.shared.filterSettings
//    var delegate: SettingsViewControllerDelegate?
//    
//    var filterSettingsLabels = [String : UILabel]()
//    
//    //MARK: ViewController lifecyle
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        
//        // Set up UISegmentedControls
//        positioningModeSegmentedControl.selectedSegmentIndex = filterSettings.positioningModeIsRelative ? 0 : 1
//        
//        if filterSettings.calibrationModeIsAutomatic {
//            calibrationModeSegmentedControl.selectedSegmentIndex = 0
//        } else {
//            calibrationModeSegmentedControl.selectedSegmentIndex = 1
//        }
//        showCalibrationView()
//        
//        dataSinkSegmentedControl.selectedSegmentIndex = filterSettings.dataSinkIsLocal ? 0 : 1
//        
//        switch filterSettings.filterType {
//        case .none:
//            filterTypeSegmentedControl.selectedSegmentIndex = 0
//        case .kalman:
//            filterTypeSegmentedControl.selectedSegmentIndex = 1
//            showFilterSettingsViewForType(.kalman)
//        case .particle:
//            filterTypeSegmentedControl.selectedSegmentIndex = 2
//        }
//        showFilterSettingsViewForType(filterSettings.filterType)
//        
//        // Tap gesture recognizer for dismissing keyboard when touching outside of UITextFields
//        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
//        tapGestureRecognizer.cancelsTouchesInView = false
//        self.view.addGestureRecognizer(tapGestureRecognizer)
//        
//        resizeViews()
//    }
//    
//    override func viewWillDisappear(_ animated: Bool) {
//        // Initialize Filter
//        switch filterSettings.filterType {
//        case .none:
//            IndoorLocationManager.shared.filter = BayesianFilter()
//        case .kalman:
//            IndoorLocationManager.shared.filter = KalmanFilter()
//        case .particle:
//            IndoorLocationManager.shared.filter = ParticleFilter()
//        }
//    }
//    
//    //MARK: IBActions
//    @IBAction func onSliderValueChanged(_ sender: UISlider) {
//        switch sender.tag {
//        case 1:
//            filterSettings.accelerationUncertainty = Int(sender.value)
//            if let label = filterSettingsLabels["acc"] {
//                label.text = "Acc. uncertainty: \(filterSettings.accelerationUncertainty)"
//            }
//        case 2:
//            filterSettings.distanceUncertainty = Int(sender.value)
//            if let label = filterSettingsLabels["dist"] {
//                label.text = "Dist. uncertainty: \(filterSettings.distanceUncertainty)"
//            }
//        case 3:
//            filterSettings.processingUncertainty = Int(sender.value)
//            if let label = filterSettingsLabels["proc"] {
//                label.text = "Proc. uncertainty: \(filterSettings.processingUncertainty)"
//            }
//        case 4:
//            filterSettings.numberOfParticles = Int(sender.value)
//            if let label = filterSettingsLabels["part"] {
//                label.text = "Particles: \(filterSettings.numberOfParticles)"
//            }
//        default:
//            break
//        }
//    }
//    
//    @IBAction func onSegmentedControlValueChanged(_ sender: UISegmentedControl) {
//        switch sender.tag {
//        case 1:
//            filterSettings.positioningModeIsRelative = sender.selectedSegmentIndex == 0
//            delegate?.toggleFloorplanVisible(!filterSettings.positioningModeIsRelative)
//        case 2:
//            filterSettings.calibrationModeIsAutomatic = sender.selectedSegmentIndex == 0
//            showCalibrationView()
//        case 3:
//            filterSettings.dataSinkIsLocal = sender.selectedSegmentIndex == 0
//        case 4:
//            switch sender.selectedSegmentIndex {
//            case 0:
//                filterSettings.filterType = .none
//            case 1:
//                filterSettings.filterType = .kalman
//            case 2:
//                filterSettings.filterType = .particle
//            default:
//                break
//            }
//            showFilterSettingsViewForType(filterSettings.filterType)
//        default:
//            break
//        }
//    }
//    
//    @IBAction func onButtonTapped(_ sender: UIButton) {
//        if sender.tag == 1 {
//            IndoorLocationManager.shared.calibrate()
//        } else {
//            // Added anchor manually
//        }
//    }
//    
//    @IBAction func dismissKeyboard() {
//        self.view.endEditing(true)
//    }
//    
//    //MARK: Private API
//    private func resizeViews() {
//        
//        // Update height constraint of calibrationView
//        if let calibrationViewHeightConstraint = calibrationView.constraints.first {
//            let newSize = calibrationView.sizeThatFits()
//            calibrationViewHeightConstraint.constant = newSize.height
//            calibrationView.frame.size = newSize
//        }
//        
//        // Update height constraint of filterSettingsView
//        if let filterSettingsViewHeightConstraint = filterSettingsView.constraints.first {
//            let newSize = filterSettingsView.sizeThatFits()
//            filterSettingsViewHeightConstraint.constant = newSize.height
//            filterSettingsView.frame.size = newSize
//        }
//        
//        // Update height constraint of contentView. As this view contains many constraints
//        // the right constraint has to be found first.
//        for constraint in contentView.constraints {
//            if constraint.firstItem as! NSObject == contentView && constraint.firstAttribute == .height {
//                let newSize = contentView.sizeThatFits()
//                constraint.constant = newSize.height
//                calibrationView.frame.size = newSize
//                break
//            }
//        }
//    }
//    
//    private func showFilterSettingsViewForType(_ filterType: FilterType) {
//        for subview in filterSettingsView.subviews {
//            subview.removeFromSuperview()
//        }
//        filterSettingsLabels.removeAll()
//        
//        let uiElementWidth = filterSettingsView.frame.width - 40
//        
//        switch filterType {
//        case .none:
//            break
//            
//        case .kalman:
//            // Add 3 Labels and Sliders for acceleration uncertainty, position uncertainty and processing uncertainty
//            let sigAccLabel = UILabel(frame: CGRect(x: 20, y: 4, width: uiElementWidth, height: 16))
//            LabelHelper.setupLabel(sigAccLabel, withText: "Acc. uncertainty: \(filterSettings.accelerationUncertainty)")
//            filterSettingsView.addSubview(sigAccLabel)
//            filterSettingsLabels["acc"] = sigAccLabel
//            
//            let sigAccSlider = UISlider(frame: CGRect(x: 20, y: 24, width: uiElementWidth, height: 20))
//            SliderHelper.setupSlider(sigAccSlider, minValue: 0, maxValue: 100, defaultValue: Float(filterSettings.accelerationUncertainty), tag: 1)
//            sigAccSlider.addTarget(self, action: #selector(onSliderValueChanged(_:)), for: .valueChanged)
//            filterSettingsView.addSubview(sigAccSlider)
//            
//            let sigDistLabel = UILabel(frame: CGRect(x: 20, y: 56, width: uiElementWidth, height: 16))
//            LabelHelper.setupLabel(sigDistLabel, withText: "Dist. uncertainty: \(filterSettings.distanceUncertainty)")
//            filterSettingsView.addSubview(sigDistLabel)
//            filterSettingsLabels["dist"] = sigDistLabel
//            
//            let sigDistSlider = UISlider(frame: CGRect(x: 20, y: 76, width: uiElementWidth, height: 20))
//            SliderHelper.setupSlider(sigDistSlider, minValue: 0, maxValue: 100, defaultValue: Float(filterSettings.distanceUncertainty), tag: 2)
//            sigDistSlider.addTarget(self, action: #selector(onSliderValueChanged(_:)), for: .valueChanged)
//            filterSettingsView.addSubview(sigDistSlider)
//            
//            let sigProcLabel = UILabel(frame: CGRect(x: 20, y: 108, width: uiElementWidth, height: 16))
//            LabelHelper.setupLabel(sigProcLabel, withText: "Proc. uncertainty: \(filterSettings.processingUncertainty)")
//            filterSettingsView.addSubview(sigProcLabel)
//            filterSettingsLabels["proc"] = sigProcLabel
//            
//            let sigProcSlider = UISlider(frame: CGRect(x: 20, y: 128, width: uiElementWidth, height: 20))
//            SliderHelper.setupSlider(sigProcSlider, minValue: 0, maxValue: 100, defaultValue: Float(filterSettings.processingUncertainty), tag: 3)
//            sigProcSlider.addTarget(self, action: #selector(onSliderValueChanged(_:)), for: .valueChanged)
//            filterSettingsView.addSubview(sigProcSlider)
//            
//        case .particle:
//            // Add 1 Label and Slider for number of particles
//            let numParticlesLabel = UILabel(frame: CGRect(x: 20, y: 4, width: uiElementWidth, height: 16))
//            LabelHelper.setupLabel(numParticlesLabel, withText: "Particles: \(filterSettings.numberOfParticles)")
//            filterSettingsView.addSubview(numParticlesLabel)
//            filterSettingsLabels["part"] = numParticlesLabel
//            
//            let numParticlesSlider = UISlider(frame: CGRect(x: 20, y: 24, width: uiElementWidth, height: 20))
//            SliderHelper.setupSlider(numParticlesSlider, minValue: 0, maxValue: 1000, defaultValue: Float(filterSettings.numberOfParticles), tag: 4)
//            numParticlesSlider.addTarget(self, action: #selector(onSliderValueChanged(_:)), for: .valueChanged)
//            filterSettingsView.addSubview(numParticlesSlider)
//        }
//        resizeViews()
//    }
//    
//    private func showCalibrationView() {
//        for subview in calibrationView.subviews {
//            subview.removeFromSuperview()
//        }
//        
//        if (!filterSettings.calibrationModeIsAutomatic) {
//            
//            if let anchors = IndoorLocationManager.shared.anchors,
//                let anchorIDs = IndoorLocationManager.shared.anchorIDs {
//                for i in 0..<anchors.count {
//                    let idTextfield = UITextField(frame: CGRect(x: 20, y: 30 * i, width: 42, height: 30))
//                    TextFieldHelper.setupTextField(idTextfield, text: String(describing: anchorIDs[i]), tag: 3 * i + 1, delegate: self)
//                    calibrationView.addSubview(idTextfield)
//                    
//                    let xTextField = UITextField(frame: CGRect(x: 66, y: 30 * i, width: 42, height: 30))
//                    TextFieldHelper.setupTextField(xTextField, text: String(describing: anchors[i].x), keyboardType: .numberPad, tag: 3 * i + 2, delegate: self)
//                    calibrationView.addSubview(xTextField)
//                    
//                    let yTextField = UITextField(frame: CGRect(x: 112, y: 30 * i, width: 42, height: 30))
//                    TextFieldHelper.setupTextField(yTextField, text: String(describing: anchors[i].y), keyboardType: .numberPad, tag: 3 * i + 3, delegate: self)
//                    calibrationView.addSubview(yTextField)
//                    
//                    let addButton = UIButton(type: .contactAdd)
//                    addButton.frame = CGRect(x: 158, y: 30 * i + 4, width: 22, height: 22)
//                    addButton.tag = 3 * i + 2
//                    addButton.addTarget(self, action: #selector(onButtonTapped(_:)), for: .touchUpInside)
//                    calibrationView.addSubview(addButton)
//                }
//            } else {
//                let idTextfield = UITextField(frame: CGRect(x: 20, y: 0, width: 42, height: 30))
//                TextFieldHelper.setupTextField(idTextfield, placeholder: "ID: ", tag: 1, delegate: self)
//                calibrationView.addSubview(idTextfield)
//                
//                let xTextField = UITextField(frame: CGRect(x: 66, y: 0, width: 42, height: 30))
//                TextFieldHelper.setupTextField(xTextField, placeholder: "x: ", keyboardType: .numberPad, tag: 2, delegate: self)
//                calibrationView.addSubview(xTextField)
//                
//                let yTextField = UITextField(frame: CGRect(x: 112, y: 0, width: 42, height: 30))
//                TextFieldHelper.setupTextField(yTextField, placeholder: "y: ", keyboardType: .numberPad, tag: 3, delegate: self)
//                calibrationView.addSubview(yTextField)
//                
//                let addButton = UIButton(type: .contactAdd)
//                addButton.frame = CGRect(x: 158, y: 4, width: 22, height: 22)
//                addButton.tag = 2
//                addButton.addTarget(self, action: #selector(onButtonTapped(_:)), for: .touchUpInside)
//                calibrationView.addSubview(addButton)
//            }
//        }
//        resizeViews()
//    }
//}

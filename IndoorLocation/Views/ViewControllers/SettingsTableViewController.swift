//
//  SettingsTableViewController.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 29.05.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

protocol SettingsTableViewControllerDelegate {
    func toggleFloorplanVisible(_ isFloorplanVisible: Bool)
    func toggleMeasurementsVisible(_ areMeasurementsVisible: Bool)
    func changeFilterType(_ filterType: FilterType)
}

/**
 ViewController for the settings of the application
 */
class SettingsTableViewController: UITableViewController, AnchorTableViewCellDelegate, ButtonTableViewCellDelegate, SegmentedControlTableViewCellDelegate, SliderTableViewCellDelegate, SwitchTableViewCellDelegate {
    
    enum SettingsTableViewSection: Int {
        case view = 0
        case calibration
        case filter
    }
    
    enum SliderType: Int {
        case processUncertainty = 0
        case distanceUncertainty
        case numberOfParticles
        case N_thr
    }
    
    enum SwitchType: Int {
        case isFloorplanVisible = 0
        case areMeasurementsVisible
    }
    
    enum SegmentedControlType: Int {
        case filterType = 0
        case particleFilterType
    }
    
    let tableViewSections = [SettingsTableViewSection.view.rawValue,
                             SettingsTableViewSection.calibration.rawValue,
                             SettingsTableViewSection.filter.rawValue]
    
    let filterSettings = IndoorLocationManager.shared.filterSettings
    var settingsDelegate: SettingsTableViewControllerDelegate?
    
    var calibrationPending = false
    var calibratedAnchors = IndoorLocationManager.shared.anchors
    
    var filterInitializationPending = false
    
    //MARK: ViewController lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up tableView        
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 50))
        let titleLabel = UILabel(frame: CGRect(x: 20, y: 12.5, width: headerView.frame.width - 20, height: 25))
        titleLabel.text = "Settings"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        headerView.addSubview(titleLabel)
        tableView.tableHeaderView = headerView

        tableView.bounces = false
        tableView.showsVerticalScrollIndicator = false
        
        tableView.register(AnchorTableViewCell.self, forCellReuseIdentifier: String(describing: AnchorTableViewCell.self))
        tableView.register(ButtonTableViewCell.self, forCellReuseIdentifier: String(describing: ButtonTableViewCell.self))
        tableView.register(SegmentedControlTableViewCell.self, forCellReuseIdentifier: String(describing: SegmentedControlTableViewCell.self))
        tableView.register(SliderTableViewCell.self, forCellReuseIdentifier: String(describing: SliderTableViewCell.self))
        tableView.register(SwitchTableViewCell.self, forCellReuseIdentifier: String(describing: SwitchTableViewCell.self))
        
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        
        // Tap gesture recognizer for dismissing keyboard when touching outside of UITextFields
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGestureRecognizer.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tapGestureRecognizer)
        
        calibrationPending = false
        filterInitializationPending = false
    }
    
    override func viewWillLayoutSubviews() {
        // Set up close button
        let closeButton = UIButton(frame: CGRect(x: view.frame.width - 35, y: 15, width: 20, height: 20))
        closeButton.setImage(UIImage(named: "closeIcon"), for: .normal)
        closeButton.addTarget(self, action: #selector(didTapCloseButton(_:)), for: .touchUpInside)
        view.addSubview(closeButton)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        // Initialize filter if necessary
        if filterInitializationPending {
            switch filterSettings.filterType {
            case .none:
                IndoorLocationManager.shared.filter = BayesianFilter()
            case .kalman:
                guard let anchors = IndoorLocationManager.shared.anchors,
                    let initialDistances = IndoorLocationManager.shared.initialDistances else { return }
                if let filter = KalmanFilter(anchors: anchors.filter({ $0.isActive }), distances: initialDistances) {
                    IndoorLocationManager.shared.filter = filter
                } else {
                    alertWithTitle("Error", message: "Could not initialize Kalman filter! Make sure at least 3 anchors are within range.")
                }
            case .particle:
                guard let anchors = IndoorLocationManager.shared.anchors,
                    let initialDistances = IndoorLocationManager.shared.initialDistances else { return }
                if let filter = ParticleFilter(anchors: anchors.filter({ $0.isActive }), distances: initialDistances) {
                    IndoorLocationManager.shared.filter = filter
                } else {
                    alertWithTitle("Error", message: "Could not initialize Particle filter! Make sure at least one anchor is within range.")
                }
            }
        }
        
        // Inform the user that calibration settings have changed while calibration has not been executed. The user has the options to calibrate or to discard changes.
        if calibrationPending {
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                IndoorLocationManager.shared.anchors = self.calibratedAnchors
            }
            
            let calibrateAction = UIAlertAction(title: "Calibrate", style: .default) { _ in
                IndoorLocationManager.shared.calibrate() { error in
                    if let error = error {
                        alertWithTitle("Error", message: error.localizedDescription)
                    } else {
                        alertWithTitle("Success", message: "Calibration was successful!")
                    }
                }
            }

            alertWithTitle("Attention", message: "Changes in calibration have not been applied. Do you want to execute calibration to apply changes?", actions: [cancelAction, calibrateAction])
        }
    }

    // MARK: Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return tableViewSections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        guard let tableViewSection = SettingsTableViewSection(rawValue: section) else {
            fatalError("Could not retrieve section")
        }
        
        switch tableViewSection {
        case .view:
            return 2
        case .calibration:
            var numAnchorCells = IndoorLocationManager.shared.anchors?.count ?? 0
            if numAnchorCells < 20 {
                // If less than 20 anchors are entered add an empty cell
                numAnchorCells += 1
            }
            // Another cell is added for the calibration button
            return numAnchorCells + 1
            
        case .filter:
            switch filterSettings.filterType {
            case .none:
                return 1
            case .kalman:
                return 3
            case .particle:
                return 6
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell
        
        guard let tableViewSection = SettingsTableViewSection(rawValue: indexPath.section) else {
            fatalError("Could not retrieve section")
        }
        
        // Determine the type of cell
        switch tableViewSection {
        case .view:
            cell = tableView.dequeueReusableCell(withIdentifier: String(describing: SwitchTableViewCell.self), for: indexPath)
        case .calibration:
            var numAnchorCells = IndoorLocationManager.shared.anchors?.count ?? 0
            if numAnchorCells < 20 {
                // Add an empty cell if less than 20 anchors are entered
                numAnchorCells += 1
            }
            if (indexPath.row < numAnchorCells) {
                cell = tableView.dequeueReusableCell(withIdentifier: String(describing: AnchorTableViewCell.self), for: indexPath)
            } else {
                cell = tableView.dequeueReusableCell(withIdentifier: String(describing: ButtonTableViewCell.self), for: indexPath)
            }
        case .filter:
            if (indexPath.row == 0) {
                cell = tableView.dequeueReusableCell(withIdentifier: String(describing: SegmentedControlTableViewCell.self), for: indexPath)
            } else if (filterSettings.filterType == .particle) && (indexPath.row == 1) {
                cell = tableView.dequeueReusableCell(withIdentifier: String(describing: SegmentedControlTableViewCell.self), for: indexPath)
            } else {
                cell = tableView.dequeueReusableCell(withIdentifier: String(describing: SliderTableViewCell.self), for: indexPath)
            }
        }
        
        // Configure the cell
        configureCell(cell, forIndexPath: indexPath)
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        guard let tableViewSection = SettingsTableViewSection(rawValue: section) else {
            fatalError("Could not retrieve section")
        }
        
        switch tableViewSection {
        case .view:
            return "View"
        case .calibration:
            return "Calibration"
        case .filter:
            return "Filter"
        }
    }
    
    //MARK: AnchorTableViewCellDelegate
    /**
     AnchorTableViewCellDelegate function that is called when a new anchor has to be added.
     - Parameter sender: The UIButton that was tapped
     - Parameter id: The ID of the anchor to be added
     - Parameter x: The x-coordinate of the anchor to be added
     - Parameter y: The y-coordinate of the anchor to be added
     */
    func onAddAnchorButtonTapped(_ sender: UIButton, id: Int, x: Int, y: Int) {
        IndoorLocationManager.shared.addAnchorWithID(id, x: x, y: y)
        calibrationPending = true
        tableView.reloadData()
    }
    
    /**
     AnchorTableViewCellDelegate function that is called when an anchor has to be removed.
     - Parameter sender: The UIButton that was tapped
     - Parameter id: The ID of the anchor to be removed
     */
    func onRemoveAnchorButtonTapped(_ sender: UIButton, id: Int) {
        IndoorLocationManager.shared.removeAnchorWithID(id)
        calibrationPending = true
        tableView.reloadData()
    }
    
    //MARK: ButtonTableViewCellDelegate
    /**
     ButtonTableViewCellDelegate function that is called when the button of a ButtonTableViewCell is tapped.
     The only ButtonTableViewCell that is used here is for calibration. Therefore calibration is initiated.
     - Parameter sender: The UIButton that was tapped
     */
    func onButtonTapped(_ sender: UIButton) {
        IndoorLocationManager.shared.calibrate() { error in
            if let error = error {
                alertWithTitle("Error", message: error.localizedDescription)
            } else {
                alertWithTitle("Success", message: "Calibration was successful!")
                self.calibrationPending = false
                self.calibratedAnchors = IndoorLocationManager.shared.anchors
            }
        }
    }
    
    //MARK: SegmentedControlTableViewCellDelegate
    /**
     SegmentedControlTableViewCellDelegate function that is called when the value of the segmented control of a SegmentedControlTableViewCell
     is changed. The  only SegmentedControlTableViewCell that is used here is for the filter type. Therefore the filter type is changed in the settings.
     - Parameter sender: The UISegmentedControl that was changed
     */
    func onSegmentedControlValueChanged(_ sender: UISegmentedControl) {
        
        guard let segmentedControlType = SegmentedControlType(rawValue: sender.tag) else {
            fatalError("Could not retrieve segmented control type")
        }
        
        // Determine which segmented control has changed and edit its value in the settings accordingly
        switch segmentedControlType {
        case .filterType:
            filterSettings.filterType = FilterType(rawValue: sender.selectedSegmentIndex) ?? .none
            tableView.reloadData()
            settingsDelegate?.changeFilterType(filterSettings.filterType)
            filterInitializationPending = true
        case .particleFilterType:
            filterSettings.particleFilterType = ParticleFilterType(rawValue: sender.selectedSegmentIndex) ?? .bootstrap
        }
    }
    
    //MARK: SliderTableViewCellDelegate
    /**
     SliderTableViewCellDelegate function that is called when the value of the slider of a SliderTableViewCell is changed.
     The type of slider that is used is determined by its tag and the value associated with it is changed in the settings.
     For most settings the filters also have to be reinitialized.
     - Parameter sender: The UISlider that was changed
     */
    func onSliderValueChanged(_ sender: UISlider) {
        
        guard let sliderType = SliderType(rawValue: sender.tag) else {
            fatalError("Could not retrieve slider type")
        }
        
        // Determine which slider has changed and edit its value in the settings accordingly
        switch sliderType {
        case .processUncertainty:
            filterSettings.processUncertainty = Int(sender.value)
            filterInitializationPending = true
        case .distanceUncertainty:
            filterSettings.distanceUncertainty = Int(sender.value)
            filterInitializationPending = true
        case .numberOfParticles:
            filterSettings.numberOfParticles = Int(sender.value)
            filterInitializationPending = true
        case .N_thr:
            filterSettings.N_thr = sender.value
        }
    }
    
    //MARK: SwitchTableViewCellDelegate
    /**
     SwitchTableViewCellDelegate function that is called when the switch of a SwitchTableViewCell is tapped.
     The type of switch that is used is determined by its tag and the value associated with it is changed in the settings.
     - Parameter sender: The UISwitch that was tapped
     */
    func onSwitchTapped(_ sender: UISwitch) {
        
        guard let switchType = SwitchType(rawValue: sender.tag) else {
            fatalError("Could not retrieve switch type")
        }
        
        switch switchType {
        case .isFloorplanVisible:
            filterSettings.isFloorplanVisible = sender.isOn
            settingsDelegate?.toggleFloorplanVisible(sender.isOn)
        case .areMeasurementsVisible:
            filterSettings.areMeasurementsVisible = sender.isOn
            settingsDelegate?.toggleMeasurementsVisible(sender.isOn)
        }
    }
    
    //MARK: Private API
    /**
     Configure the cell according to the desired layout
     - Parameter cell: The cell to configure
     - Parameter indexPath: The indexPath of the cell
     */
    private func configureCell(_ cell: UITableViewCell, forIndexPath indexPath: IndexPath) {
        
        guard let tableViewSection = SettingsTableViewSection(rawValue: indexPath.section) else {
            fatalError("Could not retrieve section")
        }
        
        switch tableViewSection {
        case .view:
            if let cell = cell as? SwitchTableViewCell {
                switch indexPath.row {
                case 0:
                    // Floorplan switch
                    cell.setupWithText("Floorplan", isOn: filterSettings.isFloorplanVisible, delegate: self, tag: SwitchType.isFloorplanVisible.rawValue)
                case 1:
                    // Measurement switch
                    cell.setupWithText("Measurements", isOn: filterSettings.areMeasurementsVisible, delegate: self, tag: SwitchType.areMeasurementsVisible.rawValue)
                default:
                    break
                }
            }
            
        case .calibration:
            if let cell = cell as? ButtonTableViewCell {
                // Calibration button
                cell.setupWithText("Calibrate", delegate: self)
            } else if let cell = cell as? AnchorTableViewCell {
                if let anchors = IndoorLocationManager.shared.anchors {
                    let index = indexPath.row
                    if index < anchors.count {
                        // Anchor cells with previously entered anchor
                        cell.setupWithDelegate(self, anchor: anchors[index])
                    } else {
                        // Empty anchor cell
                        cell.setupWithDelegate(self)
                    }
                } else {
                    // Empty anchor cell
                    cell.setupWithDelegate(self)
                }
            }
            
        case .filter:
            if let cell = cell as? SegmentedControlTableViewCell {
                switch indexPath.row {
                case 0:
                    // Filter type segmented control
                    let selectedSegmentIndex = filterSettings.filterType.rawValue
                    cell.setupWithSegments(["None", "Kalman", "Particle"], selectedSegmentIndex: selectedSegmentIndex, delegate: self, tag: SegmentedControlType.filterType.rawValue)
                case 1:
                    // Particle filter type segmented control
                    let selectedSegmentIndex = filterSettings.particleFilterType.rawValue
                    cell.setupWithSegments(["Bootstrap", "Regularized"], selectedSegmentIndex: selectedSegmentIndex, delegate: self, tag: SegmentedControlType.particleFilterType.rawValue)
                default:
                    break
                }
                

            } else if let cell = cell as? SliderTableViewCell {
                switch filterSettings.filterType {
                // Kalman filter sliders
                case .kalman:
                    switch indexPath.row {
                    case 1:
                        // Process uncertainty slider
                        cell.setupWithValue(filterSettings.processUncertainty, minValue: 0, maxValue: 100, text: "Proc. uncertainty:", unit: "mg²", delegate: self, tag: SliderType.processUncertainty.rawValue)
                    case 2:
                        // Distance uncertainty slider
                        cell.setupWithValue(filterSettings.distanceUncertainty, minValue: 1, maxValue: 100, text: "Dist. uncertainty:", unit: "cm²", delegate: self, tag: SliderType.distanceUncertainty.rawValue)
                    default:
                        break
                    }
                // Particle filter sliders
                case .particle:
                    switch indexPath.row {
                    case 2:
                        // Process uncertainty slider
                        cell.setupWithValue(filterSettings.processUncertainty, minValue: 0, maxValue: 200, text: "Proc. uncertainty:", unit: "mg²", delegate: self, tag: SliderType.processUncertainty.rawValue)
                    case 3:
                        // Distance uncertainty slider
                        cell.setupWithValue(filterSettings.distanceUncertainty, minValue: 1, maxValue: 100, text: "Dist. uncertainty:", unit: "cm²", delegate: self, tag: SliderType.distanceUncertainty.rawValue)
                    case 4:
                        // Number of particles slider
                        cell.setupWithValue(filterSettings.numberOfParticles, minValue: 1, maxValue: 1000, text: "No. Particles:", delegate: self, tag: SliderType.numberOfParticles.rawValue)
                    case 5:
                        // Effective sample size slider
                        cell.setupWithValue(Int(filterSettings.N_thr), minValue: 1, maxValue: filterSettings.numberOfParticles, text: "N_thr:", delegate: self, tag: SliderType.N_thr.rawValue)
                    default:
                        break
                    }
                default:
                    break
                }
            }
        }
    }
    
    /**
     Function to dismiss the keyboard if tapped outside of a UITextField
     */
    func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func didTapCloseButton(_ sender: UIButton) {
        self.dismiss(animated: true)
    }
}

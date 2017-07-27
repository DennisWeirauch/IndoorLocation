//
//  SettingsTableViewController.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 29.05.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

protocol SettingsTableViewControllerDelegate {
    func toggleFloorplanVisible(_ isFloorPlanVisible: Bool)
    func toggleMeasurementsVisible(_ areMeasurementsVisible: Bool)
    func changeFilterType(_ filterType: FilterType)
}

class SettingsTableViewController: UITableViewController, AnchorTableViewCellDelegate, ButtonTableViewCellDelegate, SegmentedControlTableViewCellDelegate, SliderTableViewCellDelegate, SwitchTableViewCellDelegate {
    
    enum SettingsTableViewSection: Int {
        case view = 0
        case calibration
        case filter
    }
    
    enum SliderType: Int {
        case accelerationUncertainty = 0
        case distanceUncertainty
        case processingUncertainty
        case numberOfParticles
    }
    
    enum SwitchType: Int {
        case isFloorplanVisible = 0
        case areMeasurementsVisible
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

        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
        let titleLabel = UILabel(frame: CGRect(x: 0, y: 12.5, width: 200, height: 25))
        titleLabel.text = "Settings"
        titleLabel.font = UIFont.systemFont(ofSize: 20)
        titleLabel.textAlignment = .center
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
    
    override func viewDidDisappear(_ animated: Bool) {
        // Initialize Filter if settings have changed
        if filterInitializationPending {
            switch filterSettings.filterType {
            case .none:
                IndoorLocationManager.shared.filter = BayesianFilter()
            case .kalman:
                guard let anchors = IndoorLocationManager.shared.anchors,
                    let initialDistances = IndoorLocationManager.shared.initialDistances else { return }
                IndoorLocationManager.shared.filter = KalmanFilter(anchors: anchors.filter({ $0.isActive }), distances: initialDistances)
            case .particle:
                guard let anchors = IndoorLocationManager.shared.anchors,
                    let initialDistances = IndoorLocationManager.shared.initialDistances else { return }
                IndoorLocationManager.shared.filter = ParticleFilter(anchors: anchors.filter({ $0.isActive }), distances: initialDistances)
            }
        }
        
        if calibrationPending {
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                IndoorLocationManager.shared.anchors = self.calibratedAnchors
            }
            
            let calibrateAction = UIAlertAction(title: "Calibrate", style: .default) { _ in
                IndoorLocationManager.shared.calibrate() { error in
                    if let error = error {
                        alertWithTitle("Error", message: error.localizedDescription)
                    } else {
                        alertWithTitle("Success", message: "Calibration Successful!")
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
            return numAnchorCells + 1   // Add a cell for calibration button
            
        case .filter:
            switch filterSettings.filterType {
            case .none:
                return 1
            case .kalman:
                return 4
            case .particle:
                return 5
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell
        
        guard let tableViewSection = SettingsTableViewSection(rawValue: indexPath.section) else {
            fatalError("Could not retrieve section")
        }
        
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
            } else {
                cell = tableView.dequeueReusableCell(withIdentifier: String(describing: SliderTableViewCell.self), for: indexPath)
            }
        }
        
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
        
    //MARK: SegmentedControlTableViewCellDelegate
    func onSegmentedControlValueChanged(_ sender: UISegmentedControl) {
        filterSettings.filterType = FilterType(rawValue: sender.selectedSegmentIndex) ?? .none
        tableView.reloadData()
        settingsDelegate?.changeFilterType(filterSettings.filterType)
        filterInitializationPending = true
    }
    
    //MARK: SliderTableViewCellDelegate
    func onSliderValueChanged(_ sender: UISlider) {
        
        guard let sliderType = SliderType(rawValue: sender.tag) else {
            fatalError("Could not retrieve slider type")
        }
        
        switch sliderType {
        case .accelerationUncertainty:
            filterSettings.accelerationUncertainty = Int(sender.value)
        case .distanceUncertainty:
            filterSettings.distanceUncertainty = Int(sender.value)
        case .processingUncertainty:
            filterSettings.processingUncertainty = Int(sender.value)
        case .numberOfParticles:
            filterSettings.numberOfParticles = Int(sender.value)
        }
        
        filterInitializationPending = true
    }
    
    //MARK: ButtonTableViewCellDelegate
    func onButtonTapped(_ sender: UIButton) {
        IndoorLocationManager.shared.calibrate() { error in
            if let error = error {
                alertWithTitle("Error", message: error.localizedDescription)
            } else {
                alertWithTitle("Success", message: "Calibration Successful!")
                self.calibrationPending = false
                self.calibratedAnchors = IndoorLocationManager.shared.anchors
            }
        }
    }
    
    //MARK: AnchorTableViewCellDelegate
    func onAddAnchorButtonTapped(_ sender: UIButton, id: Int, x: Int, y: Int) {
        IndoorLocationManager.shared.addAnchorWithID(id, x: x, y: y)
        calibrationPending = true
        tableView.reloadData()
    }
    
    func onRemoveAnchorButtonTapped(_ sender: UIButton, id: Int) {
        IndoorLocationManager.shared.removeAnchorWithID(id)
        calibrationPending = true
        tableView.reloadData()
    }
    
    //MARK: SwitchTableViewCellDelegate
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
    private func configureCell(_ cell: UITableViewCell, forIndexPath indexPath: IndexPath) {
        
        guard let tableViewSection = SettingsTableViewSection(rawValue: indexPath.section) else {
            fatalError("Could not retrieve section")
        }
        
        switch tableViewSection {
        case .view:
            if let cell = cell as? SwitchTableViewCell {
                switch indexPath.row {
                case 0:
                    cell.setupWithText("Floorplan", isOn: filterSettings.isFloorplanVisible, delegate: self, tag: SwitchType.isFloorplanVisible.rawValue)
                case 1:
                    cell.setupWithText("Measurements", isOn: filterSettings.areMeasurementsVisible, delegate: self, tag: SwitchType.areMeasurementsVisible.rawValue)
                default:
                    break
                }
            }
            
        case .calibration:
            if let cell = cell as? ButtonTableViewCell {
                cell.setupWithText("Calibrate!", delegate: self)
            } else if let cell = cell as? AnchorTableViewCell {
                if let anchors = IndoorLocationManager.shared.anchors {
                    let index = indexPath.row
                    if index < anchors.count {
                        cell.setupWithDelegate(self, anchor: anchors[index])
                    } else {
                        cell.setupWithDelegate(self)
                    }
                } else {
                    cell.setupWithDelegate(self)
                }
            }
            
        case .filter:
            if let cell = cell as? SegmentedControlTableViewCell {
                let selectedSegmentIndex = filterSettings.filterType.rawValue
                
                cell.setupWithSegments(["None", "Kalman", "Particle"], selectedSegmentIndex: selectedSegmentIndex, delegate: self, tag: tableViewSection.rawValue)
            } else if let cell = cell as? SliderTableViewCell {
                switch filterSettings.filterType {
                case .kalman:
                    switch indexPath.row {
                    case 1:
                        cell.setupWithValue(filterSettings.accelerationUncertainty, minValue: 1, maxValue: 100, text: "Acc. uncertainty:", unit: "cm/s²", delegate: self, tag: SliderType.accelerationUncertainty.rawValue)
                    case 2:
                        cell.setupWithValue(filterSettings.distanceUncertainty, minValue: 1, maxValue: 100, text: "Dist. uncertainty:", unit: "cm", delegate: self, tag: SliderType.distanceUncertainty.rawValue)
                    case 3:
                        cell.setupWithValue(filterSettings.processingUncertainty, minValue: 0, maxValue: 100, text: "Proc. uncertainty:", unit: "cm/s²", delegate: self, tag: SliderType.processingUncertainty.rawValue)
                    default:
                        break
                    }
                case .particle:
                    switch indexPath.row {
                    case 1:
                        //TODO: Remove acceleration uncertainty from particle filter
                        cell.setupWithValue(0, minValue: 0, maxValue: 0, text: "Acc. uncertainty:", unit: "cm/s²", delegate: self, tag: SliderType.accelerationUncertainty.rawValue)
                    case 2:
                        cell.setupWithValue(filterSettings.distanceUncertainty, minValue: 1, maxValue: 100, text: "Dist. uncertainty:", unit: "cm", delegate: self, tag: SliderType.distanceUncertainty.rawValue)
                    case 3:
                        cell.setupWithValue(filterSettings.processingUncertainty, minValue: 0, maxValue: 1000, text: "Proc. uncertainty:", unit: "cm/s²", delegate: self, tag: SliderType.processingUncertainty.rawValue)
                    case 4:
                        cell.setupWithValue(filterSettings.numberOfParticles, minValue: 1, maxValue: 1000, text: "Particles:", delegate: self, tag: SliderType.numberOfParticles.rawValue)
                    default:
                        break
                        
                    }
                default:
                    break
                }
            }
        }
    }
    
    func dismissKeyboard() {
        self.view.endEditing(true)
    }
}

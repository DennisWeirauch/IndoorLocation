//
//  SettingsTableViewController.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 29.05.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

enum SettingsTableViewSection: Int {
    case positioningMode = 0
    case calibrationMode
    case dataSink
    case filterType
}

enum SliderType: Int {
    case accelerationUncertainty = 0
    case distanceUncertainty
    case processingUncertainty
    case numberOfParticles
}

protocol SettingsTableViewControllerDelegate {
    func toggleFloorplanVisible(_ floorPlanVisible: Bool)
}

class SettingsTableViewController: UITableViewController, SegmentedControlTableViewCellDelegate, SliderTableViewCellDelegate, ButtonTableViewCellDelegate, AnchorTableViewCellDelegate {
    
    let tableViewSections = [SettingsTableViewSection.positioningMode.rawValue,
                             SettingsTableViewSection.calibrationMode.rawValue,
                             SettingsTableViewSection.dataSink.rawValue,
                             SettingsTableViewSection.filterType.rawValue]
    
    let filterSettings = IndoorLocationManager.shared.filterSettings
    var settingsDelegate: SettingsTableViewControllerDelegate?
    
    //MARK: ViewController lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
        let titleLabel = UILabel(frame: CGRect(x: 0, y: 12.5, width: 200, height: 25))
        LabelHelper.setupLabel(titleLabel, withText: "Settings", fontSize: 20, alignment: .center)
        headerView.addSubview(titleLabel)
        tableView.tableHeaderView = headerView
        tableView.bounces = false
        tableView.showsVerticalScrollIndicator = false
        
        tableView.register(SegmentedControlTableViewCell.self, forCellReuseIdentifier: String(describing: SegmentedControlTableViewCell.self))
        tableView.register(SliderTableViewCell.self, forCellReuseIdentifier: String(describing: SliderTableViewCell.self))
        tableView.register(ButtonTableViewCell.self, forCellReuseIdentifier: String(describing: ButtonTableViewCell.self))
        tableView.register(AnchorTableViewCell.self, forCellReuseIdentifier: String(describing: AnchorTableViewCell.self))
        
        tableView.separatorStyle = .none
        tableView.allowsSelection = false
        
        // Tap gesture recognizer for dismissing keyboard when touching outside of UITextFields
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGestureRecognizer.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tapGestureRecognizer)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // Initialize Filter
        switch filterSettings.filterType {
        case .none:
            IndoorLocationManager.shared.filter = BayesianFilter()
        case .kalman:
            guard let position = IndoorLocationManager.shared.position else { return }
            IndoorLocationManager.shared.filter = KalmanFilter(position: position)
        case .particle:
            guard let position = IndoorLocationManager.shared.position else { return }
            IndoorLocationManager.shared.filter = ParticleFilter(position: position)
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
        case .positioningMode:
            return 1
        case .calibrationMode:
            if filterSettings.calibrationModeIsAutomatic {
                return 2
            } else {
                return 3 + (IndoorLocationManager.shared.anchors?.count ?? 0) // 1 Segmented Control, 1 Button, 1 cell for each anchor found, 1 empty cell
            }
        case .dataSink:
            return 1
        case .filterType:
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
        case .positioningMode:
            cell = tableView.dequeueReusableCell(withIdentifier: String(describing: SegmentedControlTableViewCell.self), for: indexPath)
        case .calibrationMode:
            if (indexPath.row == 0) {
                cell = tableView.dequeueReusableCell(withIdentifier: String(describing: SegmentedControlTableViewCell.self), for: indexPath)
            } else if filterSettings.calibrationModeIsAutomatic {
                cell = tableView.dequeueReusableCell(withIdentifier: String(describing: ButtonTableViewCell.self), for: indexPath)
            } else {
                let numCells = 3 + (IndoorLocationManager.shared.anchors?.count ?? 0)
                if (indexPath.row == numCells - 1) {
                    cell = tableView.dequeueReusableCell(withIdentifier: String(describing: ButtonTableViewCell.self), for: indexPath)
                } else {
                    cell = tableView.dequeueReusableCell(withIdentifier: String(describing: AnchorTableViewCell.self), for: indexPath)
                }
            }
        case .dataSink:
            cell = tableView.dequeueReusableCell(withIdentifier: String(describing: SegmentedControlTableViewCell.self), for: indexPath)
        case .filterType:
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
        case .positioningMode:
            return "Positioning mode"
        case .calibrationMode:
            return "Calibration mode"
        case .dataSink:
            return "Data Sink"
        case .filterType:
            return "Filter Type"
        }
    }
        
    //MARK: SegmentedControlTableViewCellDelegate
    func onSegmentedControlValueChanged(_ sender: UISegmentedControl) {
        
        guard let tableViewSection = SettingsTableViewSection(rawValue: sender.tag) else {
            fatalError("Could not retrieve section")
        }
        
        switch tableViewSection {
        case .positioningMode:
            filterSettings.positioningModeIsRelative = sender.selectedSegmentIndex == 0
            settingsDelegate?.toggleFloorplanVisible(!filterSettings.positioningModeIsRelative)
        case .calibrationMode:
            filterSettings.calibrationModeIsAutomatic = sender.selectedSegmentIndex == 0
            tableView.reloadData()
        case .dataSink:
            filterSettings.dataSinkIsLocal = sender.selectedSegmentIndex == 0
        case .filterType:
            filterSettings.filterType = FilterType(rawValue: sender.selectedSegmentIndex) ?? .none
            tableView.reloadData()
        }
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
    }
    
    //MARK: ButtonTableViewCellDelegate
    func onButtonTapped(_ sender: UIButton) {
        IndoorLocationManager.shared.calibrate(automatic: filterSettings.calibrationModeIsAutomatic)
    }
    
    //MARK: AnchorTableViewCellDelegate
    func onAddAnchorButtonTapped(_ sender: UIButton, id: Int, x: Int, y: Int) {
        IndoorLocationManager.shared.addAnchorWithID(id, x: x, y: y)
        tableView.reloadData()
    }
    
    func onEditTextField(_ sender: UITextField) {
        //TODO!
    }
    
    //MARK: Private API
    private func configureCell(_ cell: UITableViewCell, forIndexPath indexPath: IndexPath) {
        
        guard let tableViewSection = SettingsTableViewSection(rawValue: indexPath.section) else {
            fatalError("Could not retrieve section")
        }
        
        switch tableViewSection {
        case .positioningMode:
            if let cell = cell as? SegmentedControlTableViewCell {
                let selectedSegmentIndex = filterSettings.positioningModeIsRelative ? 0 : 1
                
                cell.setupWithSegments(["Relative", "Absolute"], selectedSegmentIndex: selectedSegmentIndex, delegate: self, tag: tableViewSection.rawValue)
            }
        case .calibrationMode:
            if let cell = cell as? SegmentedControlTableViewCell {
                let selectedSegmentIndex = filterSettings.calibrationModeIsAutomatic ? 0 : 1
                
                cell.setupWithSegments(["Automatic", "Manual"], selectedSegmentIndex: selectedSegmentIndex, delegate: self, tag: tableViewSection.rawValue)
            } else if let cell = cell as? ButtonTableViewCell {
                cell.setupWithText("Calibrate!", delegate: self)
            } else if let cell = cell as? AnchorTableViewCell {
                if let anchors = IndoorLocationManager.shared.anchors {
                    let index = indexPath.row - 1
                    if index < anchors.count {
                        cell.setupWithID(anchors[index].id, x: Int(anchors[index].coordinates.x), y: Int(anchors[index].coordinates.y), delegate: self)
                    } else {
                        cell.setupWithDelegate(self)
                    }
                } else {
                    cell.setupWithDelegate(self)
                }
            }
        case .dataSink:
            if let cell = cell as? SegmentedControlTableViewCell {
                let selectedSegmentIndex = filterSettings.dataSinkIsLocal ? 0 : 1
                
                cell.setupWithSegments(["Local", "Remote"], selectedSegmentIndex: selectedSegmentIndex, delegate: self, tag: tableViewSection.rawValue)
            }
        case .filterType:
            if let cell = cell as? SegmentedControlTableViewCell {
                let selectedSegmentIndex = filterSettings.filterType.rawValue
                
                cell.setupWithSegments(["None", "Kalman", "Particle"], selectedSegmentIndex: selectedSegmentIndex, delegate: self, tag: tableViewSection.rawValue)
            } else if let cell = cell as? SliderTableViewCell {
                switch filterSettings.filterType {
                case .kalman:
                    switch indexPath.row {
                    case 1:
                        cell.setupWithValue(filterSettings.accelerationUncertainty, minValue: 0, maxValue: 100, text: "Acc. uncertainty:", delegate: self, tag: SliderType.accelerationUncertainty.rawValue)
                    case 2:
                        cell.setupWithValue(filterSettings.distanceUncertainty, minValue: 0, maxValue: 100, text: "Dist. uncertainty:", delegate: self, tag: SliderType.distanceUncertainty.rawValue)
                    case 3:
                        cell.setupWithValue(filterSettings.processingUncertainty, minValue: 0, maxValue: 100, text: "Proc. uncertainty:", delegate: self, tag: SliderType.processingUncertainty.rawValue)
                    default:
                        break
                    }
                case .particle:
                    switch indexPath.row {
                    case 1:
                        cell.setupWithValue(filterSettings.accelerationUncertainty, minValue: 0, maxValue: 100, text: "Acc. uncertainty:", delegate: self, tag: SliderType.accelerationUncertainty.rawValue)
                    case 2:
                        cell.setupWithValue(filterSettings.distanceUncertainty, minValue: 0, maxValue: 100, text: "Dist. uncertainty:", delegate: self, tag: SliderType.distanceUncertainty.rawValue)
                    case 3:
                        cell.setupWithValue(filterSettings.processingUncertainty, minValue: 0, maxValue: 100, text: "Proc. uncertainty:", delegate: self, tag: SliderType.processingUncertainty.rawValue)
                    case 4:
                        cell.setupWithValue(filterSettings.numberOfParticles, minValue: 0, maxValue: 1000, text: "Particles:", delegate: self, tag: SliderType.numberOfParticles.rawValue)
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

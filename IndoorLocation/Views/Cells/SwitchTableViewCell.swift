//
//  SwitchTableViewCell.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 30.05.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

protocol SwitchTableViewCellDelegate: class {
    func onSwitchTapped(_ sender: UISwitch)
}

/**
 A cell that contains a switch.
 */
class SwitchTableViewCell: UITableViewCell {
    
    weak var delegate: SwitchTableViewCellDelegate?
    
    var label: UILabel!
    var switcher: UISwitch!
    
    //MARK: Public API
    /**
     Sets up the cell with the provided data
     - Parameter text: The description of the switch
     - Parameter delegate: The cell's delegate
     - Parameter tag: The tag of the cell
     */
    func setupWithText(_ text: String, isOn: Bool, delegate: SwitchTableViewCellDelegate, tag: Int) {
        
        for subview in contentView.subviews {
            subview.removeFromSuperview()
        }
        
        self.delegate = delegate
        
        // Set up label
        label = UILabel(frame: CGRect(x: 10, y: 5, width: contentView.frame.width - 100, height: 30))
        label.text = text
        contentView.addSubview(label)
        
        // Set up switch
        switcher = UISwitch(frame: CGRect(x: contentView.frame.maxX - 60, y: 5, width: 50, height: 30))
        switcher.isOn = isOn
        switcher.onTintColor = UIColor.Application.lightGreen
        switcher.tag = tag
        switcher.addTarget(self, action: #selector(onSwitchTapped(_:)), for: .valueChanged)
        contentView.addSubview(switcher)
    }
    
    /**
     Function that is called when the switch is tapped. The delegate is informed about this event.
     */
    @objc func onSwitchTapped(_ sender: UISwitch) {
        delegate?.onSwitchTapped(sender)
    }
}

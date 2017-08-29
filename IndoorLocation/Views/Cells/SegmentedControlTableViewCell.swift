//
//  SegmentedControlTableViewCell.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 29.05.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

protocol SegmentedControlTableViewCellDelegate: class {
    func onSegmentedControlValueChanged(_ sender: UISegmentedControl)
}

/**
 A cell that contains a segmented control.
 */
class SegmentedControlTableViewCell: UITableViewCell {

    //MARK: Stored properties
    weak var delegate: SegmentedControlTableViewCellDelegate?
    
    var segmentedControl: UISegmentedControl!
    
    //MARK: Public API
    /**
     Sets up the cell with the provided data
     - Parameter segments: The segments to be displayed
     - Parameter selectedSegmentIndex: The index of the segment that is to be selected
     - Parameter delegate: The cell's delegate
     - Parameter tag: The tag of the cell
     */
    func setupWithSegments(_ segments: [String], selectedSegmentIndex: Int, delegate: SegmentedControlTableViewCellDelegate, tag: Int) {
        
        for subview in contentView.subviews {
            subview.removeFromSuperview()
        }
        
        self.delegate = delegate
        
        // Set up segmented control
        segmentedControl = UISegmentedControl(items: segments)
        segmentedControl.frame = CGRect(x: 10, y: 5, width: contentView.frame.width - 20, height: 30)
        segmentedControl.selectedSegmentIndex = selectedSegmentIndex
        segmentedControl.addTarget(self, action: #selector(onSegmentedControlValueChanged(_:)), for: .valueChanged)
        segmentedControl.tag = tag
        
        contentView.addSubview(segmentedControl)
    }
    
    /**
     Function that is called when the value of the segmented control changes. The delegate is informed about this event.
     */
    func onSegmentedControlValueChanged(_ sender: UISegmentedControl) {
        delegate?.onSegmentedControlValueChanged(sender)
    }
}

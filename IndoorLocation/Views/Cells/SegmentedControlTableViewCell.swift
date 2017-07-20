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

class SegmentedControlTableViewCell: UITableViewCell {

    //MARK: Stored properties
    weak var delegate: SegmentedControlTableViewCellDelegate?
    
    var segmentedControl: UISegmentedControl?
    
    //MARK: Public API
    func setupWithSegments(_ segments: [String], selectedSegmentIndex: Int, delegate: SegmentedControlTableViewCellDelegate, tag: Int) {
        
        for subview in contentView.subviews {
            subview.removeFromSuperview()
        }
        
        self.delegate = delegate
                
        segmentedControl = UISegmentedControl(items: segments)
        guard let segmentedControl = segmentedControl else { return }
        segmentedControl.frame = CGRect(x: 10, y: 5, width: contentView.frame.width - 20, height: 30)
        segmentedControl.selectedSegmentIndex = selectedSegmentIndex
        segmentedControl.addTarget(self, action: #selector(onSegmentedControlValueChanged(_:)), for: .valueChanged)
        segmentedControl.tag = tag
        
        contentView.addSubview(segmentedControl)
    }
    
    func onSegmentedControlValueChanged(_ sender: UISegmentedControl) {
        delegate?.onSegmentedControlValueChanged(sender)
    }
}

//
//  SliderTableViewCell.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 29.05.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

protocol SliderTableViewCellDelegate: class {
    func onSliderValueChanged(_ sender: UISlider)
}

/**
 A cell that contains a slider.
 */
class SliderTableViewCell: UITableViewCell {

    weak var delegate: SliderTableViewCellDelegate?
    
    var label: UILabel!
    var slider: UISlider!
    
    var labelDescription: String!
    var labelUnit: String!
    
    //MARK: Public API
    /**
     Sets up the cell with the provided data
     - Parameter value: The current value of the slider
     - Parameter minValue: The minimum value of the slider
     - Parameter maxValue: The maximum value of the slider
     - Parameter text: The description of the slider
     - Parameter unit: The unit of the value to be displayed
     - Parameter delegate: The cell's delegate
     - Parameter tag: The tag of the cell
     */
    func setupWithValue(_ value: Int, minValue: Int, maxValue: Int, text: String, unit: String = "", delegate: SliderTableViewCellDelegate, tag: Int) {
        
        for subview in contentView.subviews {
            subview.removeFromSuperview()
        }
        
        self.delegate = delegate
        
        // Set up label
        labelDescription = text
        labelUnit = unit
                
        label = UILabel(frame: CGRect(x: 10, y: 4, width: contentView.frame.width - 20, height: 16))
        
        label.text = labelDescription + " \(value) " + labelUnit
        label.font = UIFont.systemFont(ofSize: 13)
        
        contentView.addSubview(label)
        
        // Set up slider
        slider = UISlider(frame: CGRect(x: 10, y: 24, width: contentView.frame.width - 20, height: 20))
        
        slider.minimumValue = Float(minValue)
        slider.maximumValue = Float(maxValue)
        slider.value = Float(value)
        slider.tag = tag
        
        slider.addTarget(self, action: #selector(onSliderValueChanged(_:)), for: .valueChanged)
        
        contentView.addSubview(slider)
    }
    
    /**
     Function that is called when the value of the slider changes. The delegate is informed about this event.
     */
    func onSliderValueChanged(_ sender: UISlider) {
        label.text = labelDescription + " \(Int(sender.value)) " + labelUnit
        delegate?.onSliderValueChanged(sender)
    }
}

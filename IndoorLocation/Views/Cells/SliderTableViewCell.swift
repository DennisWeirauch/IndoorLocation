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

class SliderTableViewCell: UITableViewCell {

    weak var delegate: SliderTableViewCellDelegate?
    
    var label: UILabel?
    var slider: UISlider?
    
    var labelText: String?
    
    //MARK: Public API
    func setupWithValue(_ value: Int, minValue: Int, maxValue: Int, text: String, delegate: SliderTableViewCellDelegate, tag: Int) {
        
        for subview in contentView.subviews {
            subview.removeFromSuperview()
        }
        
        self.delegate = delegate
        
        labelText = text
                
        label = UILabel(frame: CGRect(x: 10, y: 4, width: contentView.frame.width - 20, height: 16))
        guard let label = label else { return }
        LabelHelper.setupLabel(label, withText: text + " \(value)", fontSize: 13)
        
        contentView.addSubview(label)
        
        slider = UISlider(frame: CGRect(x: 10, y: 24, width: contentView.frame.width - 20, height: 20))
        guard let slider = slider else { return }
        SliderHelper.setupSlider(slider, value: Float(value), minValue: Float(minValue), maxValue: Float(maxValue), tag: tag)
        slider.addTarget(self, action: #selector(onSliderValueChanged(_:)), for: .valueChanged)
        
        contentView.addSubview(slider)
    }
    
    func onSliderValueChanged(_ sender: UISlider) {
        label?.text = (labelText ?? "") + " \(Int(sender.value))"
        delegate?.onSliderValueChanged(sender)
    }
}

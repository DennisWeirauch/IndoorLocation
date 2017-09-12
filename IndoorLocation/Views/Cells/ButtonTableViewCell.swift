//
//  ButtonTableViewCell.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 30.05.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

protocol ButtonTableViewCellDelegate: class {
    func onButtonTapped(_ sender: UIButton)
}

/**
 A cell that contains a button.
 */
class ButtonTableViewCell: UITableViewCell {

    weak var delegate: ButtonTableViewCellDelegate?
    
    var button: UIButton!
    
    //MARK: Public API
    /**
     Sets up the cell with the provided data
     - Parameter text: The text of the button
     - Parameter delegate: The cell's delegate
     */
    func setupWithText(_ text: String, delegate: ButtonTableViewCellDelegate) {
        
        for subview in contentView.subviews {
            subview.removeFromSuperview()
        }
        
        self.delegate = delegate
        
        // Set up button
        button = UIButton(frame: contentView.frame)
        
        button.setTitle(text, for: .normal)
        button.setTitleColor(UIColor.Application.darkBlue, for: .normal)
        
        button.addTarget(self, action: #selector(onButtonTapped(_:)), for: .touchUpInside)
        
        contentView.addSubview(button)
    }
    
    /**
     Function that is called when the button is tapped. The delegate is informed about this event.
     */
    func onButtonTapped(_ sender: UIButton) {
        delegate?.onButtonTapped(sender)
    }
}

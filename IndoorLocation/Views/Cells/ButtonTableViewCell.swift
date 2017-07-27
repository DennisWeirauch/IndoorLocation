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

class ButtonTableViewCell: UITableViewCell {

    weak var delegate: ButtonTableViewCellDelegate?
    
    var button: UIButton!
    
    //MARK: Public API
    func setupWithText(_ text: String, delegate: ButtonTableViewCellDelegate) {
        
        for subview in contentView.subviews {
            subview.removeFromSuperview()
        }
        
        self.delegate = delegate
                
        button = UIButton(frame: contentView.frame)
        
        button.setTitle(text, for: .normal)
        button.setTitleColor(button.tintColor, for: .normal)
        
        button.addTarget(self, action: #selector(onButtonTapped(_:)), for: .touchUpInside)
        
        contentView.addSubview(button)
    }
    
    func onButtonTapped(_ sender: UIButton) {
        delegate?.onButtonTapped(sender)
    }
}

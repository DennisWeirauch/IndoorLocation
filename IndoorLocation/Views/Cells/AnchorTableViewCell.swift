//
//  AnchorTableViewCell.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 30.05.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

protocol AnchorTableViewCellDelegate: class {
    func onAddAnchorButtonTapped(_ sender: UIButton, id: Int, x: Int, y: Int)
    func onRemoveAnchorButtonTapped(_ sender: UIButton, id: Int)
}

class AnchorTableViewCell: UITableViewCell {
    
    weak var delegate: AnchorTableViewCellDelegate?
    
    var idTextField: UITextField!
    var xTextField: UITextField!
    var yTextField: UITextField!
    
    var button: UIButton!
    
    //MARK: Public API
    func setupWithDelegate(_ delegate: AnchorTableViewCellDelegate, anchor: Anchor? = nil) {
        
        for subview in contentView.subviews {
            subview.removeFromSuperview()
        }
        
        self.delegate = delegate
                
        idTextField = UITextField(frame: CGRect(x: 10, y: 0, width: 40, height: frame.height))
        xTextField = UITextField(frame: CGRect(x: idTextField.frame.maxX, y: 0, width: 50, height: frame.height))
        yTextField = UITextField(frame: CGRect(x: xTextField.frame.maxX, y: 0, width: xTextField.frame.width, height: frame.height))
        
        idTextField.font = UIFont.systemFont(ofSize: 12)
        xTextField.font = UIFont.systemFont(ofSize: 12)
        yTextField.font = UIFont.systemFont(ofSize: 12)
        
        if let anchor = anchor {
            idTextField.text = String(format:"%2X", anchor.id)
            xTextField.text = "x: \(Int(anchor.position.x))"
            yTextField.text = "y: \(Int(anchor.position.y))"
        } else {
            idTextField.placeholder = "ID:"
            xTextField.placeholder = "x:"
            yTextField.placeholder = "y:"
        }
        
        xTextField.keyboardType = .numberPad
        yTextField.keyboardType = .numberPad
        
        contentView.addSubview(idTextField)
        contentView.addSubview(xTextField)
        contentView.addSubview(yTextField)
        
        let buttonSize: CGFloat = 25
        button = UIButton(frame: CGRect(x: contentView.frame.width - buttonSize - 10, y: (contentView.frame.height - buttonSize) / 2, width: buttonSize, height: buttonSize))
        if anchor != nil {
            button.setImage(UIImage(named: "trashIcon"), for: .normal)
            button.addTarget(self, action: #selector(onRemoveAnchorButtonTapped(_:)), for: .touchUpInside)
        } else {
            button.setImage(UIImage(named: "addIcon"), for: .normal)
            button.addTarget(self, action: #selector(onAddAnchorButtonTapped(_:)), for: .touchUpInside)
        }
        contentView.addSubview(button)
    }
    
    func onAddAnchorButtonTapped(_ sender: UIButton) {
        guard let id = Int(idTextField.text!, radix: 16), let x = Int(xTextField.text!), let y = Int(yTextField.text!) else { return }
        delegate?.onAddAnchorButtonTapped(sender, id: id, x: x, y: y)
    }
    
    func onRemoveAnchorButtonTapped(_ sender: UIButton) {
        guard let id = Int(idTextField.text!, radix: 16) else { return }
        delegate?.onRemoveAnchorButtonTapped(sender, id: id)
    }
}

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
    
    func onEditTextField(_ sender: UITextField)
}

class AnchorTableViewCell: UITableViewCell, UITextFieldDelegate {
    
    weak var delegate: AnchorTableViewCellDelegate?
    
    var idTextField: UITextField?
    var xTextField: UITextField?
    var yTextField: UITextField?
    
    var addButton: UIButton?
    
    //MARK: Public API
    func setupWithID(_ id: Int, x: Int, y: Int, delegate: AnchorTableViewCellDelegate) {
        
        for subview in contentView.subviews {
            subview.removeFromSuperview()
        }
        
        self.delegate = delegate
                
        idTextField = UITextField(frame: CGRect(x: 20, y: 0, width: 40, height: frame.height))
        xTextField = UITextField(frame: CGRect(x: 65, y: 0, width: 55, height: frame.height))
        yTextField = UITextField(frame: CGRect(x: 125, y: 0, width: 55, height: frame.height))
        
        guard let idTextField = idTextField, let xTextField = xTextField, let yTextField = yTextField else { return }
        
        idTextField.delegate = self
        xTextField.delegate = self
        yTextField.delegate = self
        
        idTextField.font = UIFont.systemFont(ofSize: 12)
        xTextField.font = UIFont.systemFont(ofSize: 12)
        yTextField.font = UIFont.systemFont(ofSize: 12)
        
        idTextField.text = String(format:"%2X:", id)
        xTextField.text = "x: \(x)"
        yTextField.text = "y: \(y)"
        
        xTextField.keyboardType = .numberPad
        yTextField.keyboardType = .numberPad
        
        idTextField.isEnabled = false
        
        contentView.addSubview(idTextField)
        contentView.addSubview(xTextField)
        contentView.addSubview(yTextField)
    }
    
    func setupWithDelegate(_ delegate: AnchorTableViewCellDelegate) {
        
        for subview in contentView.subviews {
            subview.removeFromSuperview()
        }
        
        self.delegate = delegate
        
        idTextField = UITextField(frame: CGRect(x: 20, y: 0, width: 40, height: frame.height))
        xTextField = UITextField(frame: CGRect(x: 65, y: 0, width: 40, height: frame.height))
        yTextField = UITextField(frame: CGRect(x: 110, y: 0, width: 40, height: frame.height))
        
        guard let idTextField = idTextField, let xTextField = xTextField, let yTextField = yTextField else { return }
        
        idTextField.delegate = self
        xTextField.delegate = self
        yTextField.delegate = self
        
        idTextField.font = UIFont.systemFont(ofSize: 12)
        xTextField.font = UIFont.systemFont(ofSize: 12)
        yTextField.font = UIFont.systemFont(ofSize: 12)
        
        idTextField.placeholder = "ID: "
        xTextField.placeholder = "x: "
        yTextField.placeholder = "y: "
        
        xTextField.keyboardType = .numberPad
        yTextField.keyboardType = .numberPad
        
        contentView.addSubview(idTextField)
        contentView.addSubview(xTextField)
        contentView.addSubview(yTextField)
        
        addButton = UIButton(type: .contactAdd)
        guard let addButton = addButton else { return }
        addButton.frame = CGRect(x: frame.width - addButton.frame.width - 20, y: (frame.height - addButton.frame.height) / 2, width: addButton.frame.width, height: addButton.frame.height)
        addButton.addTarget(self, action: #selector(onAddAnchorButtonTapped(_:)), for: .touchUpInside)
        
        contentView.addSubview(addButton)
    }
    
    func onAddAnchorButtonTapped(_ sender: UIButton) {
        guard let idTextField = idTextField, let xTextField = xTextField, let yTextField = yTextField else { return }
        guard let id = Int(idTextField.text!, radix: 16), let x = Int(xTextField.text!), let y = Int(yTextField.text!) else { return }
        delegate?.onAddAnchorButtonTapped(sender, id: id, x: x, y: y)
    }
    
    //MARK: UITextFieldDelegate
    func textFieldDidEndEditing(_ textField: UITextField) {

    }
}

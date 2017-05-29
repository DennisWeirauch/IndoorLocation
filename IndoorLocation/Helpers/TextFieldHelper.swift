//
//  TextFieldHelper.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 25.05.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

class TextFieldHelper {
    
    static func setupTextField(_ textField: UITextField,
                               text: String? = nil,
                               placeholder: String? = nil,
                               keyboardType: UIKeyboardType = .default,
                               fontSize: CGFloat = 13,
                               tag: Int,
                               delegate: UITextFieldDelegate? = nil) {
        textField.text = text
        textField.placeholder = placeholder
        textField.keyboardType = keyboardType
        textField.font = UIFont.systemFont(ofSize: fontSize)
        textField.tag = tag
        textField.delegate = delegate
    }
}

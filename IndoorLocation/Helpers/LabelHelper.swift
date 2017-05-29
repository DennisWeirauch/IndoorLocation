//
//  LabelHelper.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 25.05.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

class LabelHelper {
    
    static func setupLabel(_ label: UILabel,
                           withText text: String?,
                           fontSize: CGFloat = 13,
                           textColor: UIColor = .black,
                           alignment: NSTextAlignment = .left) {
        
        label.text = text;
        label.font = UIFont.systemFont(ofSize: fontSize)
        label.textColor = textColor
        label.textAlignment = alignment
        label.adjustsFontSizeToFitWidth = true
    }
}

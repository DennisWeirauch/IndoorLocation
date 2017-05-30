//
//  ButtonHelper.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 30.05.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

class ButtonHelper {
    
    static func setupButton(_ button: UIButton,
                            text: String) {
        
        button.setTitle(text, for: .normal)
        button.setTitleColor(button.tintColor, for: .normal)
    }
}

//
//  AnchorSettingsViewController.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 03/04/2017.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

class AnchorSettingsViewController: UIViewController {

    //MARK: IBOutlets and private variables
    @IBOutlet weak var nameLabel: UILabel!
    
    @IBOutlet weak var xPositionTextfield: UITextField!
    @IBOutlet weak var yPositionTextfield: UITextField!
    
    @IBOutlet weak var distanceLabel: UILabel!
        
    var name: String?
    var point: CGPoint?
    
    //MARK: ViewController lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        self.nameLabel.text = name
        
        if let point = self.point {
            self.xPositionTextfield.text = String(describing: Int(point.x))
            self.yPositionTextfield.text = String(describing: Int(point.y))
        } else {
            self.xPositionTextfield.text = ""
            self.yPositionTextfield.text = ""
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //MARK: IBActions
    @IBAction func onCloseButtonTapped() {
        self.dismiss(animated: true, completion: nil)
    }
}

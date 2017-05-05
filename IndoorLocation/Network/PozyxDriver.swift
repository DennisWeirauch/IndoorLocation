//
//  PozyxDriver.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 12.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

typealias AnchorDict = Dictionary<String, (Double, Double)>

let CALIBRATE = "c"
let GET_POS = "p"
let ANCHORS = "a"
let REMOTE_ID = "i"
let POS_AND_ACC = "x"
let REM_POS_AND_ACC = "r"

class PozyxDriver: NSObject {
    
    //TODO: Use settings for WIFI here instead of baudRate and port
    var baudRate: Int
    var port: Int
    
    var remoteID: Int?
    
    static let sharedInstance = PozyxDriver(baudRate: 115200, port: 0)
    
    private init(baudRate: Int, port: Int, remoteID: Int? = nil) {
        self.baudRate = baudRate
        self.port = port
        self.remoteID = remoteID
    }
    
    //MARK: Private API
    func calibrate(anchorDict: AnchorDict?) -> AnchorDict? {

        if (anchorDict == nil) {
            let data = self.getData(CALIBRATE)
            
            guard let strongData = data else {
                print("Error during calibration!")
                return nil
            }
            
            let anchors = strongData.components(separatedBy: "]")
            var resultAnchorDict = AnchorDict()
            
            for anchor in anchors {
                let details = anchor.components(separatedBy: "[")
                let name = "0x\(details[0])"
                let coordinates = details[1].components(separatedBy: ",")
                
                resultAnchorDict[name] = (Double(coordinates[0])!, Double(coordinates[1])!)
            }
            return resultAnchorDict
            
        } else {
            //TODO: post manual calibration to device
            return anchorDict
        }
    }

    func getPosData() -> Dictionary<String, Int>? {
        let data = getData(GET_POS)
        
        guard let strongData = data else {
            print("Error receiving positioning data!")
            return nil
        }
        
        let measurements = strongData.components(separatedBy: ",")
        var positionDict = Dictionary<String, Int>()
        
        positionDict["x_pos"] = Int(measurements[0])!
        positionDict["y_pos"] = Int(measurements[1])!
        positionDict["x_acc"] = Int(measurements[2])!
        positionDict["y_acc"] = Int(measurements[3])!
        
        return positionDict
    }
    
    func getRangeAndAcc() -> [String]? {
        var resultData = ""
        if (remoteID == nil) {
            let data = getData(POS_AND_ACC)
            
            guard let strongData = data else {
                print("Error receiving ranging data!")
                return nil
            }
            resultData = strongData
        } else {
            let data = getData(REM_POS_AND_ACC)
            
            guard let strongData = data else {
                print("Error receiving remote ranging data!")
                return nil
            }
            resultData = strongData
        }
        return resultData.components(separatedBy: ",")
    }
    
    func setRemote(remoteID: Int) {
        
        self.remoteID = remoteID
        
        postData(command: REMOTE_ID, data: String(describing: Decimal(remoteID)))
    }
    
    //MARK: Interaction with Pozyx device
    func getData(_ command: String, text: String = "") -> String? {
        //TODO: Send command over Wifi and get return data, possibly better asynchronously
        return ""
    }
    
    func postData(command: String, data: String) {
        //TODO: Post data to Pozyx device, possibly better asynchronously
    }
}

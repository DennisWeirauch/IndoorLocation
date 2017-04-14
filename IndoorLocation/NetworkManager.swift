//
//  NetworkManager.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 14.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

class NetworkManager: NSObject, NetServiceDelegate, NetServiceBrowserDelegate {
    
    static let sharedInstance = NetworkManager()
    
    let netService = NetService(domain: "", type: "_indoorLocation._tcp", name: UIDevice.current.name, port: 1812)
    let netServiceBrowser = NetServiceBrowser()
    
    var services = [NetService]()
    var selectedService: NetService?
    
    private override init() {
        super.init()
        netService.delegate = self
        netServiceBrowser.delegate = self
    }
    
    func resume() {
        netService.publish()
        netServiceBrowser.searchForServices(ofType: "_arduino._tcp.", inDomain: "local.")
    }
    
    func pause() {
        netService.stop()
        netServiceBrowser.stop()
    }
    
    //MARK: NetServiceBrowserDelegate functions
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("Did find service \(service.type) from \(service.name)")
        if (!services.contains(service)) {
            services.append(service)
            // Automatically select first found service
            if (selectedService == nil) {
                selectedService = service
            }
        }
    }
}

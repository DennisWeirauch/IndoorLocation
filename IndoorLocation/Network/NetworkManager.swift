//
//  NetworkManager.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 14.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit
import Embassy

class NetworkManager: NSObject, NetServiceDelegate, NetServiceBrowserDelegate {
    
    static let sharedInstance = NetworkManager()
    
    let netService = NetService(domain: "", type: "_indoorLocation._tcp", name: UIDevice.current.name, port: 1812)
    let netServiceBrowser = NetServiceBrowser()
    
    var services = [NetService]()
    var selectedService: NetService?
    
    var eventLoop: SelectorEventLoop?

    private override init() {
        super.init()
        netService.delegate = self
        netServiceBrowser.delegate = self
        
        setupServer()
    }
    
    //MARK: Private API
    private func setupServer() {
        eventLoop = try! SelectorEventLoop(selector: try! SelectSelector())
        let server = DefaultHTTPServer(eventLoop: eventLoop!, interface: "::", port: 8080) {(
            environ: [String: Any],
            startResponse: ((String, [(String, String)]) -> Void),
            sendBody: ((Data) -> Void)) in
            // Start HTTP response
            startResponse("200 OK", [])
            // Send empty response
            sendBody(Data())
            // Ciao Rest Connector sends data in path, http body is not used
            let data = environ["PATH_INFO"]! as! String
            print(data)
            
            self.receivedData(data)
        }
        
        // Start HTTP server to listen on the port
        try! server.start()
        
        print("Server running")
        // Run server task in background thread
        DispatchQueue.global(qos: .background).async {
            // Run event loop
            self.eventLoop?.runForever()
        }
    }
    
    private func receivedData(_ data: String) {
        
    }
    
    //MARK: NetServiceBrowserDelegate
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        if (!services.contains(service)) {
            services.append(service)
            // Automatically select first found service
            if (selectedService == nil) {
                selectedService = service
            }
        }
    }
    
    //MARK: Public API
    func resume() {
        //TODO: Start server here
        netService.publish()
        netServiceBrowser.searchForServices(ofType: "_arduino._tcp.", inDomain: "local.")
    }
    
    func pause() {
        //TODO: Pause Server here
        netService.stop()
        netServiceBrowser.stop()
    }
    
    func calibratePozyx(resultCallback: @escaping (Data?) -> Void) {
        let url = URL(string: "http://192.168.1.111:8080/arduino/calibrate")
        let task = URLSession.shared.dataTask(with: url!) { data, response, error in
            guard error == nil else {
                print(error!)
                return
            }
            guard let data = data else {
                print("Data is empty")
                return
            }
            resultCallback(data)
        }
        task.resume()
    }
}

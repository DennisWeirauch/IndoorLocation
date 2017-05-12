//
//  NetworkManager.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 14.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit
import Embassy

enum TaskType : String {
    case beginRanging = "r"
    case stopRanging = "s"
    case calibrate = "c"
    case setAnchors = "a"
}

class NetworkManager: NSObject, NetServiceDelegate, NetServiceBrowserDelegate {
    
    static let shared = NetworkManager()
    
//    let netService = NetService(domain: "", type: "_indoorLocation._tcp", name: UIDevice.current.name, port: 1812)
//    let netServiceBrowser = NetServiceBrowser()
    
    var services = [NetService]()
    var selectedService: NetService?
    
    private override init() {
        super.init()
//        netService.delegate = self
//        netServiceBrowser.delegate = self
        
        setupServer()
    }
    
    //MARK: Private API
    private func setupServer() {
        let eventLoop = try! SelectorEventLoop(selector: try! KqueueSelector())
        let server = DefaultHTTPServer(eventLoop: eventLoop, interface: "::", port: 8080) {(
            environ: [String: Any],
            startResponse: ((String, [(String, String)]) -> Void),
            sendBody: ((Data) -> Void)) in
            // Start HTTP response
            startResponse("200 OK", [])
            // Send empty response
            sendBody(Data())
            // Ciao Rest Connector sends data in path, http body is not used
            let data = environ["PATH_INFO"]! as! String
            
            self.receivedData(data)
        }
        
        // Run server task in background thread
        DispatchQueue.global(qos: .background).async {
            // Start HTTP server to listen on the port
            try! server.start()
            
            print("Server running")
            // Run event loop
            eventLoop.runForever()
        }
    }
    
    private func receivedData(_ data: String) {
        print(data)
    }
    
    /*
    //MARK: NetServiceBrowserDelegate
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        print("Found \(service.name)")
        service.delegate = self
        service.resolve(withTimeout: 10)
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        if (sender != netService) {
            if (!services.contains(sender)) {
                services.append(sender)
                // Automatically select first found service
                if (selectedService == nil) {
                    selectedService = sender
                }
            }
//            let addresses = sender.addresses!.flatMap { getIFAddress($0) }
        }
    }
    
    func netServiceDidStop(_ sender: NetService) {
        print("Stopped \(sender.name)")
    }
    
    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        print(sender)
        print(errorDict)
    }
    */
    //MARK: Public API
    /*
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
    */
    
    func pozyxTask(task: TaskType, data: String = "", resultCallback: @escaping (Data?) -> Void) {
        var urlString = "http://"
        if let service = selectedService {
            urlString.append(service.name + ".local")
            //TODO: Resolve IP of Arduino's service and use it for url. Should not need ATS permission that way
//            urlString.append(getIFAddress((service.addresses?.first)!)!)
        } else {
            urlString.append("192.168.1.111")
        }
        urlString.append(":8080/arduino/")
        var txData = data
        if task == .beginRanging {
            //TODO: Get IP of device
            txData = "192.168.1.60"
        }
        let url = URL(string: urlString + task.rawValue + "/" + txData)
        let task = URLSession.shared.dataTask(with: url!) { data, response, error in
            guard error == nil else {
                print(error!)
                return
            }
            resultCallback(data)
        }
        task.resume()
    }
}

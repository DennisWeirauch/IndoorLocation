//
//  NetworkManager.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 14.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import Embassy

enum TaskType : String {
    case beginRanging = "r"
    case stopRanging = "s"
    case calibrate = "c"
}

enum NetworkResult {
    case success(Data?)
    case failure(Error)
}

/**
 Class to handle communication with the Arduino. It automatically determines the Arduino's IP address using Bonjour, sets up a server on the iOS device
 for receiving measurement data from the Arduino and implements functions to control the Arduino.
 */
class NetworkManager: NSObject, NetServiceDelegate, NetServiceBrowserDelegate {
    
    static let shared = NetworkManager()
    
    let netService = NetService(domain: "", type: "_indoorLocation._tcp", name: UIDevice.current.name, port: 1812)
    let netServiceBrowser = NetServiceBrowser()
    
    var selectedService: NetService?

    let port = 8080
    let hostIP = "172.20.10.1"
    var arduinoIP: String?
    
    let session: URLSession

    private override init() {
        // Set timeout for requests to Arduino to 10 s
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        session = URLSession(configuration: config)
        
        super.init()

        netService.delegate = self
        netServiceBrowser.delegate = self
        
        setupServer()
        
        netService.publish()
        netServiceBrowser.searchForServices(ofType: "_arduino._tcp.", inDomain: "local.")
    }
    
    //MARK: Private API
    /**
     Set up server with Embassy framework to receive measurement data from the Arduino.
     */
    private func setupServer() {
        let eventLoop = try! SelectorEventLoop(selector: try! KqueueSelector())
        let server = DefaultHTTPServer(eventLoop: eventLoop, interface: "::", port: port) {(
            environ: [String: Any],
            startResponse: ((String, [(String, String)]) -> Void),
            sendBody: ((Data) -> Void)) in
            // Start HTTP response
            startResponse("200 OK", [])
            // Send empty response
            sendBody(Data())
            // Ciao Rest Connector sends data in path, http body is not used, therefore data is taken from path info
            let data = environ["PATH_INFO"]! as? String
            
            // Forward received data to IndoorLocationManager on main thread
            DispatchQueue.main.async {
                IndoorLocationManager.shared.newRangingData(data)
            }
        }
        
        // Run server task in background thread
        DispatchQueue.global(qos: .background).async {
            // Start HTTP server to listen on the port
            try! server.start()
            
            // Run event loop
            eventLoop.runForever()
        }
    }

    /**
     Get the local ip address from a Data object.
     - Parameter data: Address data
     - Returns: The ip address as String
     */
    private func getIFAddress(_ data : Data) -> String? {
        
        let hostname = UnsafeMutablePointer<Int8>.allocate(capacity: Int(INET6_ADDRSTRLEN))
        
        getnameinfo((data as NSData).bytes.bindMemory(to: sockaddr.self, capacity: data.count), socklen_t(data.count), hostname, socklen_t(INET6_ADDRSTRLEN), nil, 0, NI_NUMERICHOST)
        
        let string = String(cString: hostname)
        
        // Discard link local addresses
        if string.hasPrefix("fe80:") || string.hasPrefix("127.") {
            return nil
        }
        
        hostname.deinitialize()
        return string
    }
    
    //MARK: Public API
    /**
     This function is used to send tasks to the Arduino.
     - Parameter task: The task to perform on the Arduino
     - Parameter data: Optional data to send to the Arduino, i.e. calibration data
     - Parameter resultCallback: A closure which is executed after receiving a response from the Arduino
     - Parameter result: The result of the task
     */
    func pozyxTask(task: TaskType, data: String = "", resultCallback: @escaping (_ result: NetworkResult) -> Void) {
        // Check if IP of Arduino has been determined successfully
        if let arduinoIP = arduinoIP {
            let urlString = "http://\(arduinoIP):\(port)/arduino/"
            
            var txData = data
            if task == .beginRanging {
                txData = "\(hostIP):\(port)"
            }
            
            let url = URL(string: urlString + task.rawValue + "/" + txData)!
            let dataTask = session.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        resultCallback(.failure(error))
                    } else {
                        resultCallback(.success(data))
                    }
                }
            }
            dataTask.resume()
        } else {
            // Search for Arduino again
            netServiceBrowser.searchForServices(ofType: "_arduino._tcp.", inDomain: "local.")
            
            let error = NSError(domain: "Error", code: 0, userInfo: [NSLocalizedDescriptionKey : "Arduino could not be found. Make sure it is connected to this device's Wifi hotspot and try again."])
            resultCallback(.failure(error))
        }
    }
    
    //MARK: NetServiceBrowserDelegate
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        if selectedService == nil {
            selectedService = service
            selectedService?.delegate = self
            selectedService?.resolve(withTimeout: 10)
        }
    }
    
    //MARK: NetServiceDelegate
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let addresses = sender.addresses else { return }
        
        let ifAddresses = addresses.flatMap({getIFAddress($0)})
        
        arduinoIP = ifAddresses.first
    }
}

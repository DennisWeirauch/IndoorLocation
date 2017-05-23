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
    case setAnchors = "a"
}

class NetworkManager {
    
    static let shared = NetworkManager()

    let port = 8080
    let hostIP = "172.20.10.1"
    // TODO: Check if hardcoding IP is a good solution here
    let arduinoIP = "172.20.10.4"

    private init() {
        setupServer()
    }
    
    //MARK: Private API
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
            // Ciao Rest Connector sends data in path, http body is not used
            let data = environ["PATH_INFO"]! as? String
            
            DispatchQueue.main.async {
                self.receivedData(data)
            }
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
    
    private func receivedData(_ data: String?) {
        IndoorLocationManager.shared.newData(data)
    }

    //MARK: Public API
    func pozyxTask(task: TaskType, data: String = "", resultCallback: @escaping (Data?) -> Void) {
        let urlString = "http://\(arduinoIP):\(port)/arduino/"
        
        var txData = data
        if task == .beginRanging {
            txData = "\(hostIP):\(port)"
        }
        
        let url = URL(string: urlString + task.rawValue + "/" + txData)
        let task = URLSession.shared.dataTask(with: url!) { data, response, error in
            guard error == nil else {
                print(error!)
                return
            }
            DispatchQueue.main.async {
                resultCallback(data)
            }
        }
        task.resume()
    }
}

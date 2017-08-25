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

class NetworkManager {
    
    static let shared = NetworkManager()

    let port = 8080
    let hostIP = "172.20.10.1"
    // TODO: Add custom ping mechanism to get arduino's IP. (Send message to broadcast address (172.20.10.15) and let arduino respond.)
    let arduinoIP = "172.20.10.4"
    let session: URLSession

    private init() {
        // Set timeout for requests to Arduino to 10 s
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        session = URLSession(configuration: config)
        
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
            
            // Run event loop
            eventLoop.runForever()
        }
    }
    
    private func receivedData(_ data: String?) {
        IndoorLocationManager.shared.newRangingData(data)
    }

    //MARK: Public API
    func pozyxTask(task: TaskType, data: String = "", resultCallback: @escaping (NetworkResult) -> Void) {
        let urlString = "http://\(arduinoIP):\(port)/arduino/"
        
        var txData = data
        if task == .beginRanging {
            txData = "\(hostIP):\(port)"
        }
        
        let url = URL(string: urlString + task.rawValue + "/" + txData)
        let dataTask = session.dataTask(with: url!) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    resultCallback(.failure(error))
                } else {
                    resultCallback(.success(data))
                }
            }
        }
        dataTask.resume()
    }
}

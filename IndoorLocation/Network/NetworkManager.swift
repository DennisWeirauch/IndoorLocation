//
//  NetworkManager.swift
//  IndoorLocation
//
//  Created by Dennis Hirschgänger on 14.04.17.
//  Copyright © 2017 Hirschgaenger. All rights reserved.
//

import UIKit

class NetworkManager: NSObject, NetServiceDelegate, NetServiceBrowserDelegate, StreamDelegate {
    
    static let sharedInstance = NetworkManager()
    
    let netService = NetService(domain: "", type: "_indoorLocation._tcp", name: UIDevice.current.name, port: 1812)
    let netServiceBrowser = NetServiceBrowser()
    
    var services = [NetService]()
    var selectedService: NetService?
    
    var inputStream: InputStream?
    var outputStream: OutputStream?
    
    var successfullySentData = false
    
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
    
    func setupStream() {
        
        successfullySentData = false

        guard let service = selectedService else {
            print("Failure in setting up stream: No Service selected!")
            return
        }
        
        if service.getInputStream(&inputStream, outputStream: &outputStream) {
            guard let strongInputStream = inputStream, let strongOutputStream = outputStream else {
                print("Failure in setting up stream: Could not get streams!")
                return
            }
            strongInputStream.delegate = self
            strongOutputStream.delegate = self
            
            strongInputStream.schedule(in: .current, forMode: .defaultRunLoopMode)
            strongOutputStream.schedule(in: .current, forMode: .defaultRunLoopMode)
            
            strongInputStream.open()
            strongOutputStream.open()
        }
 
//        selectedService?.delegate = self
//        selectedService?.resolve(withTimeout: 10)
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
    /*
    //MARK: NetServiceDelegate
    func netServiceDidResolveAddress(_ sender: NetService) {
        print("Did resolve address for \(sender)")
        let name = sender.name
        let type = sender.type + sender.domain
        let addresses = sender.addresses!.flatMap({getIFAddress($0)})
        let port = sender.port
        
        var txtData = [[String]]()
        if let txtRecord = sender.txtRecordData() {
            for (key, value) in NetService.dictionary(fromTXTRecord: txtRecord) {
                txtData.append([key, String(data: value, encoding: String.Encoding.utf8)!])
            }
        }
        print("Name: \(name)")
        print("Type: \(type)")
        print("Addresses: \(addresses)")
        print("Port: \(port)")
        
        print(txtData)
    }
    
    // Get the local ip addresses used by this node
    func getIFAddress(_ data : Data) -> String? {
        
        //let hostname = [CChar](count: Int(INET6_ADDRSTRLEN), repeatedValue: 0)
        let hostname = UnsafeMutablePointer<Int8>.allocate(capacity: Int(INET6_ADDRSTRLEN))
        
        var _ = getnameinfo(
            (data as NSData).bytes.bindMemory(to: sockaddr.self, capacity: data.count), socklen_t(data.count),
            hostname, socklen_t(INET6_ADDRSTRLEN),
            nil, 0,
            NI_NUMERICHOST)
        
        let string = String(cString: hostname)
        
        // link local addresses don't cound
        if string.hasPrefix("fe80:") || string.hasPrefix("127.") {
            return nil
        }
        
        hostname.deinitialize()
        return string
    }
    */
    
    //MARK: StreamDelegate
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch (eventCode){
            
        case Stream.Event.errorOccurred:
            print("ErrorOccurred")
            break
            
        case Stream.Event.endEncountered:
            print("EndEncountered")
            break

        case Stream.Event.hasBytesAvailable:
            print("HasBytesAvaible")
            
            var buffer = [UInt8](repeating: 0, count: 4096)
            
            if (aStream == inputStream) {
                
                guard let strongInputStream = inputStream else { return }
                
                while (strongInputStream.hasBytesAvailable){
                    let len = strongInputStream.read(&buffer, maxLength: buffer.count)
                    print(len)
                    if (len > 0) {
                        let output = NSString(bytes: &buffer, length: len, encoding: String.Encoding.utf8.rawValue)
                        if (output != ""){
                            print("Server response: %@", output!)
                        }
                    }
                }
            }

        case Stream.Event.openCompleted:
            print("OpenCompleted")
            
        case Stream.Event.hasSpaceAvailable:
            print("HasSpaceAvailable")
            
            if (aStream == outputStream) {
                guard let strongOutputStream = outputStream else { return }
                
                if (!successfullySentData) {
                    let message = "Ich baller jetzt mal mega viele Daten rein!"
                    let buffer = [UInt8](message.utf8)
                    
                    let len = strongOutputStream.write(buffer, maxLength: buffer.count)
                    if (len > 0) {
                        print("Successfully sent \(len) byte(s) to stream")
                        successfullySentData = true

                    } else {
                        print("Error sending data!")
                    }
                }
            }
            
        default:
            print("Default case")

        break
        }
    }
}

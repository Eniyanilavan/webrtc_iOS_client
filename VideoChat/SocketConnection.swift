//
//  SocketConnection.swift
//  VideoChat
//
//  Created by Eniyanilavan Ravisankar on 24/01/20.
//  Copyright © 2020 Eniyanilavan Ravisankar. All rights reserved.
//

import UIKit
import Starscream
import WebRTC

class SocketConnection: NSObject, WebSocketDelegate {
    
    var socket: WebSocket = WebSocket(request: URLRequest(url: URL(string: "wss://77485217.ngrok.io")!))
    var webRTCClient: WebRTCClient!
    var isConnected: Bool = false
    var onConnect: (()->Void)!
    
    init(client: WebRTCClient, onConnect: @escaping ()->Void) {
        super.init()
        self.webRTCClient = client
        self.webRTCClient.socket = self
        self.onConnect = onConnect
        socket.delegate = self
        socket.connect()
    }
    
    static func toJsonString(data:[String: Any])-> String{
        var jsonData: Data?
        do{
            jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
        }
        catch let err{
            print("json parse error", err.localizedDescription)
        }
        if(jsonData != nil){
            return String(data: jsonData!, encoding: .ascii)!
        }
        else{
            return ""
        }
    }
    
    static func parseJson(data: String)->[String: Any]{
        var jsonData: [String:Any] = [:]
        do{
            let string = data.data(using: .ascii)
            jsonData = try JSONSerialization.jsonObject(with: string!, options: []) as! [String : Any]
        }
        catch let err{
            print("json parse error", err.localizedDescription)
        }
        return jsonData
    }
    
    func send(data: String, completion: (()->Void)?){
        socket.write(string: data, completion: completion)
    }
    
    func newCandidate(){
        print("new candidate")
        let payload = ["event": "newCandidate", "payload":[
            "roomID": webRTCClient.roomID,
        ]] as [String : Any]
        let data = SocketConnection.toJsonString(data: payload)
        socket.write(string: data, completion: nil)
    }
    
    func success(payload: [String: Any]){
        print(payload["iceServers"] as Any)
        webRTCClient.success(payload: payload)
        if((payload["isCaller"] as? Bool ?? false)){
            webRTCClient.isHost = true
        }
        else{
            newCandidate()
        }
    }
    
    func createOffer(roomID: String){
        webRTCClient.createOffer(roomID: roomID)
    }
    
    func createAnswer(payload: [String: Any]){
        webRTCClient.createAnswer(payload: payload)
    }
    
    func acceptAnswer(payload: [String: Any]){
        webRTCClient.acceptAnswer(payload: payload)
    }
    
    func emit(event: String, payload: [String: Any]){
        
        switch event {
        case "success":
            success(payload: payload)
        case "createOffer":
            if(webRTCClient.isHost){
                createOffer(roomID: payload["roomID"] as! String)
            }
        case "offer":
            if(!webRTCClient.isHost){
                createAnswer(payload: payload)
            }
        case "answer":
            if(webRTCClient.isHost){
                acceptAnswer(payload: payload)
            }
        case "candidate":
            print("iceCandidate from ws")
            let cand = payload["candidate"] as! [String: Any]
            let iceCan = RTCIceCandidate(sdp: cand["candidate"] as! String, sdpMLineIndex: cand["sdpMLineIndex"] as? Int32 ?? 0, sdpMid: cand["sdpMid"] as? String ?? "")
            webRTCClient.peerConnection.add(iceCan)
        default:
            print("no event", event, payload)
        }
        
    }
    
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
            
        case .connected(_):
            isConnected = true
            print("websocket is connected:")
            self.onConnect()
            let register = SocketConnection.toJsonString(data: ["event": "register", "payload": [:]])
            client.write(string: register, completion: nil)
            
        case .disconnected(let reason, let code):
            isConnected = false
            print("websocket is disconnected: \(reason) with code: \(code)")
            
        case .text(let string):
            let json = SocketConnection.parseJson(data: string)
            emit(event: json["event"] as! String, payload: json["payload"] as! [String : Any])
            
        case .binary(let data):
            print("Received data: \(data.count)")
            
        case .ping(_):
            break
            
        case .pong(_):
            break
            
        case .viablityChanged(_):
            break
            
        case .reconnectSuggested(_):
            break
            
        case .cancelled:
            isConnected = false
            
        case .error(let error):
            isConnected = false
            print("error", error?.localizedDescription ?? "")
        }
    }
    

}

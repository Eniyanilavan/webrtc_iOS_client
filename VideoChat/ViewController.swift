//
//  ViewController.swift
//  VideoChat
//
//  Created by Eniyanilavan Ravisankar on 07/01/20.
//  Copyright © 2020 Eniyanilavan Ravisankar. All rights reserved.
//

import UIKit
import WebRTC
import Starscream
import AVKit

class ViewController: UIViewController {
    

    @IBOutlet weak var roomText: UITextField!
    @IBOutlet weak var joinButton: UIButton!
    @IBOutlet weak var localView: RTCEAGLVideoView!
    @IBOutlet weak var remoteView: RTCEAGLVideoView!
    
    var webRTCClient: WebRTCClient!
    var socket: SocketConnection!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        localView.contentMode = .scaleAspectFit
        remoteView.contentMode = .scaleAspectFill
        webRTCClient = WebRTCClient(remoteView: &remoteView, localView: &localView)
        socket = SocketConnection(client: webRTCClient, onConnect: self.onConnect)
    }
    
    func onConnect(){
        joinButton.isEnabled = true
    }
    
    @IBAction func join(_ sender: Any) {
        roomText.resignFirstResponder()
        if((roomText.text) != nil && !(roomText.text?.isEmpty ?? true)){
            webRTCClient.roomID = roomText.text
            let join = SocketConnection.toJsonString(data: ["event": "hostOrJoin", "payload": ["callID": webRTCClient.roomID]])
            socket.send(data: join, completion: nil)
        }
        else{
            let uialert = UIAlertAction(title: "ok", style: .default) { (action) in
                
            }
            
            let alertVC = UIAlertController(title: "Opps!", message: "Enter a room number", preferredStyle: .alert)
            alertVC.addAction(uialert)
            
            self.present(alertVC, animated: true, completion: nil)
        }
    }
    
}


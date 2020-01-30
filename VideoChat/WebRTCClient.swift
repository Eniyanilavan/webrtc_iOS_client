//
//  WebRTCClient.swift
//  VideoChat
//
//  Created by Eniyanilavan Ravisankar on 24/01/20.
//  Copyright © 2020 Eniyanilavan Ravisankar. All rights reserved.
//

import UIKit
import WebRTC

class WebRTCClient: NSObject, RTCPeerConnectionDelegate {
    
    var isHost = false
    
    var socket: SocketConnection!
    
    var localView: RTCEAGLVideoView!
    var localStream: RTCMediaStream!
    var localCapturer: RTCCameraVideoCapturer!
    var localVideoSource: RTCVideoSource!
    
    var remoteView: RTCEAGLVideoView!
    var remoteStream: RTCMediaStream!
    var remoteCapturer: RTCCameraVideoCapturer!
    var remoteVideoSource: RTCVideoSource!
    
    var roomID: String!
    var participantID: Int!
    var peerConnectionFactory: RTCPeerConnectionFactory = RTCPeerConnectionFactory()
    var peerConnection: RTCPeerConnection!
    var peerConnections: [Int : RTCPeerConnection]!
    
    init(remoteView: inout RTCEAGLVideoView, localView: inout RTCEAGLVideoView) {
        super.init()
        self.remoteView = remoteView
        self.localView = localView
    }
    
    func mediaConstrains()->RTCMediaConstraints{
        return RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio": "true", "OfferToReceiveVideo": "true"], optionalConstraints: nil)
    }
    
    func config(iceServers: [[String: Any]])-> RTCConfiguration{
        let conf = RTCConfiguration()
        for iceServer in iceServers {
            conf.iceServers.append(RTCIceServer(urlStrings: iceServer["urls"] as! [String], username: (iceServer["username"] as? String ?? ""), credential: (iceServer["credential"] as? String ?? "")))
        }
        return conf
    }
    
    func success(payload: [String: Any]){
        self.participantID = payload["participantID"] as? Int ?? 0
        peerConnection = peerConnectionFactory.peerConnection(with: config(iceServers: ((payload["iceServers"] as! [String: Any])["iceServers"]) as! [[String : Any]]), constraints: mediaConstrains(), delegate: self)
        localStream = peerConnectionFactory.mediaStream(withStreamId: "local")
        let audioTrack = peerConnectionFactory.audioTrack(withTrackId: "localAudio")
        localStream.addAudioTrack(audioTrack)
        localVideoSource = peerConnectionFactory.videoSource()
        localCapturer = RTCCameraVideoCapturer(delegate: localVideoSource)
        guard let frontCamera = (RTCCameraVideoCapturer.captureDevices().first{$0.position == .front}), let format = (RTCCameraVideoCapturer.supportedFormats(for: frontCamera).sorted { (f1, f2) -> Bool in
                let width1 = CMVideoFormatDescriptionGetDimensions(f1.formatDescription).width
                let width2 = CMVideoFormatDescriptionGetDimensions(f2.formatDescription).width
                return width1 < width2
            }).last,
            let fps = (format.videoSupportedFrameRateRanges.sorted { return $0.maxFrameRate < $1.maxFrameRate }.last) else {
                return
        }
        localCapturer.startCapture(with: frontCamera, format: format, fps: Int(fps.maxFrameRate))
        let videoTrack = peerConnectionFactory.videoTrack(with: localVideoSource, trackId: "localVideo")
        localCapturer.captureSession.startRunning()
        localStream.addVideoTrack(videoTrack)
        videoTrack.add(localView)
        
    }
    
    func addLocalStream(){
        peerConnection.add(localStream.videoTracks[0], streamIds: ["stream"])
        peerConnection.add(localStream.audioTracks[0], streamIds: ["stream"])
    }
    
    func createOffer(roomID: String){
        print("create offer")
        addLocalStream()
        peerConnection.offer(for: mediaConstrains()) { (sessDes, err) in
            guard let sessionDescription = sessDes else{
                print("could not create offer ", err?.localizedDescription ?? "")
                return
            }
            let payload = SocketConnection.toJsonString(data: ["event": "offer", "payload":[
                "roomID": self.roomID!,
                "sessDes": ["type": "offer", "sdp": sessionDescription.sdp]
            ]])
            self.peerConnection.setLocalDescription(sessionDescription) { (err) in
                if(err != nil){
                    print("could not set offer in local description")
                }
            }
            self.socket.send(data: payload, completion: nil)
        }
    }
    
    func createAnswer(payload: [String: Any]){
        print("create answer")
        addLocalStream()
        peerConnection.setRemoteDescription(RTCSessionDescription(type: .offer, sdp: (payload["sessDes"] as! [String: String])["sdp"]!), completionHandler: {
            (err) in
            if(err != nil){
                print("could not set offer in remote description ", err!.localizedDescription)
            }
        })
        peerConnection.answer(for: mediaConstrains()) { (sessDess, err) in
            guard let sessionDescription = sessDess else{
                print("could not create answer ", err?.localizedDescription ?? "")
                return
            }
            let payload = SocketConnection.toJsonString(data: ["event": "answer", "payload":[
                "roomID": self.roomID!,
                "sessDes": ["type": "answer", "sdp": sessionDescription.sdp]
            ]])
            self.peerConnection.setLocalDescription(sessionDescription) { (err) in
                if(err != nil){
                    print("could not set answer in local description")
                }
            }
            self.socket.send(data: payload, completion: nil)
        }
        
    }
    
    func acceptAnswer(payload: [String: Any]){
        print("answer", payload)
        peerConnection.setRemoteDescription(RTCSessionDescription(type: .answer, sdp: (payload["sessDes"] as! [String: String])["sdp"]!), completionHandler: {
            (err) in
            if(err != nil){
                print("could not set answer in remote description ", err!.localizedDescription)
            }
        })
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("change state closed", stateChanged == .closed)
        print("change state haveLocalOffer", stateChanged == .haveLocalOffer)
        print("change state haveLocalPrAnswer", stateChanged == .haveLocalPrAnswer)
        print("change state haveRemoteOffer", stateChanged == .haveRemoteOffer)
        print("change state haveRemotePrAnswer", stateChanged == .haveRemotePrAnswer)
        print("change state stable", stateChanged == .stable)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        remoteStream = stream
//        remoteStream.addAudioTrack(remoteStream.audioTracks[0])
//        remoteStream.addVideoTrack(remoteStream.videoTracks[0])
        remoteStream.videoTracks[0].add(remoteView)
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        let payload = SocketConnection.toJsonString(data: ["event": "candidate", "payload":[
            "candidate": ["candidate": candidate.sdp, "sdpMid": candidate.sdpMid ?? "", "sdpMLineIndex": candidate.sdpMLineIndex],
            "roomID": self.roomID ?? ""
        ]])
        self.socket.send(data: payload, completion: nil)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        
    }
    
    func videoView(_ videoView: RTCVideoRenderer, didChangeVideoSize size: CGSize) {
        
    }

}

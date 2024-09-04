//
//  CallController.swift
//  QboxCallSDK
//
//  Created by Tileubergenov Nurken on 02.09.2024.
//

import WebRTC

protocol CallControllerDelegate: AnyObject {
  
}


class CallController {
  let moduleName = "CallController"
  
  weak var delegate: CallControllerDelegate?
  private let iceServers = [RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])]
  private var socket: SocketProvider?
  private var rtc: RTCClient?
  private var token: String?
  private var url: String
  
  public required init(url socketUrl: String) {
    url = socketUrl
  }
  
  func startCall(token socketToken: String? = nil) -> Bool {
    if socketToken != nil { token = socketToken }
    
    setSocket()
    guard let socket = socket else { return false }
    
    setRTC()
    guard let _ = rtc?.connection else { return false }
    
    socket.connect()
    
    return true
  }
  
  private func setRTC() {
    rtc = RTCClient(iceServers: iceServers)
    rtc?.delegate = self
    QBoxLog.debug(moduleName, "setRTC() -> done")
  }
  
  private func setSocket() {
    guard let token = token else {
      QBoxLog.error(moduleName, "startCall() -> token is nil")
      return
    }
    
    let url = url + "/websocket?token=" + token
    
    if #available(iOS 19.0, *) {
      QBoxLog.debug(moduleName, "setSocket() -> using NativeSocket")
      socket = NativeSocket(url: url)
    } else {
      QBoxLog.debug(moduleName, "setSocket() -> using StarscreamSocket")
      socket = StarscreamSocket(url: url)
    }
    socket?.delegate = self
    
    QBoxLog.debug(moduleName, "setSocket() -> done")
  }
}
// MARK: - Control methods
extension CallController{
  public func setAudioInput(isEnabled: Bool) {
    rtc?.setAudioInput(isEnabled)
  }
  
  public func setAudioOutput(isEnabled: Bool) {
    rtc?.setAudioOutput(isEnabled)
  }
  
  public func setSpeaker(isEnabled: Bool) {
    rtc?.setSpeaker(isEnabled)
  }
  
  public func sendDTMF(digit: String) {
    QBoxLog.debug(moduleName, "socket.send() -> event: dtmf, digit: \(digit)")
    socket?.send([
      "event": "dtmf",
      "dtmf": ["digit": digit]
    ])
  }
}
// MARK: - Socket Delegate
extension CallController: SocketProviderDelegate {
  func socketDidChange(state: SocketState) {
    switch state {
    case .Connected:
      rtc?.offer {
        [weak self] sessionDescription in
        guard let self else { return }
        DispatchQueue.main.async {
          QBoxLog.debug("CallController", "socket.send() -> event: call (with sessionDescription)")
        }
        socket?.send([
          "event": "call",
          "call": ["sdp": [
            "sdp": sessionDescription.sdp,
            "type": stringifySDPType(sessionDescription.type)
          ]]
        ])
      }
      
    case .Disconnected:
      break
    case .None:
      break
    }
  }
  
  func socketDidRecieve(data: [String : Any]) {
    DispatchQueue.main.async {
      [weak self] in
      guard let self else { return }
      
      let event = data["event"] as? String
      switch event {
      case "answer":
        guard
          let answer = data["answer"] as? [String: Any],
          let sdpData = answer["sdp"] as? [String: Any],
          let sdp = sdpData["sdp"] as? String
        else { return }
        
        let remote = RTCSessionDescription(type: .answer, sdp: sdp)
        QBoxLog.debug(moduleName, "socketDidRecieve() -> Answer")
        rtc?.set(remoteSdp: remote)
        
      case "candidate":
        guard
          let candidateData = data["candidate"] as? [String: Any]
        else { return }
        
        let sdpCandidate = candidateData["candidate"] as? String ?? ""
        let sdpMid = candidateData["sdpMid"] as? String ?? nil
        let LineIndex = candidateData["sdpMLineIndex"] as? Int ?? 0
        let candidate = RTCIceCandidate(sdp: sdpCandidate, sdpMLineIndex: Int32(LineIndex), sdpMid: sdpMid)
        QBoxLog.debug(moduleName, "socketDidRecieve() -> Candidate: \(sdpCandidate)")
        rtc?.set(remoteCandidate: candidate)
        
      case "hangup":
        QBoxLog.debug(moduleName, "socketDidRecieve() -> Hangup")
        //      rtc.close()
        socket?.disconnect()
        
      default:
        break
      }
    }
  }
}
// MARK: - RTCClient Delegate
extension CallController: RTCClientDelegate {
  func rtcClient(didDiscover localCandidate: RTCIceCandidate) {
    let data: [String: Any] = [
      "candidate": localCandidate.sdp,
      "sdpMid": localCandidate.sdpMid ?? "0",
      "sdpMLineIndex": Int(localCandidate.sdpMLineIndex)
    ]
    QBoxLog.debug(moduleName, "socket.send() -> event: candidate")
    socket?.send([
      "event": "candidate",
      "candidate": data
    ])
  }
  
  func rtcClient(didAdd stream: RTCMediaStream) {
  }
  
  func rtcClient(didChange state: RTCIceConnectionState) {
  }
}

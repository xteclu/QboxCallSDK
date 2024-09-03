//
//  RTCClient.swift
//  QboxCallSDK
//
//  Created by Tileubergenov Nurken on 02.09.2024.
//

import Foundation
import WebRTC

func stringifySDPType(_ sdpType: RTCSdpType) -> String {
  switch sdpType {
  case .offer:    return "offer"
  case .answer:   return "answer"
  case .prAnswer: return "prAnswer"
    //  case .rollback: return "rollback"
  @unknown default:
    return "unknown"
  }
}

protocol RTCClientDelegate: AnyObject {
  func rtcClient(didDiscover localCandidate: RTCIceCandidate)
  func rtcClient(didAdd stream: RTCMediaStream)
  func rtcClient(didChange state: RTCIceConnectionState)
}

final class RTCClient: NSObject {
  private let moduleName = "RTCClient"
  private let factory: RTCPeerConnectionFactory
  
  weak var delegate: RTCClientDelegate?
  
  var connection: RTCPeerConnection?
  private var audioSession: AudioSession?
  
  @available(*, unavailable)
  override init() {
    fatalError("RTCClient.init() is unavailable")
  }
  
  required init(iceServers: [RTCIceServer]) {
    RTCInitializeSSL()
    
    factory = RTCPeerConnectionFactory(
      encoderFactory: RTCDefaultVideoEncoderFactory(),
      decoderFactory: RTCDefaultVideoDecoderFactory()
    )
    super.init()
    audioSession = AudioSession()

    connection = setPeerConnection(with: iceServers)
    
    createMediaSenders()
    audioSession?.configure()
    connection?.delegate = self
  }
  
  deinit {
    RTCCleanupSSL()
    audioSession = nil
  }
  
  func setPeerConnection(with iceServers: [RTCIceServer]) -> RTCPeerConnection? {
    let config = RTCConfiguration()
    config.iceServers = iceServers
    
    config.sdpSemantics = .unifiedPlan
    config.continualGatheringPolicy = .gatherContinually
    
    let constraints = RTCMediaConstraints(mandatoryConstraints: [
      kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
      kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueFalse
    ], optionalConstraints: nil)
    
    let peerConnection = factory.peerConnection(
      with: config,
      constraints: constraints,
      delegate: nil
    )
    
    if peerConnection == nil {
      QBoxLog.error(moduleName, "setPeerConnection() -> failed")
    }
    
    return peerConnection
  }
  
}

// MARK: - Signaling
extension RTCClient {
  func offer(completion: @escaping (_ sdp: RTCSessionDescription) -> Void) {
    let constrains = RTCMediaConstraints(
      mandatoryConstraints: nil,
      optionalConstraints: nil
    )
    
    connection?.offer(for: constrains) { [weak self] (sdp, error) in
      guard let sdp = sdp, let connection = self?.connection else { return }
      
      connection.setLocalDescription(sdp, completionHandler: { (error) in completion(sdp) })
    }
  }
  
  func answer(completion: @escaping (_ sdp: RTCSessionDescription) -> Void)  {
    let constrains = RTCMediaConstraints(mandatoryConstraints: nil,
                                         optionalConstraints: nil)
    connection?.answer(for: constrains) { [weak self] (sdp, error) in
      guard let sdp = sdp, let connection = self?.connection else { return }
      
      connection.setLocalDescription(sdp, completionHandler: { (error) in completion(sdp) })
    }
  }
  
  func set(remoteSdp: RTCSessionDescription) {
    connection?.setRemoteDescription(remoteSdp) { error in
      QBoxLog.error("RTCClient", "set(remoteSdp) -> error: \(String(describing: error))")
    }
  }
  
  func set(remoteCandidate: RTCIceCandidate) {
    connection?.add(remoteCandidate) { error in
      QBoxLog.error("RTCClient", "add(remoteSdp) -> error: \(String(describing: error))")
    }
  }
}
// MARK: - Media
extension RTCClient {
  private func createMediaSenders() {
    let streamId = "stream"
    
    // Audio
    let audioConstrains = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
    let audioSource = factory.audioSource(with: audioConstrains)
    let audioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")
    connection?.add(audioTrack, streamIds: [streamId])
  }

  func setAudioInput(_ isEnabled: Bool) {
    connection?.transceivers
      .compactMap { return $0.sender.track as? RTCAudioTrack }
      .forEach { $0.isEnabled = isEnabled }
  }
  
  func setAudioOutput(_ isEnabled: Bool) {
    connection?.transceivers
      .compactMap { return $0.receiver.track as? RTCAudioTrack }
      .forEach { $0.isEnabled = isEnabled }
  }
  
  func setSpeaker(_ isEnabled: Bool) {
    audioSession?.setSpeaker(isEnabled)
  }
}

// MARK: - WebRTC Delegate
extension RTCClient: RTCPeerConnectionDelegate {
  
  func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
    QBoxLog.debug(moduleName, "peerConnection(didChange stateChanged) -> signaling: \(stateChanged)")
  }
  
  func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
    QBoxLog.debug(moduleName, "peerConnection(didAdd stream) -> \(stream)")
    delegate?.rtcClient(didAdd: stream)
  }
  
  func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
    QBoxLog.debug(moduleName, "peerConnection(didRemove stream) -> \(stream)")
  }
  
  func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
    QBoxLog.debug(moduleName, "peerConnectionShouldNegotiate()")
  }
  
  func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
    QBoxLog.debug(moduleName, "peerConnection(didChange newState) -> connection: \(newState)")
    delegate?.rtcClient(didChange: newState)
  }
  
  func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
    QBoxLog.debug(moduleName, "peerConnection(didChange newState) -> gathering: \(newState)")
  }
  
  func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
    QBoxLog.debug(moduleName, "peerConnection(didGenerate localCandidate) -> \(candidate)")
    delegate?.rtcClient(didDiscover: candidate)
  }
  
  func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
    QBoxLog.debug(moduleName, "peerConnection(didRemove candidates) - > \(candidates)")
  }
  
  func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
    QBoxLog.debug(moduleName, "peerConnection(didOpen: dataChannel) -> \(dataChannel)")
  }
}


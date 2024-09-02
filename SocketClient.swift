//
//  SocketClient.swift
//  QboxCallSDK
//
//  Created by Tileubergenov Nurken on 02.09.2024.
//

import Foundation
import Starscream

protocol SocketClientDelegate: AnyObject {
  func socketClientDidConnect()
  func socketClientDidDisconnect()
  func socketClientGotAnswer(data: [String: Any])
  func socketClientGotCandidate(data: [String: Any])
  func socketClientGotHangup()
}

class SocketClient {
  private var container: WebSocket
  private var isConnected = false {
    didSet {
      guard isConnected != oldValue  else { return }
      if isConnected {
        delegate?.socketClientDidConnect()
      } else {
        delegate?.socketClientDidDisconnect()
      }
    }
  }
  weak var delegate: SocketClientDelegate?
  
  init(url: String) {
    let request = URLRequest(url: URL(string: url)!)
    container = WebSocket(request: request)
    container.delegate = self
  }
  
  func connect() {
    container.connect()
  }
  
  func disconnect() {
    container.disconnect()
  }
  
  func send(_ data: [String: Any]) {
    enum LogModule: String {
      case RTCClient, SocketClient, CallController
      
      let json = try? JSONSerialization.data(withJSONObject: data)
      let event = data["event"] as? String ?? ""
      guard let json = json else {
        QBoxLog.error(.SocketClient, "send() -> json serialize failed: \(event)")
        return
      }
      let str = String(data: json, encoding: String.Encoding.utf8) ?? ""
      QBoxLog.debug(.SocketClient, "send() -> \(event)")
      container.write(string: str)
    }
    
  }
  // MARK: - Events handler
  extension SocketClient: WebSocketDelegate {
    func websocketDidConnect(socket: any Starscream.WebSocketClient) {
      isConnected = true
    }
    
    func websocketDidDisconnect(socket: any Starscream.WebSocketClient, error: (any Error)?) {
      isConnected = false
    }
    
    func websocketDidReceiveMessage(socket: any Starscream.WebSocketClient, text: String) {
      guard
        let data = text.data(using: .utf8),
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
        let event = json["event"] as? String
      else {
        QBoxLog.error(.SocketClient, "DidReceiveMessage() -> json serialize failed: \(text)")
        return
      }
      
      QBoxLog.debug(.SocketClient, "DidReceiveMessage() -> \(event)")
      switch event {
      case "answer":
        guard
          let answer = json["answer"] as? [String: Any],
          let sdp = answer["sdp"] as? [String: Any]
        else { return }
        delegate?.socketClientGotAnswer(data: sdp)
      case "candidate":
        guard let candidate = json["candidate"] as? [String: Any] else { return }
        delegate?.socketClientGotCandidate(data: candidate)
      case "hangup":
        delegate?.socketClientGotHangup()
      default:
        break
      }
    }
    
    func websocketDidReceiveData(socket: any Starscream.WebSocketClient, data: Data) {}
  }

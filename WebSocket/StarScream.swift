//
//  StarScream.swift
//  QboxCallSDK
//
//  Created by Tileubergenov Nurken on 02.09.2024.
//

import Foundation
import Starscream


class StarscreamSocket: SocketProvider {
  let moduleName = "StarscreamSocket"
  
  weak var delegate: SocketProviderDelegate?
  private let socket: WebSocket
  var state = SocketState.None {
    didSet {
      guard state != oldValue  else { return }
      QBoxLog.debug(moduleName, "Connection state: \(state.rawValue)")
      delegate?.socketDidChange(state: state)
    }
  }
  
  init(url: String) {
    let request = URLRequest(url: URL(string: url)!)
    socket = WebSocket(request: request)
    socket.delegate = self
  }
  
  func connect() {
    socket.connect()
  }
  
  func disconnect() {
    socket.disconnect()
  }
  
  func send(_ data: [String: Any]) {
    guard let json = try? JSONSerialization.data(withJSONObject: data) else {
      QBoxLog.error(moduleName, "send() -> JSON exception, data: \(data)")
      return
    }
    let message = String(data: json, encoding: String.Encoding.utf8) ?? ""
    QBoxLog.debug(moduleName, "send() -> data: \(message)")
    socket.write(string: message) { }
  }
}

extension StarscreamSocket: WebSocketDelegate {
  func websocketDidConnect(socket: any Starscream.WebSocketClient) {
    state = SocketState.Connected
  }
  
  func websocketDidDisconnect(socket: any Starscream.WebSocketClient, error: (any Error)?) {
    state = SocketState.Disconnected
  }
  
  func websocketDidReceiveMessage(socket: any Starscream.WebSocketClient, text: String) {
    guard
      let data = text.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let event = json["event"] as? String
    else {
      QBoxLog.error(moduleName, "DidReceiveMessage() -> json serialize failed, data: \(text)")
      return
    }
    
    QBoxLog.debug(moduleName, "DidReceiveMessage() -> data: \(json)")
    delegate?.socketDidRecieve(data: json)
  }
  
  func websocketDidReceiveData(socket: any Starscream.WebSocketClient, data: Data) {}
  
}

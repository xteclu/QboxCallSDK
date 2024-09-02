//
//  WebSocket.swift
//  CallSDKTest
//
//  Created by Tileubergenov Nurken on 02.09.2024.
//

import Foundation

@available(iOS 13.0, *)
class NativeSocket: NSObject, SocketProvider {
  let moduleName = "NativeSocket"
  
  weak var delegate: SocketProviderDelegate?
  private var socket: URLSessionWebSocketTask?
  private var state = SocketState.None {
    didSet {
      guard state != oldValue  else { return }
      delegate?.socketDidChange(state: state)
    }
  }

  private lazy var urlSession: URLSession = URLSession(
    configuration: .default,
    delegate: self, 
    delegateQueue: nil
  )
  
  init(url urlString: String) {
    super.init()
    guard let url = URL(string: urlString) else {
      QBoxLog.error(moduleName, "init() -> incorrect url: \(urlString)")
      return
    }
    socket = urlSession.webSocketTask(with: url)
  }
  
  deinit {
    socket = nil
  }
  
  func connect() {
    socket?.resume()
    readMessage()
  }
  
  func send(_ data: [String: Any]) {
    guard let json = try? JSONSerialization.data(withJSONObject: data) else {
      QBoxLog.error(moduleName, "send() -> JSON exception, data: \(data)")
      return
    }
    let message = String(data: json, encoding: String.Encoding.utf8) ?? ""
    QBoxLog.debug(moduleName, "send() -> data: \(message)")

    socket?.send(.string(message)) { _ in }
  }
  
  private func readMessage() {
    socket?.receive { [weak self] message in
      guard let self = self else { return }
      
      switch message {
      case .success(.string(let data)):
        self.readMessage()
        
      case .success:
        debugPrint("Warning: Expected to receive data format but received a string. Check the websocket server config.")
      case .failure:
        self.disconnect()
      }
    }
  }
  
  private func disconnect() {
    socket?.cancel()
    delegate?.webSocketDidDisconnect(self)
  }
}

@available(iOS 13.0, *)
extension NativeSocket: URLSessionWebSocketDelegate, URLSessionDelegate  {
  func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
    self.delegate?.webSocketDidConnect(self)
  }
  
  func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
    self.disconnect()
  }
}

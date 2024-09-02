//
//  SocketProvider.swift
//  CallSDKTest
//
//  Created by Tileubergenov Nurken on 02.09.2024.
//

import Foundation


enum SocketState: String {
  case None, Connected, Disconnected
}

protocol SocketProvider: AnyObject {
  var delegate: SocketProviderDelegate? { get set }
  func connect()
  func disconnect()
  func send(_ data: [String: Any])
}

protocol SocketProviderDelegate: AnyObject {
  func socketDidChange(state: SocketState)
  func socketDidRecieve(data: [String: Any])
}

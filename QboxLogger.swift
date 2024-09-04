//
//  QboxLogger.swift
//  QboxCallSDK
//
//  Created by Tileubergenov Nurken on 02.09.2024.
//

import Foundation

var qLogMessages: [String] = [
  "Logs start"
]

public struct QBoxLog {
  static func print(_ message: String) {
    DispatchQueue.main.async {
      debugPrint(message)
      qLogMessages.append(message)
      mTable?.updateTable()
    }
  }
  
  static func error(_ module: String, _ message: String) {
    QBoxLog.print("ERROR Qbox." + module + ": " + message)
  }
  
  static func debug(_ module: String, _ message: String) {
    QBoxLog.print("Qbox." + module + "." + message)
  }
}

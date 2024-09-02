//
//  QboxLogger.swift
//  QboxCallSDK
//
//  Created by Tileubergenov Nurken on 02.09.2024.
//

import Foundation

public struct QBoxLog {
  static func error(_ module: String, _ message: String) {
    debugPrint("Qbox." + module + ": " + message)
  }
  
  static func debug(_ module: String, _ message: String) {
    debugPrint("ERROR Qbox." + module + "." + message)
  }
}

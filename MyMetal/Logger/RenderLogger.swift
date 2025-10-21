//
//  RenderLogger.swift
//  MyMetal
//
//  Created by Yauheni Kozich on 21.10.25.
//

import os.log
import os

// MARK: - Logger Protocol and Implementation
protocol Logger {
    func log(_ message: String, level: LogLevel)
}

enum LogLevel {
    case info, debug, warning, error
}

final class RenderLogger: Logger {
    static let shared = RenderLogger()
    private let logger = os.Logger(subsystem: "MetalCube", category: "Renderer")
    private init() {}
    func log(_ message: String, level: LogLevel) {
        switch level {
        case .info:
            logger.info("\(message, privacy: .public)")
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }
    }
}

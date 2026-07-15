//
//  AppLogger.swift
//  IosDevelopersGuide
//
//  Professional logging system using Apple's Unified Logging (OSLog)
//

import Foundation
import OSLog

protocol AppLoggerProtocol {
    func debug(_ message: String, privacy: PrivacyLevel, file: String, function: String, line: Int)
    func info(_ message: String, privacy: PrivacyLevel, file: String, function: String, line: Int)
    func notice(_ message: String, privacy: PrivacyLevel, file: String, function: String, line: Int)
    func error(_ message: String, privacy: PrivacyLevel, file: String, function: String, line: Int)
    func fault(_ message: String, privacy: PrivacyLevel, file: String, function: String, line: Int)
}

enum PrivacyLevel {
    case publicData
    case privateData
    case sensitive
}

final class OSLogLogger: AppLoggerProtocol {
    
    private let logger: Logger
    
    init(category: LogCategory, subsystem: String = "com.iosdevelopers.guide") {
        self.logger = Logger(subsystem: subsystem, category: category.rawValue)
    }
    
    
    func debug(_ message: String, privacy: PrivacyLevel = .publicData, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        switch privacy {
        case .publicData:
            logger.debug("\(message, privacy: .public)")
        case .privateData:
            logger.debug("\(message, privacy: .private)")
        case .sensitive:
            logger.debug("\(message, privacy: .sensitive)")
        }
        #endif
    }
    
    func info(_ message: String, privacy: PrivacyLevel = .publicData, file: String = #file, function: String = #function, line: Int = #line) {
        switch privacy {
        case .publicData:
            logger.info("\(message, privacy: .public)")
        case .privateData:
            logger.info("\(message, privacy: .private)")
        case .sensitive:
            logger.info("\(message, privacy: .sensitive)")
        }
    }
    
    func notice(_ message: String, privacy: PrivacyLevel = .publicData, file: String = #file, function: String = #function, line: Int = #line) {
        switch privacy {
        case .publicData:
            logger.notice("\(message, privacy: .public)")
        case .privateData:
            logger.notice("\(message, privacy: .private)")
        case .sensitive:
            logger.notice("\(message, privacy: .sensitive)")
        }
    }
    
    func error(_ message: String, privacy: PrivacyLevel = .privateData, file: String = #file, function: String = #function, line: Int = #line) {
        switch privacy {
        case .publicData:
            logger.error("\(message, privacy: .public)")
        case .privateData:
            logger.error("\(message, privacy: .private)")
        case .sensitive:
            logger.error("\(message, privacy: .sensitive)")
        }
    }
    
    func fault(_ message: String, privacy: PrivacyLevel = .privateData, file: String = #file, function: String = #function, line: Int = #line) {
        switch privacy {
        case .publicData:
            logger.fault("\(message, privacy: .public)")
        case .privateData:
            logger.fault("\(message, privacy: .private)")
        case .sensitive:
            logger.fault("\(message, privacy: .sensitive)")
        }
    }
}

extension AppLoggerProtocol {

    // MARK: - Convenience Methods without privacy
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, privacy: .publicData, file: file, function: function, line: line)
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message, privacy: .publicData, file: file, function: function, line: line)
    }

    func notice(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        notice(message, privacy: .publicData, file: file, function: function, line: line)
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        error(message, privacy: .privateData, file: file, function: function, line: line)
    }

    func fault(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        fault(message, privacy: .privateData, file: file, function: function, line: line)
    }

    // MARK: - Convenience Methods with privacy
    func debug(_ message: String, privacy: PrivacyLevel, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, privacy: privacy, file: file, function: function, line: line)
    }

    func info(_ message: String, privacy: PrivacyLevel, file: String = #file, function: String = #function, line: Int = #line) {
        info(message, privacy: privacy, file: file, function: function, line: line)
    }

    func notice(_ message: String, privacy: PrivacyLevel, file: String = #file, function: String = #function, line: Int = #line) {
        notice(message, privacy: privacy, file: file, function: function, line: line)
    }

    func error(_ message: String, privacy: PrivacyLevel, file: String = #file, function: String = #function, line: Int = #line) {
        error(message, privacy: privacy, file: file, function: function, line: line)
    }

    func fault(_ message: String, privacy: PrivacyLevel, file: String = #file, function: String = #function, line: Int = #line) {
        fault(message, privacy: privacy, file: file, function: function, line: line)
    }
}

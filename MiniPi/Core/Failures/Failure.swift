//
//  Failure.swift
//  IosDevelopersGuide
//
//  Created by [Your Name]
//  Copyright © 2026. All rights reserved.
//

import Foundation

enum FailureSeverity: String {
    case info
    case warning
    case critical
    
    var displayName: String {
        switch self {
        case .info: return "Info"
        case .warning: return "Warning"
        case .critical: return "Error"
        }
    }
    
    var iconName: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.circle.fill"
        }
    }
}

protocol Failure: Error, CustomStringConvertible, LocalizedError {

    var message: String { get }

    var severity: FailureSeverity { get }

    var cause: Failure? { get }

    var technicalDetails: String? { get }

    func isEqual(to other: Failure) -> Bool
}

extension Failure {

    /// Surfaces the user-facing message through `localizedDescription`
    /// so it is displayed correctly in the UI (alerts, error banners, etc.).
    var errorDescription: String? {
        description
    }

    var technicalDetails: String? {
        var details = "Failure: \(message)"
        if let cause = cause {
            details += "\nCaused by: \(cause.description)"
        }
        return details
    }
    
    var description: String {
        if let cause = cause {
            return "\(message) (caused by: \(cause.message))"
        }
        return message
    }
    
    var chain: String {
        var chain = message
        var currentCause = cause
        while let nextCause = currentCause {
            chain += " → " + nextCause.message
            currentCause = nextCause.cause
        }
        return chain
    }
}

extension Failure where Self: Equatable {
    func isEqual(to other: Failure) -> Bool {
        guard let other = other as? Self else { return false }
        return self == other
    }
}

@available(iOS 13.0, *)
extension Failure {}

//
//  NetworkFailure.swift
//  IosDevelopersGuide
//
//  Created by [Your Name]
//  Copyright © 2026. All rights reserved.
//

import Foundation

/// Failure representing network-related errors
struct NetworkFailure: Failure, Equatable {
    let message: String
    let severity: FailureSeverity
    let cause: Failure?
    let technicalDetails: String?
    
    init(_ message: String, severity: FailureSeverity = .warning, cause: Failure? = nil, technicalDetails: String? = nil) {
        self.message = message
        self.severity = severity
        self.cause = cause
        self.technicalDetails = technicalDetails
    }
    
    // MARK: - Equatable Conformance
    
    static func == (lhs: NetworkFailure, rhs: NetworkFailure) -> Bool {
        return lhs.message == rhs.message &&
               lhs.severity == rhs.severity &&
               lhs.technicalDetails == rhs.technicalDetails
        // Note: We skip cause comparison to avoid infinite recursion
    }
    
    // MARK: - Common Network Failures

    /// No internet connection available
    static func noConnection(cause: Failure? = nil) -> NetworkFailure {
        NetworkFailure("No internet connection. Please check your network settings.",
                       severity: .warning,
                       cause: cause)
    }

    /// Network unavailable (alias for noConnection)
    static func networkUnavailable(_ message: String = "Network unavailable", severity: FailureSeverity = .critical, cause: Failure? = nil) -> NetworkFailure {
        NetworkFailure(message, severity: severity, cause: cause)
    }

    /// Request timed out
    static func timeout(cause: Failure? = nil) -> NetworkFailure {
        NetworkFailure("Request timed out. Please try again.",
                       severity: .warning,
                       cause: cause)
    }

    /// Server unreachable
    static func unreachable(cause: Failure? = nil) -> NetworkFailure {
        NetworkFailure("Server is unreachable. Please check your connection.",
                       severity: .warning,
                       cause: cause)
    }
}

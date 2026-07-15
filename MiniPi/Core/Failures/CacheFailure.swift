//
//  CacheFailure.swift
//  IosDevelopersGuide
//
//  Created by [Your Name]
//  Copyright © 2026. All rights reserved.
//

import Foundation

struct CacheFailure: Failure, Equatable {
    let message: String
    let severity: FailureSeverity
    let cause: Failure?
    let technicalDetails: String?
    
    init(_ message: String,
         severity: FailureSeverity = .info,
         cause: Failure? = nil,
         technicalDetails: String? = nil) {
        self.message = message
        self.severity = severity
        self.cause = cause
        self.technicalDetails = technicalDetails
    }
    
    static func == (lhs: CacheFailure, rhs: CacheFailure) -> Bool {
        return lhs.message == rhs.message &&
               lhs.severity == rhs.severity &&
               lhs.technicalDetails == rhs.technicalDetails
    }
    
    static func notFound(cause: Failure? = nil) -> CacheFailure {
        CacheFailure("No cached data available.",
                     severity: .info,
                     cause: cause)
    }

    static func writeFailed(cause: Failure? = nil) -> CacheFailure {
        CacheFailure("Failed to save data locally.",
                     severity: .info,
                     cause: cause)
    }

    static func readFailed(_ message: String = "Failed to read cached data.", severity: FailureSeverity = .warning, cause: Failure? = nil) -> CacheFailure {
        CacheFailure(message, severity: severity, cause: cause)
    }

    static func corrupted(cause: Failure? = nil) -> CacheFailure {
        CacheFailure("Cached data is corrupted.",
                     severity: .warning,
                     cause: cause)
    }
}

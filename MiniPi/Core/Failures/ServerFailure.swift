//
//  ServerFailure.swift
//  IosDevelopersGuide
//
//  Created by [Your Name]
//  Copyright © 2026. All rights reserved.
//

import Foundation

struct ServerFailure: Failure, Equatable {
    let message: String
    let severity: FailureSeverity
    let cause: Failure?
    let technicalDetails: String?
    let statusCode: Int?
    
    init(_ message: String,
         severity: FailureSeverity = .critical,
         cause: Failure? = nil,
         technicalDetails: String? = nil,
         statusCode: Int? = nil) {
        self.message = message
        self.severity = severity
        self.cause = cause
        self.technicalDetails = technicalDetails
        self.statusCode = statusCode
    }
    
    static func == (lhs: ServerFailure, rhs: ServerFailure) -> Bool {
        return lhs.message == rhs.message &&
               lhs.severity == rhs.severity &&
               lhs.statusCode == rhs.statusCode &&
               lhs.technicalDetails == rhs.technicalDetails
    }
    
    static func internalServerError(_ message: String = "Server encountered an error. Please try again later.", severity: FailureSeverity = .critical, statusCode: Int = 500, cause: Failure? = nil) -> ServerFailure {
        ServerFailure(message,
                      severity: severity,
                      cause: cause,
                      statusCode: statusCode)
    }

    static func badRequest(cause: Failure? = nil) -> ServerFailure {
        ServerFailure("Invalid request. Please check your input.",
                      severity: .warning,
                      cause: cause,
                      statusCode: 400)
    }

    static func unauthorized(cause: Failure? = nil) -> ServerFailure {
        ServerFailure("Authentication required. Please log in.",
                      severity: .warning,
                      cause: cause,
                      statusCode: 401)
    }

    static func notFound(cause: Failure? = nil) -> ServerFailure {
        ServerFailure("Requested resource not found.",
                      severity: .warning,
                      cause: cause,
                      statusCode: 404)
    }
}

//
//  NetworkException.swift
//  IosDevelopersGuide
//
//  Created by [Your Name]
//  Copyright © 2026. All rights reserved.
//

import Foundation

struct NetworkException: AppException {
    let message: String
    let cause: Error?
    let context: String?
    
    init(_ message: String, cause: Error? = nil, context: String? = nil) {
        self.message = message
        self.cause = cause
        self.context = context
    }

    static func noConnection(cause: Error? = nil, context: String? = nil) -> NetworkException {
        NetworkException("No internet connection available", cause: cause, context: context)
    }
    
    static func timeout(cause: Error? = nil, context: String? = nil) -> NetworkException {
        NetworkException("Request timed out", cause: cause, context: context)
    }
    
    static func unreachable(cause: Error? = nil, context: String? = nil) -> NetworkException {
        NetworkException("Server unreachable", cause: cause, context: context)
    }
    
    static func connectionLost(cause: Error? = nil, context: String? = nil) -> NetworkException {
        NetworkException("Connection lost during request", cause: cause, context: context)
    }
}

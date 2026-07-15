//
//  ServerException.swift
//  IosDevelopersGuide
//
//  Created by [Your Name]
//  Copyright © 2026. All rights reserved.
//

import Foundation

struct ServerException: AppException {
    let message: String
    let cause: Error?
    let context: String?
    let statusCode: Int?
    
    init(_ message: String, cause: Error? = nil, context: String? = nil, statusCode: Int? = nil) {
        self.message = message
        self.cause = cause
        self.context = context
        self.statusCode = statusCode
    }
    
    static func internalServerError(statusCode: Int = 500, cause: Error? = nil, context: String? = nil) -> ServerException {
        ServerException("Internal server error", cause: cause, context: context, statusCode: statusCode)
    }
    
    static func badRequest(statusCode: Int = 400, cause: Error? = nil, context: String? = nil) -> ServerException {
        ServerException("Bad request", cause: cause, context: context, statusCode: statusCode)
    }
    
    static func unauthorized(statusCode: Int = 401, cause: Error? = nil, context: String? = nil) -> ServerException {
        ServerException("Unauthorized", cause: cause, context: context, statusCode: statusCode)
    }
    
    static func notFound(statusCode: Int = 404, cause: Error? = nil, context: String? = nil) -> ServerException {
        ServerException("Resource not found", cause: cause, context: context, statusCode: statusCode)
    }
}

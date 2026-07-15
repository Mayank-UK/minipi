//
//  ErrorTestingHelper.swift
//  IosDevelopersGuide
//
//  Created by [Your Name]
//  Copyright © 2026. All rights reserved.
//

import Foundation

class ErrorTestingHelper {
    
    static func simulateNetworkTimeout() -> NetworkException {
        NetworkException.timeout(
            cause: URLError(.timedOut),
            context: "Simulated timeout for testing"
        )
    }
    
    static func simulateNoConnection() -> NetworkException {
        NetworkException.noConnection(
            cause: URLError(.notConnectedToInternet),
            context: "Simulated no connection for testing"
        )
    }
    
    static func simulateServerError() -> ServerException {
        ServerException.internalServerError(
            statusCode: 500,
            cause: nil,
            context: "Simulated server error for testing"
        )
    }
    
    static func simulateNotFound() -> ServerException {
        ServerException.notFound(
            statusCode: 404,
            cause: nil,
            context: "Simulated not found for testing"
        )
    }
    
    static func simulateDatabaseError() -> DatabaseException {
        DatabaseException.readFailed(
            cause: nil,
            context: "Simulated database error for testing"
        )
    }
    
    static func simulateDecodingError() -> DecodingException {
        DecodingException.jsonDecodingFailed(
            cause: nil,
            context: "Simulated decoding error for testing"
        )
    }
}

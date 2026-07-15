//
//  DecodingException.swift
//  IosDevelopersGuide
//
//  Created by [Your Name]
//  Copyright © 2026. All rights reserved.
//

import Foundation

struct DecodingException: AppException {
    let message: String
    let cause: Error?
    let context: String?
    let decodingPath: [String]?
    
    init(_ message: String, cause: Error? = nil, context: String? = nil, decodingPath: [String]? = nil) {
        self.message = message
        self.cause = cause
        self.context = context
        self.decodingPath = decodingPath
    }
    
    static func jsonDecodingFailed(cause: Error? = nil, context: String? = nil, decodingPath: [String]? = nil) -> DecodingException {
        DecodingException("Failed to decode JSON", cause: cause, context: context, decodingPath: decodingPath)
    }
    
    static func missingField(fieldName: String, cause: Error? = nil, context: String? = nil) -> DecodingException {
        DecodingException("Missing required field: \(fieldName)", cause: cause, context: context, decodingPath: [fieldName])
    }
    
    static func invalidType(fieldName: String, expectedType: String, cause: Error? = nil, context: String? = nil) -> DecodingException {
        DecodingException("Invalid type for field: \(fieldName) (expected: \(expectedType))", cause: cause, context: context, decodingPath: [fieldName])
    }
}

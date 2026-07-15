//
//  guardedApiCall.swift
//  IosDevelopersGuide
//
//  Created by [Your Name]
//  Copyright © 2026. All rights reserved.
//

import Foundation

func guardedApiCall<T>(_ call: @escaping () async throws -> T) async throws -> T {
    do {
        return try await call()
    } catch let urlError as URLError {
        throw mapURLError(urlError)
        
    } catch let decodingError as DecodingError {
        throw mapDecodingError(decodingError)
        
    } catch let appException as AppException {
        throw appException
        
    } catch {
        throw ServerException("Unexpected API error", cause: error)
    }
}

private func mapURLError(_ urlError: URLError) -> AppException {
    switch urlError.code {
    case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost:
        return NetworkException.noConnection(cause: urlError)
        
    case .timedOut:
        return NetworkException.timeout(cause: urlError)
        
    case .serverCertificateUntrusted, .clientCertificateRejected, .secureConnectionFailed:
        return NetworkException.unreachable(cause: urlError)
        
    case .badURL, .unsupportedURL:
        return ServerException.badRequest(cause: urlError)
        
    case .httpTooManyRedirects:
        return NetworkException.unreachable(cause: urlError)
        
    default:
        return NetworkException("URL error: \(urlError.localizedDescription)", cause: urlError)
    }
}

private func mapDecodingError(_ decodingError: DecodingError) -> DecodingException {
    switch decodingError {
    case .typeMismatch(let type, let context):
        let fieldName = context.codingPath.map { $0.stringValue }.joined(separator: ".")
        return DecodingException.invalidType(
            fieldName: fieldName,
            expectedType: String(describing: type),
            cause: decodingError
        )
        
    case .valueNotFound(let type, let context):
        let fieldName = context.codingPath.map { $0.stringValue }.joined(separator: ".")
        return DecodingException.missingField(
            fieldName: fieldName,
            cause: decodingError
        )
        
    case .keyNotFound(let key, let context):
        let fieldName = context.codingPath.map { $0.stringValue }.joined(separator: ".")
        return DecodingException.missingField(
            fieldName: "\(fieldName).\(key.stringValue)",
            cause: decodingError
        )
        
    case .dataCorrupted(let context):
        return DecodingException.jsonDecodingFailed(
            cause: decodingError,
            context: "Data corrupted: \(context.debugDescription)"
        )
        
    @unknown default:
        return DecodingException.jsonDecodingFailed(cause: decodingError)
    }
}

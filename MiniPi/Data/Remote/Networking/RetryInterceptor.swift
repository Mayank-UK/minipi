//
//  RetryInterceptor.swift
//  IosDevelopersGuide
//
//  `Interceptor` that retries transient failures with linear backoff before
//  letting the error propagate to `guardedApiCall`.
//
//  Transient conditions:
//    - `URLError` codes: `timedOut`, `networkConnectionLost`,
//      `notConnectedToInternet`, `cannotConnectToHost`
//    - `ServerException` with status in `500...599`
//
//  After `maxRetries` attempts, the last error is rethrown so the app's error
//  handling maps it as usual.
//

import Foundation

final class RetryInterceptor: Interceptor {

    private let maxRetries: Int
    private let baseDelay: Duration

    init(maxRetries: Int = 2, baseDelay: Duration = .milliseconds(300)) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
    }

    func intercept(
        _ request: URLRequest,
        proceeding next: @escaping @Sendable (URLRequest) async throws -> HTTPResponse
    ) async throws -> HTTPResponse {

        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                return try await next(request)
            } catch let error {
                lastError = error

                if attempt < maxRetries, isTransient(error) {
                    // Linear backoff: baseDelay * (attempt + 1).
                    let delay = baseDelay * (attempt + 1)
                    try? await Task.sleep(for: delay)
                    continue
                }

                throw error
            }
        }

        // Exhausted retries; surface the last error.
        throw lastError ?? ServerException("Retry exhausted")
    }

    private func isTransient(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost:
                return true
            default:
                return false
            }
        }

        if let serverError = error as? ServerException,
           let code = serverError.statusCode {
            return (500...599).contains(code)
        }

        return false
    }
}

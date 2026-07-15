//
//  AuthTokenInterceptor.swift
//  IosDevelopersGuide
//
//  `Interceptor` that attaches common headers and the current auth token to
//  every outgoing request.
//
//  - Always sets `Accept: application/json`.
//  - When `AuthTokenProvider.currentToken()` returns a token, attaches
//    `Authorization: Bearer <token>`. The stub provider returns `nil` until a
//    real auth backend is wired in, so the header is simply skipped.
//

import Foundation

protocol AuthTokenProvider: Sendable {
    func currentToken() async -> String?
}

/// No-op provider used until a real auth backend exists. Returns `nil` so no
/// `Authorization` header is attached.
struct StubAuthTokenProvider: AuthTokenProvider {
    func currentToken() async -> String? { nil }
}

final class AuthTokenInterceptor: Interceptor {

    private let provider: AuthTokenProvider

    init(provider: AuthTokenProvider) {
        self.provider = provider
    }

    func intercept(
        _ request: URLRequest,
        proceeding next: @escaping @Sendable (URLRequest) async throws -> HTTPResponse
    ) async throws -> HTTPResponse {

        var request = request
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = await provider.currentToken(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return try await next(request)
    }
}

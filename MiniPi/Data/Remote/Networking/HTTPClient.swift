//
//  HTTPClient.swift
//  IosDevelopersGuide
//
//  A thin wrapper around `URLSession` that runs a chain of `Interceptor`s around
//  every request. Interceptors are applied in array order — index 0 is the
//  outermost (runs first on the way out, last on the way back).
//
//  This is the iOS counterpart to the OkHttp client (Android) and Dio client
//  (Flutter), whose interceptor chains already power auth headers, retry, and
//  dev failure-injection in the sibling projects.
//

import Foundation

final class HTTPClient: @unchecked Sendable {

    private let session: URLSession
    private let interceptors: [Interceptor]

    init(
        session: URLSession = .shared,
        interceptors: [Interceptor] = []
    ) {
        self.session = session
        self.interceptors = interceptors
    }

    /// Sends `request` through the interceptor chain, then performs the real
    /// network fetch. Non-2xx responses are converted to `ServerException` so
    /// they flow through `guardedApiCall` like any other failure.
    func send(_ request: URLRequest) async throws -> HTTPResponse {
        // The innermost handler: performs the actual fetch + validates status.
        @Sendable func core(_ req: URLRequest) async throws -> HTTPResponse {
            let (data, response) = try await session.data(for: req)

            guard let http = response as? HTTPURLResponse else {
                throw ServerException(
                    "Non-HTTP response",
                    cause: nil,
                    context: req.url?.absoluteString
                )
            }

            guard (200..<300).contains(http.statusCode) else {
                throw ServerException(
                    "Server returned \(http.statusCode)",
                    cause: nil,
                    context: req.url?.absoluteString,
                    statusCode: http.statusCode
                )
            }

            return HTTPResponse(data: data, response: http)
        }

        // Fold interceptors around `core`. Reversed so that index 0 ends up
        // outermost (runs first).
        var chain: @Sendable (URLRequest) async throws -> HTTPResponse = core
        for interceptor in interceptors.reversed() {
            let next = chain
            chain = { req in
                try await interceptor.intercept(req, proceeding: next)
            }
        }

        return try await chain(request)
    }
}

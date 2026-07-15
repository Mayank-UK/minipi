//
//  Interceptor.swift
//  IosDevelopersGuide
//
//  Interceptor-chain primitives for the `HTTPClient`. This is the iOS counterpart
//  to OkHttp's `Interceptor` (Android) and Dio's `Interceptor` (Flutter): each
//  interceptor sees a `URLRequest`, can modify it or short-circuit with an error,
//  and calls `next` to proceed down the chain.
//
//  `HTTPResponse` is the type handed back up the chain on success.
//

import Foundation

struct HTTPResponse: Sendable {
    let data: Data
    let response: HTTPURLResponse
}

protocol Interceptor: Sendable {
    /// Inspect/modify `request`, then either short-circuit by throwing, or
    /// proceed by calling `next(request)` and returning (or transforming) its
    /// `HTTPResponse`.
    func intercept(
        _ request: URLRequest,
        proceeding next: @escaping @Sendable (URLRequest) async throws -> HTTPResponse
    ) async throws -> HTTPResponse
}

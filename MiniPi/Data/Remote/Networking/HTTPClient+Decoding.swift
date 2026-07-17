//
//  HTTPClient+Decoding.swift
//  MiniPi
//
//  Shared GET + JSON-decode convenience over `HTTPClient`. This is the reusable
//  networking primitive every feature remote data source builds on, so the
//  per-feature data sources stay tiny (just endpoints + decoding type) and the
//  interceptor chain / failure mapping lives in one place.
//

import Foundation

extension HTTPClient {

    /// GET `urlString`, decode the response as `T`. Runs through `guardedApiCall`
    /// so the shared failure mapping (network / server / decoding exceptions) applies.
    func get<T: Decodable>(_ urlString: String, as type: T.Type) async throws -> T {
        try await get(urlString, as: type, headers: [:])
    }

    /// GET with extra request headers. Same shared failure mapping as `get(_:as:)`.
    /// Used by providers that need a `User-Agent` (e.g. Yahoo Finance, which rejects
    /// default `URLSession` requests with HTTP 999 / Cloudflare).
    func get<T: Decodable>(_ urlString: String, as type: T.Type, headers: [String: String]) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw NetworkException("Invalid URL", context: urlString)
        }

        return try await guardedApiCall {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            for (name, value) in headers {
                request.setValue(value, forHTTPHeaderField: name)
            }
            let response = try await self.send(request)
            return try JSONDecoder().decode(T.self, from: response.data)
        }
    }
}

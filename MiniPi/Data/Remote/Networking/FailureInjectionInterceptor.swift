//
//  FailureInjectionInterceptor.swift
//  IosDevelopersGuide
//
//  Dev-only `Interceptor` that injects API failures on the client side, in front
//  of the **real** `HTTPClient`. It throws or fabricates the same errors a real
//  failing network would, so `guardedApiCall` maps them exactly as it would in
//  production — no fake service required for failure testing.
//
//  The scenario is supplied by the DI module from `AppConfiguration` (single
//  source of truth), so there is no default here. Because it is mutable, it can
//  also be flipped at runtime from a debug menu.
//
//  Mirrors Android's `data/remote/FailureInjectionInterceptor` and Flutter's
//  `data/remote/failure_injection_interceptor.dart`.
//

import Foundation

final class FailureInjectionInterceptor: Interceptor, @unchecked Sendable {

    var scenario: ApiScenario

    init(scenario: ApiScenario) {
        self.scenario = scenario
    }

    func intercept(
        _ request: URLRequest,
        proceeding next: @escaping @Sendable (URLRequest) async throws -> HTTPResponse
    ) async throws -> HTTPResponse {
        switch scenario {
        case .success:
            // Proceed to the real API.
            return try await next(request)

        case .networkError:
            // `guardedApiCall` maps this to `NetworkException.noConnection`.
            throw URLError(.notConnectedToInternet)

        case .timeout:
            // `guardedApiCall` maps this to `NetworkException.timeout`.
            throw URLError(.timedOut)

        case .serverError:
            throw ServerException.internalServerError(
                statusCode: 500,
                context: "Simulated server error"
            )

        case .notFound:
            throw ServerException.notFound(
                statusCode: 404,
                context: "Simulated not found"
            )

        case .unauthorized:
            throw ServerException.unauthorized(
                statusCode: 401,
                context: "Simulated unauthorized"
            )

        case .invalidJson:
            // Fabricate a 200 with a malformed body so the downstream
            // `JSONDecoder` throws `DecodingError`, which `guardedApiCall`
            // maps to `DecodingException`.
            return HTTPResponse(
                data: Data("{{invalid-json".utf8),
                response: HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                )!
            )
        }
    }
}

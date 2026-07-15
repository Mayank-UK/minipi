//
//  FakeApiService.swift
//  IosDevelopersGuide
//
//  Created by [Your Name]
//  Copyright © 2026. All rights reserved.
//

import Foundation

// Use fakeApiService when backend is not ready yet

class FakeApiService: APIServiceProtocol {
    
    private var scenario: ApiScenario
    private var latency: TimeInterval = 0.6
    
    private let fakePosts: [PostDTO] = [
        PostDTO(id: 1, title: "Fake Post 1", body: "This is a fake post from FakeApiService"),
        PostDTO(id: 2, title: "Fake Post 2", body: "Another fake post for testing"),
        PostDTO(id: 3, title: "Fake Post 3", body: "Testing error handling scenarios"),
    ]
    
    // Scenario is supplied by the DI module from AppConfiguration (single source of truth) — no
    // default here so the value can't drift.
    init(scenario: ApiScenario, latency: TimeInterval = 0.6) {
         self.scenario = scenario
        self.latency = latency
    }
    
    func setScenario(_ scenario: ApiScenario) {
        self.scenario = scenario
    }
    
    func fetchPosts() async throws -> [PostDTO] {
        return try await simulateApiCall("fetchPosts") {
            return self.fakePosts
        }
    }
    
    private func simulateApiCall<T>(_ operation: String, success: @escaping () -> T) async throws -> T {
        try await Task.sleep(nanoseconds: UInt64(latency * 1_000_000_000))

        switch scenario {
        case .success:
            return success()

        case .networkError:
            throw NetworkException.noConnection(
                cause: URLError(.notConnectedToInternet),
                context: "FakeApiService network error simulation"
            )

        case .timeout:
            throw NetworkException.timeout(
                cause: URLError(.timedOut),
                context: "FakeApiService timeout simulation"
            )

        case .serverError:
            throw ServerException.internalServerError(
                statusCode: 500,
                cause: nil,
                context: "FakeApiService server error simulation"
            )

        case .notFound:
            throw ServerException.notFound(
                statusCode: 404,
                cause: nil,
                context: "FakeApiService not found simulation"
            )

        case .unauthorized:
            throw ServerException.unauthorized(
                statusCode: 401,
                cause: nil,
                context: "FakeApiService unauthorized simulation"
            )

        case .invalidJson:
            throw DecodingException.jsonDecodingFailed(
                cause: nil,
                context: "FakeApiService invalid JSON simulation"
            )
        }
    }
}

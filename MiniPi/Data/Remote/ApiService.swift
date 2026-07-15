//
//  ApiService.swift
//  IosDevelopersGuide
//
//  Created by Mayank Upadhyay on 22/08/24.
//

import Foundation

enum ErrorTypes: Error, LocalizedError {
    case networkError(URLError)
    case decodingError(DecodingError)
    case databaseError(Error)
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let urlError):
            return "Network error occurred: \(urlError.localizedDescription)"
        case .decodingError(let decodingError):
            return "Failed to decode data: \(decodingError.localizedDescription)"
        case .databaseError(let dbError):
            return "Database error: \(dbError.localizedDescription)"
        case .unknownError(let error):
            return "An unknown error occurred: \(error.localizedDescription)"
        }
    }
}


protocol APIServiceProtocol {
    func fetchPosts() async throws -> [PostDTO]
}

class APIService: APIServiceProtocol {
    private let baseURL = AppConfiguration.shared.apiBaseURL
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    // Generic method for making network requests through the interceptor chain.
    // Failure simulation is handled by the dev-only `FailureInjectionInterceptor`,
    // so there are no manual `ErrorTestingHelper` lines here anymore.
    private func fetchData<T: Decodable>(from urlString: String, type: T.Type) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw NetworkException("Invalid URL", context: urlString)
        }

        return try await guardedApiCall {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"

            let response = try await self.client.send(request)
            return try JSONDecoder().decode(T.self, from: response.data)
        }
    }

    func fetchPosts() async throws -> [PostDTO] {
        try await fetchData(
            from: "\(baseURL)/posts",
            type: [PostDTO].self
        )
    }
}


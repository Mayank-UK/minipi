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
    func fetchAsteroidFeed(startDate: String, endDate: String) async throws -> NeoFeedDTO
    func fetchAsteroidLookup(id: String) async throws -> AsteroidDTO
    func fetchAsteroidBrowse(page: Int, size: Int) async throws -> NeoBrowseDTO
}

class APIService: APIServiceProtocol {
    private let baseURL = AppConfiguration.shared.apiBaseURL
    private let nasaBaseURL = "https://api.nasa.gov/neo/rest/v1"
    private let nasaApiKey = AppConfiguration.shared.nasaApiKey
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

    /// NASA NeoWs `feed` — asteroids approaching in a date window (max 7 days).
    func fetchAsteroidFeed(startDate: String, endDate: String) async throws -> NeoFeedDTO {
        let url = "\(nasaBaseURL)/feed?start_date=\(startDate)&end_date=\(endDate)&api_key=\(nasaApiKey)"
        return try await fetchData(from: url, type: NeoFeedDTO.self)
    }

    /// NASA NeoWs lookup — full detail for one body by id, *including* `orbital_data`.
    /// Used to get orbital elements for the Home tab's asteroids (the `feed` endpoint
    /// omits `orbital_data`).
    func fetchAsteroidLookup(id: String) async throws -> AsteroidDTO {
        let url = "\(nasaBaseURL)/neo/\(id)?api_key=\(nasaApiKey)"
        return try await fetchData(from: url, type: AsteroidDTO.self)
    }

    /// NASA NeoWs `neo/browse` — one page of the full NEO catalog, each body already
    /// carrying `orbital_data`. Used to populate the 3D scene with asteroids spread
    /// all around the Sun (the close-approach `feed` clusters them near Earth).
    /// `page` is 0-indexed; `size` is per-page (NASA caps at 20 ≈ the catalog order).
    func fetchAsteroidBrowse(page: Int, size: Int) async throws -> NeoBrowseDTO {
        let url = "\(nasaBaseURL)/neo/browse?page=\(page)&size=\(size)&api_key=\(nasaApiKey)"
        return try await fetchData(from: url, type: NeoBrowseDTO.self)
    }
}


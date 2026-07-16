//
//  AsteroidRemoteDataSource.swift
//  MiniPi
//
//  Feature-scoped remote data source for NASA NeoWs (Near-Earth Objects).
//  Owns only the asteroid endpoints behind a narrow protocol; the shared
//  networking engine (HTTPClient + interceptors) is injected.
//

import Foundation

protocol AsteroidRemoteDataSource {
    /// NASA NeoWs `feed` — asteroids approaching in a date window (max 7 days).
    func fetchFeed(startDate: String, endDate: String) async throws -> NeoFeedDTO

    /// NASA NeoWs lookup — full detail for one body by id, including `orbital_data`.
    /// Used to get orbital elements for individual bodies (the `feed` omits them).
    func lookup(id: String) async throws -> AsteroidDTO

    /// NASA NeoWs `neo/browse` — one page of the full NEO catalog, each body already
    /// carrying `orbital_data`. `page` is 0-indexed; `size` is per-page.
    func browse(page: Int, size: Int) async throws -> NeoBrowseDTO
}

final class AsteroidRemoteDataSourceImpl: AsteroidRemoteDataSource {

    private let nasaBaseURL = "https://api.nasa.gov/neo/rest/v1"
    private let nasaApiKey = AppConfiguration.shared.nasaApiKey
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func fetchFeed(startDate: String, endDate: String) async throws -> NeoFeedDTO {
        let url = "\(nasaBaseURL)/feed?start_date=\(startDate)&end_date=\(endDate)&api_key=\(nasaApiKey)"
        return try await client.get(url, as: NeoFeedDTO.self)
    }

    func lookup(id: String) async throws -> AsteroidDTO {
        try await client.get("\(nasaBaseURL)/neo/\(id)?api_key=\(nasaApiKey)", as: AsteroidDTO.self)
    }

    func browse(page: Int, size: Int) async throws -> NeoBrowseDTO {
        try await client.get("\(nasaBaseURL)/neo/browse?page=\(page)&size=\(size)&api_key=\(nasaApiKey)", as: NeoBrowseDTO.self)
    }
}

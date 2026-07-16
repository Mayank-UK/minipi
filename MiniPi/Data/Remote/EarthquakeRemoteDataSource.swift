//
//  EarthquakeRemoteDataSource.swift
//  MiniPi
//
//  Feature-scoped remote data source for USGS Earthquakes. Owns only the USGS
//  endpoints behind a narrow protocol; the shared networking engine (HTTPClient
//  + interceptors) is injected — exactly like AsteroidRemoteDataSource.
//
//  USGS needs no API key. The feed + query + detail endpoints all return the
//  same GeoJSON `FeatureCollection`, so they decode into one DTO.
//

import Foundation

protocol EarthquakeRemoteDataSource {
    /// USGS summary feed (`feed/v1.0/summary/<segment>.geojson`).
    func fetchFeed(_ feed: EarthquakeFeed) async throws -> GeoJSONFeatureCollectionDTO

    /// USGS FDSNWS `query` (`fdsnws/event/1/query?format=geojson&…`).
    func query(_ query: EarthquakeQuery) async throws -> GeoJSONFeatureCollectionDTO

    /// USGS detail lookup (`feed/v1.0/detail/<id>.geojson`).
    func lookup(id: String) async throws -> GeoJSONFeatureCollectionDTO
}

final class EarthquakeRemoteDataSourceImpl: EarthquakeRemoteDataSource {

    private let feedBaseURL = "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary"
    private let queryBaseURL = "https://earthquake.usgs.gov/fdsnws/event/1/query"
    private let detailBaseURL = "https://earthquake.usgs.gov/earthquakes/feed/v1.0/detail"
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func fetchFeed(_ feed: EarthquakeFeed) async throws -> GeoJSONFeatureCollectionDTO {
        try await client.get("\(feedBaseURL)/\(feed.pathSegment).geojson",
                            as: GeoJSONFeatureCollectionDTO.self)
    }

    func query(_ query: EarthquakeQuery) async throws -> GeoJSONFeatureCollectionDTO {
        try await client.get(Self.buildQueryURL(base: queryBaseURL, query: query),
                            as: GeoJSONFeatureCollectionDTO.self)
    }

    func lookup(id: String) async throws -> GeoJSONFeatureCollectionDTO {
        try await client.get("\(detailBaseURL)/\(id).geojson",
                            as: GeoJSONFeatureCollectionDTO.self)
    }

    /// Build the FDSNWS URL with properly percent-encoded query items. Only
    /// non-nil filters are included.
    private static func buildQueryURL(base: String, query: EarthquakeQuery) -> String {
        var components = URLComponents(string: base)!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "format", value: "geojson"),
            URLQueryItem(name: "orderby", value: query.orderBy.rawValue),
        ]

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let start = query.startTime {
            items.append(URLQueryItem(name: "starttime", value: formatter.string(from: start)))
        }
        if let end = query.endTime {
            items.append(URLQueryItem(name: "endtime", value: formatter.string(from: end)))
        }
        if let minMag = query.minMagnitude {
            items.append(URLQueryItem(name: "minmagnitude", value: String(minMag)))
        }
        if let maxMag = query.maxMagnitude {
            items.append(URLQueryItem(name: "maxmagnitude", value: String(maxMag)))
        }
        if let minDepth = query.minDepthKm {
            items.append(URLQueryItem(name: "mindepth", value: String(minDepth)))
        }
        if let maxDepth = query.maxDepthKm {
            items.append(URLQueryItem(name: "maxdepth", value: String(maxDepth)))
        }

        components.queryItems = items
        return components.url?.absoluteString ?? base
    }
}

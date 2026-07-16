//
//  EarthquakeRepository.swift
//  MiniPi
//
//  Domain contract for the USGS Earthquakes feature. Mirrors AsteroidRepository:
//  one feed fetch, one parameterised query (filtered search), one id lookup.
//

import Foundation

/// Filter / sort parameters for the USGS FDSNWS `query` endpoint (the Search tab).
/// Optionals map straight onto optional query params; `nil` means "any".
struct EarthquakeQuery: Equatable {
    var startTime: Date?
    var endTime: Date?
    var minMagnitude: Double?
    var maxMagnitude: Double?
    var minDepthKm: Double?
    var maxDepthKm: Double?
    var orderBy: EarthquakeOrder = .time
}

enum EarthquakeOrder: String, CaseIterable {
    case time = "time"        // newest first
    case magnitude = "magnitude"
    case significance = "sig"

    var label: String {
        switch self {
        case .time: return "Newest"
        case .magnitude: return "Largest"
        case .significance: return "Significance"
        }
    }
}

protocol EarthquakeRepository {
    /// USGS summary feed (Home / Map / Watchlist default dataset).
    func fetchEarthquakes(feed: EarthquakeFeed) async -> Result<[Earthquake]>

    /// USGS FDSNWS `query` (Search). Filters are applied server-side.
    func queryEarthquakes(_ query: EarthquakeQuery) async -> Result<[Earthquake]>

    /// USGS `detail/{id}` lookup (Search by id / detail enrichment).
    func lookupEarthquake(id: String) async -> Result<Earthquake>
}

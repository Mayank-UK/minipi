//
//  Earthquake.swift
//  MiniPi
//
//  Domain model for a USGS seismic event (Earthquake feature). Used by Home
//  (recent list + stats), Map (3D globe markers), Search, Stats (charts) and the
//  Watchlist. Mirrors Asteroid: a plain value type with the derived helpers the
//  UI needs (magnitude band, coordinate, distance formatting).
//

import Foundation

/// Which USGS summary feed a dataset came from. Powers the Map window selector
/// and the Home "This Week / Today" tiles.
enum EarthquakeFeed: String, CaseIterable, Identifiable {
    case hour
    case day
    case week
    case month

    var id: String { rawValue }

    /// USGS feed path segment, e.g. `all_week`.
    var pathSegment: String { "all_\(rawValue)" }

    var title: String {
        switch self {
        case .hour: return "Last Hour"
        case .day: return "Today"
        case .week: return "This Week"
        case .month: return "This Month"
        }
    }

    /// Rough days spanned — used for label copy and as a fallback sort window.
    var daySpan: Int {
        switch self {
        case .hour: return 0
        case .day: return 1
        case .week: return 7
        case .month: return 30
        }
    }
}

/// Magnitude bucket. Drives the badge colour, the globe marker colour, the Map
/// legend and the Stats bucket charts — one place decides the band boundaries.
enum MagnitudeBand: String, CaseIterable, Identifiable {
    case micro      // < 2
    case minor      // 2 ..< 4
    case moderate   // 4 ..< 6
    case major      // >= 6

    var id: String { rawValue }

    init(magnitude: Double) {
        switch magnitude {
        case ..<2:  self = .micro
        case ..<4:  self = .minor
        case ..<6:  self = .moderate
        default:    self = .major
        }
    }

    var label: String {
        switch self {
        case .micro: return "< 2"
        case .minor: return "2 – 4"
        case .moderate: return "4 – 6"
        case .major: return "6+"
        }
    }

    /// Band boundary lower edges, for the Stats distribution charts.
    static var orderedBuckets: [(band: MagnitudeBand, range: String)] {
        [
            (.micro, "0 – 2"),
            (.minor, "2 – 4"),
            (.moderate, "4 – 6"),
            (.major, "6+"),
        ]
    }
}

/// A geographic point (latitude / longitude in degrees).
struct GeoCoordinate: Equatable {
    let latitude: Double
    let longitude: Double
}

/// A USGS seismic event.
struct Earthquake: Identifiable {
    let id: String                  // USGS event id (e.g. "us7000me69")
    let magnitude: Double?
    let magType: String?
    let place: String?              // "10km WNW of Petrolia, CA"
    let title: String?              // "M 7.2 - 10km WNW of Petrolia, CA"
    let time: Date?                 // origin time (epoch ms)
    let updated: Date?              // last update (epoch ms)
    let depthKm: Double?            // geometry.coordinates[2]
    let coordinate: GeoCoordinate?
    let isTsunami: Bool
    let alertLevel: String?         // "green" / "yellow" / "orange" / "red"
    let significance: Int?          // properties.sig
    let feltReports: Int?           // properties.felt
    let type: String?               // "earthquake" vs "quarry blast" etc.
    let url: String?                // USGS event page
    let detailUrl: String?          // detail GeoJSON endpoint

    /// The magnitude band, `.micro` when magnitude is missing.
    var magnitudeBand: MagnitudeBand {
        MagnitudeBand(magnitude: magnitude ?? 0)
    }

    /// Display magnitude to one decimal, "—" when unknown.
    var magnitudeText: String {
        magnitude.map { String(format: "%.1f", $0) } ?? "—"
    }

    /// Depth copy in kilometres.
    var depthText: String {
        depthKm.map { String(format: "%.1f km", $0) } ?? "—"
    }
}

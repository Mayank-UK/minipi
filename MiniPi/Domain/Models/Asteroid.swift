//
//  Asteroid.swift
//  MiniPi
//
//  Domain model for a NASA Near-Earth Object (Module A — NASA Asteroids).
//  Used by Home (close approaches + stats), Detail (overview), and Orbit (elements).
//

import Foundation

/// One close approach of an asteroid to Earth (or another body).
struct CloseApproach: Identifiable {
    let id = UUID()
    let date: Date?
    let epochDateMs: Int64?
    let velocityKilometersPerSecond: Double?
    let velocityKilometersPerHour: Double?
    let missDistanceKilometers: Double?
    let missDistanceLunar: Double?
    let missDistanceAstronomical: Double?
    let orbitingBody: String?
}

/// Complete Keplerian element set (a, e, i, Ω, ω, M) + epoch/period.
/// Enough to compute a body's heliocentric position at any instant (§A.4).
/// Nil when the source endpoint does not supply orbital data (e.g. the feed endpoint).
struct OrbitalElements {
    let semiMajorAxisAU: Double?          // a
    let eccentricity: Double?             // e
    let inclinationDeg: Double?           // i
    let ascendingNodeLongitudeDeg: Double?// Ω
    let perihelionArgumentDeg: Double?    // ω
    let meanAnomalyDeg: Double?           // M
    let epochOsculation: Double?          // Julian Date the elements are valid for
    let orbitalPeriodDays: Double?
    let firstObservationDate: Date?
}

/// A NASA Near-Earth Object.
struct Asteroid: Identifiable {
    let id: String                         // NeoWs `id`
    let name: String
    let designation: String?
    let absoluteMagnitudeH: Double?
    let diameterMinMeters: Double?
    let diameterMaxMeters: Double?
    let isPotentiallyHazardous: Bool
    let isSentryObject: Bool
    let closeApproaches: [CloseApproach]
    let orbitalElements: OrbitalElements?

    /// Earliest/next close approach, if any — drives the Home "Close Approaches" list.
    var nextCloseApproach: CloseApproach? {
        closeApproaches
            .filter { $0.date != nil }
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
            .first
    }
}

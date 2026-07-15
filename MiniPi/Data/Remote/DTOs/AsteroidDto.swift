//
//  AsteroidDto.swift
//  MiniPi
//
//  Codable representation of NASA NeoWs responses (Module A §A.3).
//  NASA returns many numeric fields as JSON strings, so those decode as String
//  and are parsed to Double during the DTO → domain mapping.
//

import Foundation

// MARK: - Feed wrapper

struct NeoFeedDTO: Codable {
    let elementCount: Int
    let nearEarthObjects: [String: [AsteroidDTO]]

    enum CodingKeys: String, CodingKey {
        case elementCount = "element_count"
        case nearEarthObjects = "near_earth_objects"
    }
}

// MARK: - Browse wrapper
// `neo/browse` paginates the *entire* NEO catalog (incl. `orbital_data` per body),
// so the 3D scene gets asteroids spread all around the Sun instead of clustered
// near Earth like the close-approach `feed`.

struct NeoBrowseDTO: Codable {
    let nearEarthObjects: [AsteroidDTO]

    enum CodingKeys: String, CodingKey {
        case nearEarthObjects = "near_earth_objects"
    }
}

// MARK: - Asteroid

struct AsteroidDTO: Codable {
    let id: String
    let neoReferenceId: String?
    let name: String
    let designation: String?
    let absoluteMagnitudeH: Double?
    let estimatedDiameter: EstimatedDiameterDTO?
    let isPotentiallyHazardousAsteroid: Bool?
    let isSentryObject: Bool?
    let closeApproachData: [CloseApproachDTO]?
    // Only present on the `neo/{id}` lookup endpoint, not on `feed`.
    let orbitalData: OrbitalDataDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case neoReferenceId = "neo_reference_id"
        case name
        case designation
        case absoluteMagnitudeH = "absolute_magnitude_h"
        case estimatedDiameter = "estimated_diameter"
        case isPotentiallyHazardousAsteroid = "is_potentially_hazardous_asteroid"
        case isSentryObject = "is_sentry_object"
        case closeApproachData = "close_approach_data"
        case orbitalData = "orbital_data"
    }
}

struct EstimatedDiameterDTO: Codable {
    let meters: DiameterRangeDTO?
}

struct DiameterRangeDTO: Codable {
    let min: Double?
    let max: Double?
    enum CodingKeys: String, CodingKey {
        case min = "estimated_diameter_min"
        case max = "estimated_diameter_max"
    }
}

struct CloseApproachDTO: Codable {
    let closeApproachDate: String?          // "2026-07-15"
    let epochDateCloseApproach: Int64?      // epoch ms
    let relativeVelocity: RelativeVelocityDTO?
    let missDistance: MissDistanceDTO?
    let orbitingBody: String?

    enum CodingKeys: String, CodingKey {
        case closeApproachDate = "close_approach_date"
        case epochDateCloseApproach = "epoch_date_close_approach"
        case relativeVelocity = "relative_velocity"
        case missDistance = "miss_distance"
        case orbitingBody = "orbiting_body"
    }
}

struct RelativeVelocityDTO: Codable {
    let kilometersPerSecond: String?
    let kilometersPerHour: String?
}

struct MissDistanceDTO: Codable {
    let astronomical: String?
    let lunar: String?
    let kilometers: String?
}

struct OrbitalDataDTO: Codable {
    let semiMajorAxis: String?
    let eccentricity: String?
    let inclination: String?
    let ascendingNodeLongitude: String?
    let perihelionArgument: String?
    let meanAnomaly: String?
    let epochOsculation: String?           // Julian Date (NASA sends as a string)
    let orbitalPeriod: String?
    let firstObservationDate: String?      // "1900-01-01"

    enum CodingKeys: String, CodingKey {
        case semiMajorAxis = "semi_major_axis"
        case eccentricity
        case inclination
        case ascendingNodeLongitude = "ascending_node_longitude"
        case perihelionArgument = "perihelion_argument"
        case meanAnomaly = "mean_anomaly"
        case epochOsculation = "epoch_osculation"
        case orbitalPeriod = "orbital_period"
        case firstObservationDate = "first_observation_date"
    }
}

// MARK: - DTO → Domain

extension AsteroidDTO {

    /// Shared "yyyy-MM-dd" parser used across NASA date fields.
    fileprivate static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    func toAsteroid() -> Asteroid {
        Asteroid(
            id: id,
            name: name.trimmingCharacters(in: .whitespaces),
            designation: designation,
            absoluteMagnitudeH: absoluteMagnitudeH,
            diameterMinMeters: estimatedDiameter?.meters?.min,
            diameterMaxMeters: estimatedDiameter?.meters?.max,
            isPotentiallyHazardous: isPotentiallyHazardousAsteroid ?? false,
            isSentryObject: isSentryObject ?? false,
            closeApproaches: (closeApproachData ?? []).map { $0.toCloseApproach() },
            orbitalElements: orbitalData?.toOrbitalElements()
        )
    }
}

extension CloseApproachDTO {
    func toCloseApproach() -> CloseApproach {
        CloseApproach(
            date: (closeApproachDate).flatMap { AsteroidDTO.dayFormatter.date(from: $0) }
                ?? (epochDateCloseApproach.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000.0) }),
            epochDateMs: epochDateCloseApproach,
            velocityKilometersPerSecond: relativeVelocity?.kilometersPerSecond.double,
            velocityKilometersPerHour: relativeVelocity?.kilometersPerHour.double,
            missDistanceKilometers: missDistance?.kilometers.double,
            missDistanceLunar: missDistance?.lunar.double,
            missDistanceAstronomical: missDistance?.astronomical.double,
            orbitingBody: orbitingBody
        )
    }
}

extension OrbitalDataDTO {
    func toOrbitalElements() -> OrbitalElements {
        OrbitalElements(
            semiMajorAxisAU: semiMajorAxis.double,
            eccentricity: eccentricity.double,
            inclinationDeg: inclination.double,
            ascendingNodeLongitudeDeg: ascendingNodeLongitude.double,
            perihelionArgumentDeg: perihelionArgument.double,
            meanAnomalyDeg: meanAnomaly.double,
            epochOsculation: epochOsculation.double,
            orbitalPeriodDays: orbitalPeriod.double,
            firstObservationDate: firstObservationDate.flatMap { AsteroidDTO.dayFormatter.date(from: $0) }
        )
    }
}

// MARK: - String → Double helper (NASA sends numbers as strings)

extension Optional where Wrapped == String {
    var double: Double? {
        switch self {
        case .none: return nil
        case .some(let raw):
            return Double(raw.trimmingCharacters(in: .whitespaces))
        }
    }
}

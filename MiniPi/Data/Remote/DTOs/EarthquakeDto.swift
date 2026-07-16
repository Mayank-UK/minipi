//
//  EarthquakeDto.swift
//  MiniPi
//
//  Codable representation of USGS GeoJSON responses (summary feeds, the FDSNWS
//  `query` endpoint, and the `detail/{id}` lookup all share this shape). GeoJSON
//  numbers arrive as JSON numbers (unlike NASA's string-encoded fields), so most
//  decode directly; only the optional ones are nullable.
//
//  A `FeatureCollection` wraps `features`; each `Feature` has `properties` and a
//  `geometry` whose `coordinates` are `[longitude, latitude, depthKm]`.
//

import Foundation

// MARK: - Feature collection

struct GeoJSONFeatureCollectionDTO: Codable {
    let metadata: GeoJSONMetadataDTO?
    let features: [GeoJSONFeatureDTO]
}

struct GeoJSONMetadataDTO: Codable {
    let count: Int?
    let title: String?
    /// Epoch ms when the feed was generated.
    let generated: Double?
}

// MARK: - Feature

struct GeoJSONFeatureDTO: Codable {
    /// USGS event id. Summary feeds put it here as a String; `query`/`detail` use
    /// the same field. Fall back to `net + code` when missing.
    let id: String?
    let properties: GeoJSONPropertiesDTO
    let geometry: GeoJSONGeometryDTO?
}

struct GeoJSONPropertiesDTO: Codable {
    let mag: Double?
    let magType: String?
    let place: String?
    let title: String?
    /// Epoch ms (origin time).
    let time: Double?
    /// Epoch ms (last update).
    let updated: Double?
    let url: String?
    let detail: String?
    let felt: Int?
    let cdi: Double?
    let mmi: Double?
    /// "green" / "yellow" / "orange" / "red", usually only on significant events.
    let alert: String?
    let status: String?
    let tsunami: Int?
    let sig: Int?
    let net: String?
    let code: String?
    let ids: String?
    let type: String?
}

struct GeoJSONGeometryDTO: Codable {
    let type: String?
    /// GeoJSON Point coordinates: `[longitude, latitude, depthKm]`.
    let coordinates: [Double]?
}

// MARK: - DTO → Domain

extension GeoJSONFeatureDTO {

    func toEarthquake() -> Earthquake {
        let p = properties
        let coordinate: GeoCoordinate? = {
            guard let coords = geometry?.coordinates, coords.count >= 2 else { return nil }
            return GeoCoordinate(latitude: coords[1], longitude: coords[0])
        }()
        let depth = geometry?.coordinates?.count ?? 0 >= 3 ? geometry?.coordinates?[2] : nil

        let resolvedID = id ?? (p.net.map { $0 + (p.code ?? "") }) ?? UUID().uuidString

        return Earthquake(
            id: resolvedID,
            magnitude: p.mag,
            magType: p.magType,
            place: p.place,
            title: p.title,
            time: p.time.map { Date(timeIntervalSince1970: $0 / 1000.0) },
            updated: p.updated.map { Date(timeIntervalSince1970: $0 / 1000.0) },
            depthKm: depth,
            coordinate: coordinate,
            isTsunami: (p.tsunami ?? 0) == 1,
            alertLevel: p.alert,
            significance: p.sig,
            feltReports: p.felt,
            type: p.type,
            url: p.url,
            detailUrl: p.detail
        )
    }
}

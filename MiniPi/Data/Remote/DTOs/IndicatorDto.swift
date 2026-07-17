//
//  IndicatorDto.swift
//  MiniPi
//
//  Codable DTOs for the World Bank Open Data API, plus the `toCountry()` / `toObservation()`
//  mappers into the domain models. The API needs no key and returns a 2-element top-level
//  JSON array: `[ {page meta}, [ ...records... ] ]`. That heterogeneous envelope is decoded
//  with a custom unkeyed container (read the meta, then the records array).
//
//  All optional — the WB schema is sparse (`value` is null when a country has no data for
//  an indicator/year), so the observation mapper drops null-valued rows. Aggregates
//  (region "Aggregates") are filtered out of the country list.
//

import Foundation

// MARK: - Envelope

/// Decodes the WB `[meta, [records]]` envelope into just the records of the requested type.
struct WorldBankResponseDTO<T: Decodable>: Decodable {
    let records: [T]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        // Element 0: the page-meta object. Consumed and discarded.
        _ = try container.decode(WorldBankPageMetaDTO.self)
        // Element 1: the records array.
        // Decode eagerly — the API honours a large `per_page` so everything is on page 1.
        if container.isAtEnd {
            records = []
        } else {
            records = try container.decode([T].self)
        }
    }
}

/// The page-meta object (element 0 of the WB envelope). We consume and discard it — none
/// of its fields are used — so it declares no keys and ignores everything. This also makes
/// decoding robust to the API's inconsistent typing (e.g. `per_page` is a string for small
/// values but a number for large ones), which would otherwise throw a type-mismatch error.
struct WorldBankPageMetaDTO: Decodable {}

// MARK: - Shared nested {id, value}

struct WorldBankNameValueDTO: Decodable {
    let id: String?
    let value: String?
}

// MARK: - Country (from /country)

struct WorldBankCountryDTO: Decodable {
    let id: String?
    let iso2Code: String?
    let name: String?
    let region: WorldBankNameValueDTO?
    let incomeLevel: WorldBankNameValueDTO?
    let capitalCity: String?

    enum CodingKeys: String, CodingKey {
        case id, iso2Code, name, region, incomeLevel, capitalCity
    }

    /// Map into the domain country. Returns nil for aggregate entries (regions/income
    /// groups that aren't real countries) and rows missing an id.
    func toCountry() -> Country? {
        guard let id = id?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
            return nil
        }
        // Aggregates (continents, income groups, EU, world…) carry an "Aggregates" region.
        let regionValue = region?.value?.trimmingCharacters(in: .whitespaces) ?? ""
        if regionValue.isEmpty || regionValue == "Aggregates" {
            return nil
        }
        let name = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? id
        return Country(
            id: id,
            name: name,
            iso2: iso2Code?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            region: regionValue,
            incomeLevel: incomeLevel?.value?.trimmingCharacters(in: .whitespaces) ?? "—",
            capital: capitalCity?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "—"
        )
    }
}

// MARK: - Observation (from /country/all/indicator/{code})

struct WorldBankObservationDTO: Decodable {
    let indicator: WorldBankNameValueDTO?
    let country: WorldBankNameValueDTO?
    let countryiso3code: String?
    /// WB date is a year string ("2023") for annual data.
    let date: String?
    /// Null when no data — decoded as nil.
    let value: Double?

    /// Map into a domain observation. Returns nil when there is no usable country code or
    /// the value is null. The `indicatorId` (from `indicator.id`) is carried through so a
    /// single bulk fetch can be flattened across indicators.
    func toObservation(indicatorCode: String) -> Observation? {
        guard let value else { return nil } // drop null-valued rows
        let countryId = countryiso3code?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !countryId.isEmpty else { return nil }
        let year = Int(date?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? 0
        guard year > 0 else { return nil }
        return Observation(
            countryId: countryId,
            indicatorId: indicatorCode,
            year: year,
            value: value
        )
    }
}

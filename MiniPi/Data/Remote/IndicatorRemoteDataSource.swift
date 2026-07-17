//
//  IndicatorRemoteDataSource.swift
//  MiniPi
//
//  Feature-scoped remote data source for the World Bank Open Data API. Owns the two
//  endpoint shapes behind a narrow protocol; the shared networking engine (HTTPClient +
//  interceptors) is injected — exactly like the other feature data sources.
//
//  World Bank needs no API key and no special User-Agent (like OpenRouter/USGS), so the
//  base URL is a hardcoded constant here, with no xcconfig/AppConfiguration entry.
//
//  Two endpoints:
//   - `/country`                       → the live country list (aggregates filtered in the mapper).
//   - `/country/all/indicator/{code}`  → the full yearly series for one indicator over a
//     recent window (per_page 10000 → single page). The repository keeps every year so the
//     user can pick a year.
//
//  World Bank occasionally prefixes its JSON with a UTF-8 BOM, which makes `JSONDecoder`
//  throw. The dedicated `get(_:as:)` helper below runs the request through the shared
//  engine + `guardedApiCall` (so URLError / DecodingError still map to the app's exception
//  family) and strips a leading BOM before decoding — instead of the shared
//  `HTTPClient.get(_:as:)` which would drop the whole indicator on a BOM response.
//

import Foundation

protocol IndicatorRemoteDataSource {
    /// `/country` — every country (mapper drops aggregates).
    func countries() async throws -> [Country]

    /// `/country/all/indicator/{code}` — the full yearly series for one indicator over the
    /// recent window. Null-valued rows are dropped by the mapper.
    func observations(for indicatorCode: String) async throws -> [Observation]
}

final class IndicatorRemoteDataSourceImpl: IndicatorRemoteDataSource {

    private let worldBankBaseURL = "https://api.worldbank.org/v2"
    /// Year window. WB data lags, so reach back several years to keep coverage high.
    private let dateWindow = "2015:2023"
    private let perPage = 10_000

    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func countries() async throws -> [Country] {
        let url = "\(worldBankBaseURL)/country?format=json&per_page=\(perPage)"
        let envelope = try await get(url, as: WorldBankResponseDTO<WorldBankCountryDTO>.self)
        return envelope.records.compactMap { $0.toCountry() }
    }

    func observations(for indicatorCode: String) async throws -> [Observation] {
        let encoded = indicatorCode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? indicatorCode
        let url = "\(worldBankBaseURL)/country/all/indicator/\(encoded)?format=json&per_page=\(perPage)&date=\(dateWindow)"
        let envelope = try await get(url, as: WorldBankResponseDTO<WorldBankObservationDTO>.self)
        return envelope.records.compactMap { $0.toObservation(indicatorCode: indicatorCode) }
    }

    // MARK: - Shared BOM-tolerant GET

    /// Runs a GET through the shared engine + `guardedApiCall` (preserving the app's
    /// network/decoding exception mapping), then strips a leading UTF-8 BOM before
    /// decoding. World Bank sometimes emits a BOM, which `JSONDecoder` rejects.
    private func get<T: Decodable>(_ urlString: String, as type: T.Type) async throws -> T {
        try await guardedApiCall {
            guard let url = URL(string: urlString) else {
                throw NetworkException("Invalid URL", context: urlString)
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            let response = try await self.client.send(request)
            var data = response.data
            // Strip an optional UTF-8 BOM (EF BB BF).
            if data.count >= 3, data.prefix(3) == Data([0xEF, 0xBB, 0xBF]) {
                data.removeFirst(3)
            }
            return try JSONDecoder().decode(T.self, from: data)
        }
    }
}

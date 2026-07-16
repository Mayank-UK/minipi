//
//  WeatherRemoteDataSource.swift
//  MiniPi
//
//  Feature-scoped remote data source for WeatherAPI.com. Owns only the weather
//  endpoints behind a narrow protocol; the shared networking engine (HTTPClient +
//  interceptors) is injected — exactly like EarthquakeRemoteDataSource.
//
//  The API key comes from the per-environment xcconfig → Info.plist →
//  AppConfiguration.shared.weatherApiKey. The base URL is feature-owned.
//

import Foundation

protocol WeatherRemoteDataSource {
    /// `forecast.json` — current + hourly + multi-day forecast + astronomy + air
    /// quality for one location (Home + Stats).
    func forecast(_ query: WeatherQuery) async throws -> WeatherForecastDTO

    /// `search.json` — autocomplete city results for a partial query (Home search).
    func search(_ query: String) async throws -> [WeatherSearchResultDTO]
}

final class WeatherRemoteDataSourceImpl: WeatherRemoteDataSource {

    private let weatherBaseURL = "https://api.weatherapi.com/v1"
    private let weatherApiKey = AppConfiguration.shared.weatherApiKey
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func forecast(_ query: WeatherQuery) async throws -> WeatherForecastDTO {
        let days = max(1, min(query.days, 14))
        let url = buildURL(
            path: "/forecast.json",
            items: [
                ("q", query.query),
                ("days", String(days)),
                ("aqi", "yes"),
                ("alerts", "no"),
            ]
        )
        return try await client.get(url, as: WeatherForecastDTO.self)
    }

    func search(_ query: String) async throws -> [WeatherSearchResultDTO] {
        let url = buildURL(path: "/search.json", items: [("q", query)])
        return try await client.get(url, as: [WeatherSearchResultDTO].self)
    }

    /// Compose a URL with the API key + percent-encoded query items.
    private func buildURL(path: String, items: [(String, String)]) -> String {
        var components = URLComponents(string: weatherBaseURL + path)!
        var queryItems: [URLQueryItem] = [URLQueryItem(name: "key", value: weatherApiKey)]
        for (name, value) in items {
            queryItems.append(URLQueryItem(name: name, value: value))
        }
        components.queryItems = queryItems
        return components.url?.absoluteString ?? (weatherBaseURL + path)
    }
}

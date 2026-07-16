//
//  WeatherRepository.swift
//  MiniPi
//
//  Domain contract for the WeatherAPI.com-backed Weather feature. Mirrors
//  EarthquakeRepository: one cache-backed fetch (forecast for Home + Stats), one
//  one-shot search (autocomplete), and one one-shot bulk fetch (globe city points).
//

import Foundation

/// Parameters for a `forecast.json` call. `query` is a city name or `lat,lon`
/// (or `auto:ip` for the IP-derived current location); `days` is the forecast
/// horizon (WeatherAPI free tier allows up to 3; higher tiers up to 14).
struct WeatherQuery: Equatable {
    var query: String
    var days: Int

    init(query: String, days: Int = 7) {
        self.query = query
        self.days = days
    }
}

protocol WeatherRepository {
    /// `forecast.json` — current conditions + hourly + multi-day forecast + astronomy
    /// + air quality for one location. Cache-backed (Home + Stats default dataset).
    func fetchForecast(_ query: WeatherQuery) async -> Result<WeatherForecast>

    /// `search.json` — autocomplete city results for a partial query (one-shot).
    func searchCities(query: String) async -> Result<[WeatherLocation]>
}

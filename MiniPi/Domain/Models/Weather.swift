//
//  Weather.swift
//  MiniPi
//
//  Domain models for the WeatherAPI.com-backed Weather feature. Used by Home
//  (current + hourly + 7-day forecast), Map (3D-globe city markers coloured by a
//  selected metric) and Stats (charts). Mirrors Earthquake: plain value types with
//  the derived helpers the UI needs, plus the metric colouring rules in one place.
//

import Foundation
import SwiftUI

// MARK: - Location

/// A place WeatherAPI.com can resolve — a search/autocomplete result or the
/// city attached to a forecast. `query` is the string to send back to the API to
/// reproduce the location (a city name or a `lat,lon` pair).
struct WeatherLocation: Identifiable, Equatable {
    /// Stable id: prefer the API `id`, else `name, region, country`, else lat/lon.
    let id: String
    let name: String
    let region: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?

    /// A display string ("London, United Kingdom" / "London, England").
    var displayName: String {
        [name, region, country]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    /// The query string to send back to the API. Uses `lat,lon` when coordinates
    /// are present (most precise), else the display name.
    var query: String {
        if let lat = latitude, let lon = longitude {
            return "\(lat),\(lon)"
        }
        return displayName
    }
}

// MARK: - Current conditions

struct CurrentWeather: Equatable {
    let tempC: Double?
    let feelsLikeC: Double?
    let conditionText: String?
    let conditionCode: Int?
    let humidity: Double?
    let windKph: Double?
    let windDir: String?
    let pressureMb: Double?
    let precipMm: Double?
    let cloud: Double?
    let uv: Double?
    let visibilityKm: Double?
    let gustKph: Double?
    let isDay: Bool
    let lastUpdated: Date?

    var tempText: String { tempC.map { "\(Int($0.rounded()))°" } ?? "—" }
    var feelsLikeText: String { feelsLikeC.map { "\(Int($0.rounded()))°" } ?? "—" }
    var humidityText: String { humidity.map { "\(Int($0))%" } ?? "—" }
    var windText: String { windKph.map { "\(Int($0)) km/h" } ?? "—" }
    var pressureText: String { pressureMb.map { "\(Int($0)) hPa" } ?? "—" }
    var precipText: String { precipMm.map { String(format: "%.1f mm", $0) } ?? "—" }
    var visibilityText: String { visibilityKm.map { "\(Int($0)) km" } ?? "—" }
    var uvText: String { uv.map { "\(Int($0))" } ?? "—" }
}

// MARK: - Hour forecast

struct HourForecast: Identifiable, Equatable {
    let id: String
    let time: Date?
    let tempC: Double?
    let conditionText: String?
    let conditionCode: Int?
    let chanceOfRain: Double?
    let precipMm: Double?
    let humidity: Double?
    let windKph: Double?

    var tempText: String { tempC.map { "\(Int($0.rounded()))°" } ?? "—" }
    var rainChanceText: String { chanceOfRain.map { "\(Int($0))%" } ?? "—" }
}

// MARK: - Day forecast

struct DayForecast: Identifiable, Equatable {
    let id: String
    let date: Date?
    let maxTempC: Double?
    let minTempC: Double?
    let avgTempC: Double?
    let conditionText: String?
    let conditionCode: Int?
    let dailyChanceOfRain: Double?
    let totalPrecipMm: Double?
    let maxWindKph: Double?
    let avgHumidity: Double?
    let uv: Double?
    let sunrise: String?
    let sunset: String?
    let moonPhase: String?

    var maxTempText: String { maxTempC.map { "\(Int($0.rounded()))°" } ?? "—" }
    var minTempText: String { minTempC.map { "\(Int($0.rounded()))°" } ?? "—" }
    var weekdayText: String {
        guard let date else { return "—" }
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}

// MARK: - Astronomy + Air quality

struct AstronomyInfo: Equatable {
    let sunrise: String?
    let sunset: String?
    let moonrise: String?
    let moonset: String?
    let moonPhase: String?
}

struct AirQuality: Equatable {
    let pm2_5: Double?
    let pm10: Double?
    let no2: Double?
    let so2: Double?
    let o3: Double?
    let co: Double?
    let usEpaIndex: Int?
    let usEpaCategory: String?
}

// MARK: - Forecast envelope

/// The full `forecast.json` payload mapped to domain — one call powers Home + Stats.
struct WeatherForecast: Equatable {
    let location: WeatherLocation
    let current: CurrentWeather
    let hours: [HourForecast]
    let days: [DayForecast]
    let astronomy: AstronomyInfo?
    let airQuality: AirQuality?

    /// Today's day forecast, if present.
    var today: DayForecast? { days.first }
}

// MARK: - Map layer + colouring

/// The metric the Map tab colours its OpenWeatherMap tile overlay by. Owns the
/// metric's display metadata, its OWM tile-layer name, and the colour ramp used by
/// the on-screen legend.
enum WeatherMetric: String, CaseIterable, Identifiable {
    case temperature
    case precipitation
    case wind
    case humidity
    case cloud

    var id: String { rawValue }

    var title: String {
        switch self {
        case .temperature: return "Temperature"
        case .precipitation: return "Precipitation"
        case .wind: return "Wind"
        case .humidity: return "Humidity"
        case .cloud: return "Cloud"
        }
    }

    var icon: String {
        switch self {
        case .temperature: return "thermometer"
        case .precipitation: return "cloud.rain"
        case .wind: return "wind"
        case .humidity: return "humidity"
        case .cloud: return "cloud"
        }
    }

    var unit: String {
        switch self {
        case .temperature: return "°C"
        case .precipitation: return "mm"
        case .wind: return "km/h"
        case .humidity: return "%"
        case .cloud: return "%"
        }
    }

    /// Ramp bounds used both to normalise marker size and to draw the legend.
    var range: ClosedRange<Double> {
        switch self {
        case .temperature: return -30 ... 45
        case .precipitation: return 0 ... 10
        case .wind: return 0 ... 60
        case .humidity: return 0 ... 100
        case .cloud: return 0 ... 100
        }
    }

    /// The OpenWeatherMap tile-layer name for the Map tab overlay (`nil` for metrics
    /// OWM doesn't expose as a free tile layer, e.g. humidity).
    var owmLayer: String? {
        switch self {
        case .temperature: return "temp_new"
        case .precipitation: return "precipitation"
        case .wind: return "wind_new"
        case .cloud: return "clouds_new"
        case .humidity: return nil
        }
    }

    /// The metrics exposed as map layers (Temperature / Precipitation / Cloud / Wind).
    static let mapLayers: [WeatherMetric] = [.temperature, .precipitation, .cloud, .wind]

    /// Colour for a raw metric value. Pure function (RGB only) — does not read the
    /// SwiftUI environment, so it is safe to call off the view hierarchy (globe
    /// Coordinator) and from parent computed properties. Mirrors the static-helper
    /// rule established by `MagnitudeBadge.color(for:in:)`.
    static func color(forValue value: Double, metric: WeatherMetric) -> Color {
        let lo = metric.range.lowerBound
        let hi = metric.range.upperBound
        let t = max(0, min(1, (value - lo) / max(hi - lo, 1)))

        switch metric {
        case .temperature:
            // Cold blue → cyan → green → yellow → red.
            return Self.rampColor(stops: [
                (0.00, (0.20, 0.45, 0.95)),
                (0.30, (0.20, 0.78, 0.92)),
                (0.55, (0.30, 0.80, 0.45)),
                (0.75, (0.98, 0.83, 0.25)),
                (1.00, (0.94, 0.27, 0.27)),
            ], at: t)
        case .precipitation:
            return Self.rampColor(stops: [
                (0.00, (0.35, 0.55, 0.85)),
                (0.50, (0.20, 0.50, 0.90)),
                (1.00, (0.10, 0.25, 0.75)),
            ], at: t)
        case .wind:
            return Self.rampColor(stops: [
                (0.00, (0.30, 0.80, 0.45)),
                (0.50, (0.98, 0.83, 0.25)),
                (1.00, (0.94, 0.27, 0.27)),
            ], at: t)
        case .humidity, .cloud:
            return Self.rampColor(stops: [
                (0.00, (0.96, 0.78, 0.40)),
                (0.50, (0.45, 0.70, 0.90)),
                (1.00, (0.25, 0.45, 0.85)),
            ], at: t)
        }
    }

    /// Linear-RGB interpolation across an ordered list of (position, rgb) stops.
    private static func rampColor(stops: [(Double, (Double, Double, Double))], at t: Double) -> Color {
        guard t <= stops.first!.0 else { return Color(rgb: stops.first!.1) }
        guard t >= stops.last!.0 else { return Color(rgb: stops.last!.1) }
        for i in 1..<stops.count {
            if t <= stops[i].0 {
                let (p0, c0) = stops[i - 1]
                let (p1, c1) = stops[i]
                let local = (t - p0) / max(p1 - p0, 0.0001)
                let r = c0.0 + (c1.0 - c0.0) * local
                let g = c0.1 + (c1.1 - c0.1) * local
                let b = c0.2 + (c1.2 - c0.2) * local
                return Color(rgb: (r, g, b))
            }
        }
        return Color(rgb: stops.last!.1)
    }
}

private extension Color {
    init(rgb: (Double, Double, Double)) {
        self.init(red: rgb.0, green: rgb.1, blue: rgb.2)
    }
}

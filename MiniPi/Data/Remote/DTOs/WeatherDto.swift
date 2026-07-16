//
//  WeatherDto.swift
//  MiniPi
//
//  Codable representation of WeatherAPI.com responses: `forecast.json` (current +
//  hours + days + astronomy + air quality), `search.json` (city autocomplete, array
//  root) and `current.json` (globe points). The three endpoints share `location` /
//  `current` / `condition` shapes, so the nested DTOs are reused.
//
//  Dates arrive as strings ("2024-01-01" / "2024-01-01 12:00") or epoch seconds; the
//  to-domain mapping parses them into `Date`. The air-quality keys use hyphens
//  (`us-epa-index`, `gb-defra-index`) and `pm2_5`, so that DTO carries CodingKeys.
//

import Foundation

// MARK: - Shared nested DTOs

struct WeatherLocationDTO: Codable {
    var id: Int? = nil
    var name: String? = nil
    var region: String? = nil
    var country: String? = nil
    var lat: Double? = nil
    var lon: Double? = nil
    var localtimeEpoch: Double? = nil
    var localtime: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, name, region, country, lat, lon
        case localtimeEpoch = "localtime_epoch"
        case localtime
    }
}

struct WeatherConditionDTO: Codable {
    let text: String?
    let icon: String?
    let code: Int?
}

struct WeatherCurrentDTO: Codable {
    var lastUpdatedEpoch: Double? = nil
    var lastUpdated: String? = nil
    var tempC: Double? = nil
    var isDay: Int? = nil
    var condition: WeatherConditionDTO? = nil
    var windKph: Double? = nil
    var windDegree: Double? = nil
    var windDir: String? = nil
    var pressureMb: Double? = nil
    var precipMm: Double? = nil
    var humidity: Double? = nil
    var cloud: Double? = nil
    var feelslikeC: Double? = nil
    var visKm: Double? = nil
    var uv: Double? = nil
    var gustKph: Double? = nil
    var airQuality: WeatherAirQualityDTO? = nil

    enum CodingKeys: String, CodingKey {
        case lastUpdatedEpoch = "last_updated_epoch"
        case lastUpdated = "last_updated"
        case tempC = "temp_c"
        case isDay = "is_day"
        case condition
        case windKph = "wind_kph"
        case windDegree = "wind_degree"
        case windDir = "wind_dir"
        case pressureMb = "pressure_mb"
        case precipMm = "precip_mm"
        case humidity, cloud
        case feelslikeC = "feelslike_c"
        case visKm = "vis_km"
        case uv
        case gustKph = "gust_kph"
        case airQuality = "air_quality"
    }
}

struct WeatherAirQualityDTO: Codable {
    let co: Double?
    let no2: Double?
    let o3: Double?
    let so2: Double?
    let pm2_5: Double?
    let pm10: Double?
    let usEpaIndex: Int?

    enum CodingKeys: String, CodingKey {
        case co, no2, o3, so2, pm2_5, pm10
        case usEpaIndex = "us-epa-index"
    }
}

// MARK: - forecast.json

struct WeatherForecastDTO: Codable {
    let location: WeatherLocationDTO?
    let current: WeatherCurrentDTO?
    let forecast: WeatherForecastContainerDTO?
}

struct WeatherForecastContainerDTO: Codable {
    let forecastday: [WeatherForecastDayDTO]?
}

struct WeatherForecastDayDTO: Codable {
    let date: String?
    let dateEpoch: Double?
    let day: WeatherDayDTO?
    let astro: WeatherAstroDTO?
    let hour: [WeatherHourDTO]?
}

struct WeatherDayDTO: Codable {
    let maxtempC: Double?
    let mintempC: Double?
    let avgtempC: Double?
    let maxwindKph: Double?
    let totalprecipMm: Double?
    let avghumidity: Double?
    let dailyChanceOfRain: Double?
    let dailyChanceOfSnow: Double?
    let condition: WeatherConditionDTO?
    let uv: Double?

    enum CodingKeys: String, CodingKey {
        case maxtempC = "maxtemp_c"
        case mintempC = "mintemp_c"
        case avgtempC = "avgtemp_c"
        case maxwindKph = "maxwind_kph"
        case totalprecipMm = "totalprecip_mm"
        case avghumidity
        case dailyChanceOfRain = "daily_chance_of_rain"
        case dailyChanceOfSnow = "daily_chance_of_snow"
        case condition, uv
    }
}

struct WeatherAstroDTO: Codable {
    let sunrise: String?
    let sunset: String?
    let moonrise: String?
    let moonset: String?
    let moonPhase: String?

    enum CodingKeys: String, CodingKey {
        case sunrise, sunset, moonrise, moonset
        case moonPhase = "moon_phase"
    }
}

struct WeatherHourDTO: Codable {
    let timeEpoch: Double?
    let time: String?
    let tempC: Double?
    let isDay: Int?
    let condition: WeatherConditionDTO?
    let windKph: Double?
    let humidity: Double?
    let chanceOfRain: Double?
    let precipMm: Double?
    let cloud: Double?

    enum CodingKeys: String, CodingKey {
        case timeEpoch = "time_epoch"
        case time
        case tempC = "temp_c"
        case isDay = "is_day"
        case condition
        case windKph = "wind_kph"
        case humidity
        case chanceOfRain = "chance_of_rain"
        case precipMm = "precip_mm"
        case cloud
    }
}

// MARK: - search.json (array root)

struct WeatherSearchResultDTO: Codable {
    let id: Int?
    let name: String?
    let region: String?
    let country: String?
    let lat: Double?
    let lon: Double?
}

// MARK: - DTO → Domain

extension WeatherLocationDTO {
    func toLocation() -> WeatherLocation {
        let name = name ?? "Unknown"
        let resolvedID: String = {
            if let id { return String(id) }
            return [name, region, country]
                .compactMap { $0 }
                .joined(separator: ",")
                .lowercased()
                .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? name
        }()
        return WeatherLocation(
            id: resolvedID,
            name: name,
            region: region,
            country: country,
            latitude: lat,
            longitude: lon
        )
    }
}

extension WeatherCurrentDTO {
    func toCurrent() -> CurrentWeather {
        CurrentWeather(
            tempC: tempC,
            feelsLikeC: feelslikeC,
            conditionText: condition?.text,
            conditionCode: condition?.code,
            humidity: humidity,
            windKph: windKph,
            windDir: windDir,
            pressureMb: pressureMb,
            precipMm: precipMm,
            cloud: cloud,
            uv: uv,
            visibilityKm: visKm,
            gustKph: gustKph,
            isDay: (isDay ?? 1) == 1,
            lastUpdated: lastUpdatedEpoch.map { Date(timeIntervalSince1970: $0) }
        )
    }
}

extension WeatherHourDTO {
    func toHour() -> HourForecast {
        HourForecast(
            id: timeEpoch.map { String(Int($0)) } ?? (time ?? UUID().uuidString),
            time: timeEpoch.map { Date(timeIntervalSince1970: $0) }
                ?? Self.parseDateTime(time),
            tempC: tempC,
            conditionText: condition?.text,
            conditionCode: condition?.code,
            chanceOfRain: chanceOfRain,
            precipMm: precipMm,
            humidity: humidity,
            windKph: windKph
        )
    }

    /// WeatherAPI sends "2024-01-01 12:00"; fall back to epoch when present.
    static func parseDateTime(_ value: String?) -> Date? {
        guard let value else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: value)
    }
}

extension WeatherDayDTO {
    func toDay(id: String, date: Date?, astro: WeatherAstroDTO?) -> DayForecast {
        DayForecast(
            id: id,
            date: date,
            maxTempC: maxtempC,
            minTempC: mintempC,
            avgTempC: avgtempC,
            conditionText: condition?.text,
            conditionCode: condition?.code,
            dailyChanceOfRain: dailyChanceOfRain,
            totalPrecipMm: totalprecipMm,
            maxWindKph: maxwindKph,
            avgHumidity: avghumidity,
            uv: uv,
            sunrise: astro?.sunrise,
            sunset: astro?.sunset,
            moonPhase: astro?.moonPhase
        )
    }

    static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: value)
    }
}

extension WeatherForecastDTO {
    func toForecast() -> WeatherForecast {
        let location = (location ?? WeatherLocationDTO()).toLocation()

        let dayDTOs = forecast?.forecastday ?? []
        let days: [DayForecast] = dayDTOs.enumerated().compactMap { index, fd in
            guard let day = fd.day else { return nil }
            return day.toDay(
                id: "\(location.id)-\(index)-\(fd.date ?? "")",
                date: fd.dateEpoch.map { Date(timeIntervalSince1970: $0) }
                    ?? WeatherDayDTO.parseDate(fd.date),
                astro: fd.astro
            )
        }

        let hours: [HourForecast] = dayDTOs.flatMap { $0.hour ?? [] }.map { $0.toHour() }

        let astronomy = dayDTOs.first?.astro.map {
            AstronomyInfo(
                sunrise: $0.sunrise,
                sunset: $0.sunset,
                moonrise: $0.moonrise,
                moonset: $0.moonset,
                moonPhase: $0.moonPhase
            )
        }

        let airQuality = current?.airQuality.map {
            AirQuality(
                pm2_5: $0.pm2_5,
                pm10: $0.pm10,
                no2: $0.no2,
                so2: $0.so2,
                o3: $0.o3,
                co: $0.co,
                usEpaIndex: $0.usEpaIndex,
                usEpaCategory: Self.epaCategory(for: $0.usEpaIndex)
            )
        }

        return WeatherForecast(
            location: location,
            current: (current ?? WeatherCurrentDTO()).toCurrent(),
            hours: hours,
            days: days,
            astronomy: astronomy,
            airQuality: airQuality
        )
    }

    /// US EPA AQI band → category label (0 Good … 5+ Hazardous).
    private static func epaCategory(for index: Int?) -> String? {
        guard let index else { return nil }
        switch index {
        case ...1: return "Good"
        case 2: return "Moderate"
        case 3: return "Unhealthy (Sensitive)"
        case 4: return "Unhealthy"
        case 5: return "Very Unhealthy"
        default: return "Hazardous"
        }
    }
}

extension WeatherSearchResultDTO {
    func toLocation() -> WeatherLocation {
        WeatherLocationDTO(
            id: id, name: name, region: region, country: country, lat: lat, lon: lon,
            localtimeEpoch: nil, localtime: nil
        ).toLocation()
    }
}

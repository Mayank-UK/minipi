//
//  WeatherViewModel.swift
//  MiniPi
//
//  WeatherAPI.com-backed Weather feature. Mirrors EarthquakeViewModel: isLoading /
//  currentFailure / forecast dataset, plus the tab selection (Home · Map · Stats)
//  and the server-backed city search (debounced).
//
//  Default location is resolved from the device GPS (LocationService). GPS gives the
//  true current location, unlike WeatherAPI's `auto:ip` which only resolves the ISP's
//  registered hub. If the user denies location permission (or the fix fails), it
//  falls back to `auto:ip`. A manually searched city always overrides, and persists.
//

import Foundation
import FactoryKit
import SwiftUI
import Combine
import CoreLocation

@MainActor
class WeatherViewModel: ObservableObject {

    private let logger: AppLoggerProtocol
    private let fetchForecastUseCase: FetchForecastUseCase
    private let searchCitiesUseCase: SearchCitiesUseCase
    let cityStore: WeatherCityStore
    let locationService: LocationService

    // MARK: - Forecast (Home + Stats)
    @Published var forecast: WeatherForecast?
    @Published var isLoading: Bool = false
    @Published var currentFailure: Failure?

    // MARK: - Tab + location resolution
    @Published var selectedTab: WeatherTab = .home
    @Published var selectedCity: WeatherLocation?
    /// True while waiting for a GPS fix (or the permission prompt) before the first load.
    @Published var locating: Bool = false
    private var userPickedCity: Bool = false

    /// True when the active location is GPS/auto (not a manually chosen city).
    var isAutoLocation: Bool { !userPickedCity }

    // MARK: - Search (Home)
    @Published var searchQuery: String = ""
    @Published var searchResults: [WeatherLocation] = []
    @Published var isSearching: Bool = false
    @Published var searchFailure: Failure?

    // MARK: - Map
    @Published var selectedLayer: WeatherMetric = .temperature

    private var hasLoadedForecast = false
    private var searchTask: Task<Void, Never>?

    init(
        logger: AppLoggerProtocol = Container.shared.viewModelLogger(),
        fetchForecast: FetchForecastUseCase,
        searchCities: SearchCitiesUseCase,
        cityStore: WeatherCityStore,
        locationService: LocationService
    ) {
        self.logger = logger
        self.fetchForecastUseCase = fetchForecast
        self.searchCitiesUseCase = searchCities
        self.cityStore = cityStore
        self.locationService = locationService

        logger.info("WeatherViewModel initialized")
    }

    // MARK: - Bootstrap / location resolution (Home + Stats)

    var activeQuery: String { cityStore.query }

    /// Resolve the default location, then load. On a real device this uses GPS; on the
    /// simulator it uses the simulated location (set via Features → Location). Falls
    /// back to `auto:ip` if permission is denied or the fix times out.
    func bootstrap() async {
        if userPickedCity {
            await loadForecast(force: false)
            return
        }
        if hasLoadedForecast { return }

        locating = true
        locationService.request()

        // Poll for a resolution (coords arrive, or permission is denied). Give the
        // permission prompt plenty of time on first launch.
        let deadline = Date().addingTimeInterval(25)
        while Date() < deadline {
            if Task.isCancelled { locating = false; return }
            if let coord = locationService.coordinates {
                cityStore.set(String(format: "%.4f,%.4f", coord.latitude, coord.longitude))
                locating = false
                logger.info("Resolved GPS location: \(coord.latitude), \(coord.longitude)")
                await loadForecast(force: true)
                return
            }
            let status = locationService.authorizationStatus
            if status == .denied || status == .restricted || locationService.failed {
                locating = false
                cityStore.resetToAutoIP()
                logger.info("Location unavailable — falling back to auto:ip")
                await loadForecast(force: true)
                return
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }

        // Timeout → auto:ip.
        locating = false
        cityStore.resetToAutoIP()
        logger.info("Location timed out — falling back to auto:ip")
        await loadForecast(force: true)
    }

    func loadForecast(force: Bool = false) async {
        if isLoading { return }
        if hasLoadedForecast && !force { return }

        isLoading = true
        currentFailure = nil

        let query = WeatherQuery(query: activeQuery, days: 7)
        logger.info("Loading forecast for \(query.query)")

        let result = await fetchForecastUseCase.execute(query)

        switch result {
        case .success(let forecast):
            self.forecast = forecast
            self.selectedCity = forecast.location
            self.hasLoadedForecast = true
            logger.info("Loaded forecast for \(forecast.location.name)")
        case .failure(let failure):
            self.currentFailure = failure
            logger.error("Failed to load forecast: \(failure.localizedDescription)")
        }

        isLoading = false
    }

    func clearError() {
        currentFailure = nil
    }

    // MARK: - City selection (search result → reload)

    /// Replace the active city and reload the forecast for it.
    func selectCity(_ location: WeatherLocation) {
        searchQuery = ""
        searchResults = []
        userPickedCity = true
        locating = false
        cityStore.set(location.query)
        selectedCity = location
        hasLoadedForecast = false
        Task { await loadForecast(force: true) }
    }

    /// Drop the chosen city and re-resolve the device location.
    func resetToAutoLocation() {
        searchQuery = ""
        searchResults = []
        userPickedCity = false
        selectedCity = nil
        hasLoadedForecast = false
        Task { await bootstrap() }
    }

    // MARK: - Search (server autocomplete, debounced)

    /// Schedule a debounced autocomplete search. Cancels any pending/in-flight search
    /// so only the latest query wins. The first keystroke after a pause pays the
    /// debounce; explicit drill-downs can pass `immediate: true`.
    func scheduleSearch(immediate: Bool = false) {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchTask?.cancel()
            searchResults = []
            isSearching = false
            return
        }

        searchTask?.cancel()
        searchTask = Task { [weak self] in
            guard let self else { return }
            if !immediate {
                try? await Task.sleep(nanoseconds: 350_000_000)
                if Task.isCancelled { return }
            }
            await self.performSearch(query: query)
        }
    }

    private func performSearch(query: String) async {
        if isSearching { return }
        isSearching = true
        searchFailure = nil

        logger.info("Running city search for \(query)")
        let result = await searchCitiesUseCase.execute(query: query)

        if Task.isCancelled {
            isSearching = false
            return
        }

        switch result {
        case .success(let cities):
            self.searchResults = cities
            logger.info("City search returned \(cities.count) results")
        case .failure(let failure):
            self.searchFailure = failure
            logger.error("City search failed: \(failure.localizedDescription)")
        }

        isSearching = false
    }

    func clearSearchError() {
        searchFailure = nil
    }

    // MARK: - Derived stats (Home + Stats)

    /// Hourly series for "now" onward (next ~24h), used by Home hourly + Stats trend.
    var upcomingHours: [HourForecast] {
        let now = Date()
        return (forecast?.hours ?? [])
            .filter { ($0.time ?? .distantPast) >= now.addingTimeInterval(-3600) }
            .prefix(24)
            .map { $0 }
    }

    /// A condensed hourly slice for the Home horizontal forecast (next ~12 slots).
    var homeHourly: [HourForecast] {
        Array(upcomingHours.prefix(12))
    }

    /// Min/max temperature across the 7-day window.
    var weekTempRange: (min: Double, max: Double)? {
        let days = forecast?.days ?? []
        let mins = days.compactMap { $0.minTempC }
        let maxs = days.compactMap { $0.maxTempC }
        guard let lo = mins.min(), let hi = maxs.max() else { return nil }
        return (lo, hi)
    }

    /// Total precipitation (mm) across the forecast window.
    var totalPrecipitation: Double {
        (forecast?.days ?? []).compactMap { $0.totalPrecipMm }.reduce(0, +)
    }

    /// Max wind (km/h) across the forecast window.
    var maxWind: Double {
        (forecast?.days ?? []).compactMap { $0.maxWindKph }.max() ?? 0
    }

    /// Average humidity across the forecast window.
    var averageHumidity: Double {
        let vals = (forecast?.days ?? []).compactMap { $0.avgHumidity }
        guard !vals.isEmpty else { return 0 }
        return vals.reduce(0, +) / Double(vals.count)
    }

    /// The active city's coordinate (for the Map tab's pin + region), if known.
    var activeCoordinate: CLLocationCoordinate2D? {
        guard let lat = forecast?.location.latitude,
              let lon = forecast?.location.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Tab model

enum WeatherTab: Hashable, CaseIterable {
    case home, map, stats

    var title: String {
        switch self {
        case .home: return "Home"
        case .map: return "Map"
        case .stats: return "Stats"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .map: return "map.fill"
        case .stats: return "chart.bar.fill"
        }
    }
}

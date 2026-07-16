//
//  WeatherCityStore.swift
//  MiniPi
//
//  Persisted "last selected city" for the Weather Home tab. Backed by UserDefaults
//  so the chosen city survives an app restart — mirrors FavoritesStore /
//  EarthquakeWatchlistStore in shape (Combine-ObservableObject) but stores a single
//  query string rather than a list. The app's main DB is in-memory (see AppDatabase
//  header), so this tiny dedicated store is the lightest persistent option.
//
//  The default query is "auto:ip" (WeatherAPI's IP-derived current location), so
//  the Home tab shows current-location weather before the user picks a city.
//

import Foundation
import Combine

final class WeatherCityStore: ObservableObject {

    /// The last query the user selected (city name / `lat,lon`). Published so the
    /// Home tab can react if the store is mutated elsewhere.
    @Published private(set) var query: String

    private let defaults: UserDefaults
    private let key = "minipi.weather.cityQuery"

    /// Sentinel the Home tab sends when it should fall back to the IP location.
    static let autoIP = "auto:ip"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: key)
        self.query = (stored?.isEmpty == false) ? stored! : Self.autoIP
    }

    var isAutoIP: Bool { query == Self.autoIP }

    /// Persist a new city query (e.g. from a search result's `query`).
    func set(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = trimmed.isEmpty ? Self.autoIP : trimmed
        guard next != self.query else { return }
        self.query = next
        defaults.set(next, forKey: key)
    }

    /// Reset to the IP-derived current location.
    func resetToAutoIP() {
        set(Self.autoIP)
    }
}

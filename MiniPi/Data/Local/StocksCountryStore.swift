//
//  StocksCountryStore.swift
//  MiniPi
//
//  Persisted "last selected country" for the Stocks Home tab. Backed by UserDefaults
//  so the chosen market survives an app restart — mirrors WeatherCityStore in shape
//  (Combine-ObservableObject) but stores a single ISO country code rather than a
//  query string. The default is the device region (Locale.current.region), falling
//  back to "US" if unresolved / not a known market.
//

import Foundation
import Combine

final class StocksCountryStore: ObservableObject {

    /// The last country code the user selected. Published so the Home tab can react
    /// if the store is mutated elsewhere.
    @Published private(set) var countryCode: String

    private let defaults: UserDefaults
    private let key = "minipi.stocks.countryCode"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let stored = defaults.string(forKey: key), !stored.isEmpty {
            self.countryCode = stored
        } else {
            self.countryCode = Self.resolveDefaultCountry()
        }
    }

    /// Persist a new country code (e.g. from the picker).
    func set(_ code: String) {
        let next = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !next.isEmpty, next != countryCode else { return }
        countryCode = next
        defaults.set(next, forKey: key)
    }

    /// The device region, mapped to a market we cover (else "US").
    private static func resolveDefaultCountry() -> String {
        let region = Locale.current.region?.identifier
        guard let region else { return "US" }
        let known = StockUniverse.pickerRegions.map { $0.code }
        return known.contains(region.uppercased()) ? region.uppercased() : "US"
    }
}

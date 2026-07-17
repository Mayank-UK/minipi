//
//  StocksWatchlistStore.swift
//  MiniPi
//
//  Persisted watchlist for the Stocks "Watchlist" tab. Backed by UserDefaults so
//  saved instruments survive an app restart — mirrors EarthquakeWatchlistStore
//  exactly. Stores a Codable slice (enough to render a row + detail after relaunch
//  when live quotes aren't loaded yet).
//

import Foundation
import Combine

/// A Codable slice of a `StockSymbol` + its last seen quote: enough to render a
/// Watchlist row and a detail header after relaunch.
struct StockSnapshot: Codable, Identifiable, Equatable {
    let id: String
    let symbol: String
    let displaySymbol: String
    let description: String
    let type: String        // StockType raw value
    let lastPrice: Double?
    let changePercent: Double?
    let currency: String?
    let savedEpoch: Double
}

final class StocksWatchlistStore: ObservableObject {

    @Published private(set) var snapshots: [StockSnapshot] = []

    private let defaults: UserDefaults
    private let key = "minipi.stocks.watchlist"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.snapshots = load()
    }

    // MARK: - Access

    func contains(id: String) -> Bool {
        snapshots.contains { $0.id == id }
    }

    /// Adds the symbol (with its quote) if not already saved, else removes it.
    func toggle(symbol: StockSymbol, quote: StockQuote?, currency: String?) {
        if let index = snapshots.firstIndex(where: { $0.id == symbol.id }) {
            snapshots.remove(at: index)
        } else {
            snapshots.append(Self.snapshot(from: symbol, quote: quote, currency: currency))
        }
        persist()
    }

    func remove(id: String) {
        snapshots.removeAll { $0.id == id }
        persist()
    }

    /// Refresh a saved snapshot's latest quote without changing order.
    func updateQuote(for id: String, quote: StockQuote) {
        guard let index = snapshots.firstIndex(where: { $0.id == id }) else { return }
        var snap = snapshots[index]
        snap = StockSnapshot(
            id: snap.id, symbol: snap.symbol, displaySymbol: snap.displaySymbol,
            description: snap.description, type: snap.type,
            lastPrice: quote.current, changePercent: quote.changePercent,
            currency: snap.currency, savedEpoch: snap.savedEpoch
        )
        snapshots[index] = snap
        persist()
    }

    /// The raw symbols to re-quote on the Watchlist tab.
    var symbols: [StockSymbol] {
        snapshots.map {
            StockSymbol(
                id: $0.id, symbol: $0.symbol, displaySymbol: $0.displaySymbol,
                description: $0.description, type: StockType(rawValue: $0.type) ?? .other,
                exchange: nil, currency: $0.currency, country: nil
            )
        }
    }

    // MARK: - Snapshot → from live types

    private static func snapshot(from symbol: StockSymbol, quote: StockQuote?, currency: String?) -> StockSnapshot {
        StockSnapshot(
            id: symbol.id,
            symbol: symbol.symbol,
            displaySymbol: symbol.displaySymbol,
            description: symbol.description,
            type: symbol.type.rawValue,
            lastPrice: quote?.current,
            changePercent: quote?.changePercent,
            currency: currency ?? symbol.currency,
            savedEpoch: Date().timeIntervalSince1970
        )
    }

    // MARK: - Persistence

    private func load() -> [StockSnapshot] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([StockSnapshot].self, from: data)) ?? []
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(snapshots) {
            defaults.set(data, forKey: key)
        }
    }
}

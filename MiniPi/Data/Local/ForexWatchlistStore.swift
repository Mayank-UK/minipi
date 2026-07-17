//
//  ForexWatchlistStore.swift
//  MiniPi
//
//  Persisted watchlist for the Forex "Watchlist" tab. Backed by UserDefaults so saved
//  pairs survive an app restart — mirrors StocksWatchlistStore exactly. Stores a
//  Codable slice (enough to render a row + detail after relaunch when live rates
//  aren't loaded yet).
//

import Foundation
import Combine

/// A Codable slice of a `ForexPair` + its last seen quote: enough to render a Watchlist
/// row and a detail header after relaunch.
struct ForexSnapshot: Codable, Identifiable, Equatable {
    let id: String             // Yahoo symbol, e.g. "EURUSD=X"
    let base: String           // "EUR"
    let quote: String          // "USD"
    let description: String    // "Euro / US Dollar"
    let lastRate: Double?
    let changePercent: Double?
    let savedEpoch: Double
}

final class ForexWatchlistStore: ObservableObject {

    @Published private(set) var snapshots: [ForexSnapshot] = []

    private let defaults: UserDefaults
    private let key = "minipi.forex.watchlist"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.snapshots = load()
    }

    // MARK: - Access

    func contains(id: String) -> Bool {
        snapshots.contains { $0.id == id }
    }

    /// Adds the pair (with its quote) if not already saved, else removes it.
    func toggle(pair: ForexPair, quote: ForexQuote?) {
        if let index = snapshots.firstIndex(where: { $0.id == pair.id }) {
            snapshots.remove(at: index)
        } else {
            snapshots.append(Self.snapshot(from: pair, quote: quote))
        }
        persist()
    }

    func remove(id: String) {
        snapshots.removeAll { $0.id == id }
        persist()
    }

    /// Refresh a saved snapshot's latest rate without changing order.
    func updateQuote(for id: String, quote: ForexQuote) {
        guard let index = snapshots.firstIndex(where: { $0.id == id }) else { return }
        var snap = snapshots[index]
        snap = ForexSnapshot(
            id: snap.id, base: snap.base, quote: snap.quote, description: snap.description,
            lastRate: quote.rate, changePercent: quote.changePercent,
            savedEpoch: snap.savedEpoch
        )
        snapshots[index] = snap
        persist()
    }

    /// The raw pairs to re-quote on the Watchlist tab.
    var pairs: [ForexPair] {
        snapshots.map {
            ForexPair(id: $0.id, symbol: $0.id, base: $0.base, quote: $0.quote, description: $0.description)
        }
    }

    // MARK: - Snapshot → from live types

    private static func snapshot(from pair: ForexPair, quote: ForexQuote?) -> ForexSnapshot {
        ForexSnapshot(
            id: pair.id,
            base: pair.base,
            quote: pair.quote,
            description: pair.description,
            lastRate: quote?.rate,
            changePercent: quote?.changePercent,
            savedEpoch: Date().timeIntervalSince1970
        )
    }

    // MARK: - Persistence

    private func load() -> [ForexSnapshot] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([ForexSnapshot].self, from: data)) ?? []
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(snapshots) {
            defaults.set(data, forKey: key)
        }
    }
}

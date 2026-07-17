//
//  CryptoWatchlistStore.swift
//  MiniPi
//
//  Persisted watchlist for the Crypto "Watchlist" tab. Backed by UserDefaults so saved
//  coins survive an app restart — mirrors ForexWatchlistStore exactly. Stores a
//  Codable slice (enough to render a row + detail after relaunch when live prices
//  aren't loaded yet).
//

import Foundation
import Combine

/// A Codable slice of a `CryptoCoin` + its last seen quote: enough to render a Watchlist
/// row and a detail header after relaunch.
struct CryptoSnapshot: Codable, Identifiable, Equatable {
    let id: String             // Yahoo symbol, e.g. "BTC-USD"
    let base: String           // "BTC"
    let quote: String          // "USD"
    let description: String    // "Bitcoin"
    let lastPrice: Double?
    let changePercent: Double?
    let savedEpoch: Double
}

final class CryptoWatchlistStore: ObservableObject {

    @Published private(set) var snapshots: [CryptoSnapshot] = []

    private let defaults: UserDefaults
    private let key = "minipi.crypto.watchlist"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.snapshots = load()
    }

    // MARK: - Access

    func contains(id: String) -> Bool {
        snapshots.contains { $0.id == id }
    }

    /// Adds the coin (with its quote) if not already saved, else removes it.
    func toggle(coin: CryptoCoin, quote: CryptoQuote?) {
        if let index = snapshots.firstIndex(where: { $0.id == coin.id }) {
            snapshots.remove(at: index)
        } else {
            snapshots.append(Self.snapshot(from: coin, quote: quote))
        }
        persist()
    }

    func remove(id: String) {
        snapshots.removeAll { $0.id == id }
        persist()
    }

    /// Refresh a saved snapshot's latest price without changing order.
    func updateQuote(for id: String, quote: CryptoQuote) {
        guard let index = snapshots.firstIndex(where: { $0.id == id }) else { return }
        var snap = snapshots[index]
        snap = CryptoSnapshot(
            id: snap.id, base: snap.base, quote: snap.quote, description: snap.description,
            lastPrice: quote.price, changePercent: quote.changePercent,
            savedEpoch: snap.savedEpoch
        )
        snapshots[index] = snap
        persist()
    }

    /// The raw coins to re-quote on the Watchlist tab.
    var coins: [CryptoCoin] {
        snapshots.map {
            CryptoCoin(id: $0.id, symbol: $0.id, base: $0.base, quote: $0.quote, description: $0.description)
        }
    }

    // MARK: - Snapshot → from live types

    private static func snapshot(from coin: CryptoCoin, quote: CryptoQuote?) -> CryptoSnapshot {
        CryptoSnapshot(
            id: coin.id,
            base: coin.base,
            quote: coin.quote,
            description: coin.description,
            lastPrice: quote?.price,
            changePercent: quote?.changePercent,
            savedEpoch: Date().timeIntervalSince1970
        )
    }

    // MARK: - Persistence

    private func load() -> [CryptoSnapshot] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([CryptoSnapshot].self, from: data)) ?? []
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(snapshots) {
            defaults.set(data, forKey: key)
        }
    }
}

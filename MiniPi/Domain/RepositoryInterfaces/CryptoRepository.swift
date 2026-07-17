//
//  CryptoRepository.swift
//  MiniPi
//
//  Domain contract for the Crypto feature. Mirrors ForexRepository: one cache-backed
//  fetch (market overview for Home + Stats) and several one-shot lookups
//  (price / candles / bulk prices / search for drill-down + detail). All coins are
//  quoted against the Yahoo `BTC-USD`-style symbols via the shared Yahoo chart/search
//  endpoints.
//

import Foundation

/// Parameters for a candle fetch.
struct CryptoCandleQuery: Equatable {
    var symbol: String
    var resolution: CryptoResolution
    var from: Date
    var to: Date

    init(symbol: String, resolution: CryptoResolution = .day, days: Int = 90) {
        self.symbol = symbol
        self.resolution = resolution
        self.to = Date()
        self.from = Date().addingTimeInterval(-Double(days) * 86_400)
    }
}

protocol CryptoRepository {
    /// USD-quoted coins + top movers (Home + Stats). Cache-backed: remote-first,
    /// persists to the local store on success, falls back to the cache on
    /// network/server error.
    func marketOverview() async -> Result<CryptoMarketOverview>

    /// Latest price for one coin (one-shot).
    func price(_ symbol: String) async -> Result<CryptoQuote>

    /// OHLCV series for a coin over a window (one-shot). Powers the detail chart.
    func candles(_ query: CryptoCandleQuery) async -> Result<CryptoCandle>

    /// Bulk prices for a list of coins, concurrently (one-shot). Drops per-coin failures
    /// so one bad ticker never blanks a list.
    func prices(for coins: [CryptoCoin]) async -> Result<[CryptoQuoteItem]>

    /// Yahoo autocomplete (one-shot). Filters to CRYPTOCURRENCY results.
    func search(query: String) async -> Result<[CryptoCoin]>
}

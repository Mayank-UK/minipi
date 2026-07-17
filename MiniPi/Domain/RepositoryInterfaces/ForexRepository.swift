//
//  ForexRepository.swift
//  MiniPi
//
//  Domain contract for the Forex feature. Mirrors StocksRepository: one cache-backed
//  fetch (market overview for Home + Stats) and several one-shot lookups
//  (rate / candles / bulk rates / search for drill-down + detail). All pairs are quoted
//  against the Yahoo `=X` symbols via the shared Yahoo chart/search endpoints.
//

import Foundation

/// Parameters for a candle fetch.
struct ForexCandleQuery: Equatable {
    var symbol: String
    var resolution: ForexResolution
    var from: Date
    var to: Date

    init(symbol: String, resolution: ForexResolution = .day, days: Int = 90) {
        self.symbol = symbol
        self.resolution = resolution
        self.to = Date()
        self.from = Date().addingTimeInterval(-Double(days) * 86_400)
    }
}

protocol ForexRepository {
    /// USD-quoted majors + top movers (Home + Stats). Cache-backed: remote-first,
    /// persists to the local store on success, falls back to the cache on
    /// network/server error.
    func marketOverview() async -> Result<ForexMarketOverview>

    /// Latest rate for one pair (one-shot).
    func rate(_ symbol: String) async -> Result<ForexQuote>

    /// OHLCV series for a pair over a window (one-shot). Powers the detail chart.
    func candles(_ query: ForexCandleQuery) async -> Result<ForexCandle>

    /// Bulk rates for a list of pairs, concurrently (one-shot). Drops per-pair failures
    /// so one bad ticker never blanks a list.
    func rates(for pairs: [ForexPair]) async -> Result<[ForexQuoteItem]>

    /// Yahoo autocomplete (one-shot). Filters to CURRENCY results.
    func search(query: String) async -> Result<[ForexPair]>
}

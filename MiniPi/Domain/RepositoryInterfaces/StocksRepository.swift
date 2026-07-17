//
//  StocksRepository.swift
//  MiniPi
//
//  Domain contract for the Finnhub-backed Stocks feature. Mirrors WeatherRepository:
//  one cache-backed fetch (market overview for Home + Stats) and several one-shot
//  lookups (quote / candles / search / profile for drill-down + detail).
//

import Foundation

/// Parameters for a candle fetch. Finnhub wants epoch-second bounds.
struct StocksCandleQuery: Equatable {
    var symbol: String
    var resolution: StockResolution
    var from: Date
    var to: Date

    init(symbol: String, resolution: StockResolution = .day, days: Int = 90) {
        self.symbol = symbol
        self.resolution = resolution
        self.to = Date()
        self.from = Date().addingTimeInterval(-Double(days) * 86_400)
    }
}

protocol StocksRepository {
    /// Indices + top movers for a country/exchange (Home + Stats). Cache-backed:
    /// remote-first, persists to the local store on success, falls back to the cache
    /// on network/server error.
    func marketOverview(country: String) async -> Result<StockMarketOverview>

    /// Latest quote for one symbol (one-shot). `currency` decorates the formatted price.
    func quote(_ symbol: String, currency: String?) async -> Result<StockQuote>

    /// OHLCV series for a symbol over a window (one-shot). Powers the detail chart.
    func candles(_ query: StocksCandleQuery) async -> Result<StockCandle>

    /// Bulk quotes for a list of symbols, concurrently (one-shot). Drops per-symbol
    /// failures so one bad ticker never blanks a list.
    func quotes(for symbols: [StockSymbol]) async -> Result<[StockQuoteItem]>

    /// `search.json` autocomplete (one-shot).
    func search(query: String) async -> Result<[StockSymbol]>

    /// `profile2` company metadata (one-shot).
    func profile(_ symbol: String) async -> Result<StockProfile?>
}

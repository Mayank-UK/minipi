//
//  CryptoRemoteDataSource.swift
//  MiniPi
//
//  Feature-scoped remote data source for Yahoo Finance cryptocurrencies. Owns only the
//  crypto endpoints behind a narrow protocol; the shared networking engine (HTTPClient +
//  interceptors) is injected — exactly like ForexRemoteDataSource.
//
//  Yahoo has no API key, but its endpoints reject the default `URLSession` User-Agent
//  with HTTP 999 / Cloudflare, so every request sets a browser-like `User-Agent` header
//  via `HTTPClient.get(_:as:headers:)` (same additive overload Stocks/Forex use).
//
//  Crypto symbols use the dash form (e.g. BTC-USD). The `/v8/finance/chart` endpoint
//  returns BOTH a price (meta) and an OHLCV series in one call, so `chart` powers the
//  price, candles and per-coin list quotes — identical to Stocks/Forex.
//

import Foundation

protocol CryptoRemoteDataSource {
    /// `/v8/finance/chart` — price (meta) + candle series for a coin/window.
    func chart(symbol: String, range: String, interval: String) async throws -> YahooChartEnvelopeDTO

    /// `/v1/finance/search` — coin autocomplete (one-shot).
    func search(_ query: String) async throws -> [YahooSearchItemDTO]
}

final class CryptoRemoteDataSourceImpl: CryptoRemoteDataSource {

    private let yahooBaseURL = "https://query1.finance.yahoo.com"
    /// Browser-like UA — Yahoo returns 999 without it.
    private let headers = ["User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"]
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func chart(symbol: String, range: String, interval: String) async throws -> YahooChartEnvelopeDTO {
        let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        let url = "\(yahooBaseURL)/v8/finance/chart/\(encoded)?range=\(range)&interval=\(interval)"
        return try await client.get(url, as: YahooChartEnvelopeDTO.self, headers: headers)
    }

    func search(_ query: String) async throws -> [YahooSearchItemDTO] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }
        // `newsCount=0` keeps the payload lean; we only want coin quotes.
        let url = "\(yahooBaseURL)/v1/finance/search?q=\(encoded)&quotesCount=20&newsCount=0"
        let envelope = try await client.get(url, as: YahooSearchDTO.self, headers: headers)
        return envelope.quotes ?? []
    }

    /// Map a day-count window to a Yahoo `range` token. Mirrors Stocks/Forex.
    static func range(forDays days: Int) -> String {
        switch days {
        case ...1: return "1d"
        case 2...7: return "5d"
        case 8...30: return "1mo"
        case 31...90: return "3mo"
        case 91...180: return "6mo"
        case 181...365: return "1y"
        default: return "max"
        }
    }
}

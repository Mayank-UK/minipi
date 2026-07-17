//
//  StocksDto.swift
//  MiniPi
//
//  Codable representation of Yahoo Finance responses. Yahoo exposes two open
//  endpoints (no key, but a User-Agent header is required — see
//  `StocksRemoteDataSourceImpl`):
//
//    • `/v8/finance/chart/{symbol}?interval=&range=` — one call returns BOTH a
//      real-time quote (from `meta`: regularMarketPrice/DayHigh/DayLow/DayOpen/
//      previousClose/regularMarketTime) and an OHLCV series (from `timestamp` +
//      `indicators.quote`). Powers the detail header, the candle chart and the
//      per-symbol list quotes.
//    • `/v1/finance/search?q=` — instrument autocomplete (`quotes[]`).
//
//  Yahoo covers native foreign tickers (`.NS` / `.L` / `.T` / `.TO` …) and real
//  index symbols (`^GSPC`, `^NSEI`, `^N225`, `^FTSE`, …) on the free endpoints, so
//  the curated universe uses each market's native symbols directly.
//
//  Yahoo's JSON uses null entries for missing series points; the DTOs decode those
//  as optionals and the mappers drop them.
//

import Foundation

// MARK: - /v8/finance/chart  (quote + candle envelope)

struct YahooChartEnvelopeDTO: Codable {
    let chart: YahooChartContainerDTO
}

struct YahooChartContainerDTO: Codable {
    let result: [YahooChartResultDTO]?
    let error: YahooChartErrorDTO?
}

struct YahooChartErrorDTO: Codable {
    let code: String?
    let description: String?
}

struct YahooChartResultDTO: Codable {
    let meta: YahooChartMetaDTO?
    let timestamp: [Double]?
    let indicators: YahooIndicatorsDTO?
}

struct YahooChartMetaDTO: Codable {
    let symbol: String?
    let currency: String?
    let exchangeName: String?
    let instrumentType: String?
    let regularMarketPrice: Double?
    let regularMarketTime: Double?       // epoch seconds
    let regularMarketDayHigh: Double?
    let regularMarketDayLow: Double?
    let regularMarketDayOpen: Double?
    let regularMarketVolume: Double?
    let chartPreviousClose: Double?
    let previousClose: Double?
}

struct YahooIndicatorsDTO: Codable {
    let quote: [YahooQuoteIndicatorDTO]?
}

struct YahooQuoteIndicatorDTO: Codable {
    let open: [Double?]?
    let high: [Double?]?
    let low: [Double?]?
    let close: [Double?]?
    let volume: [Double?]?
}

// MARK: - /v1/finance/search  (autocomplete)

struct YahooSearchDTO: Codable {
    let quotes: [YahooSearchItemDTO]?
}

struct YahooSearchItemDTO: Codable {
    let symbol: String?
    let shortname: String?
    let longname: String?
    let exchange: String?
    let quoteType: String?      // EQUITY, ETF, INDEX, CURRENCY, FUTURE, MUTUALFUND, CRYPTOCURRENCY…
    let typeDisp: String?
}

// MARK: - DTO → Domain

extension YahooChartEnvelopeDTO {

    /// Map the latest quote from `meta`. Yahoo doesn't send change/percent directly,
    /// so they're derived from `regularMarketPrice` − `previousClose`.
    func toQuote(symbol: String) -> StockQuote? {
        guard let meta = chart.result?.first?.meta,
              let price = meta.regularMarketPrice,
              price != 0 else { return nil }

        let prevClose = meta.previousClose ?? meta.chartPreviousClose ?? price
        let change = price - prevClose
        let percent = prevClose != 0 ? (change / prevClose) * 100 : 0

        return StockQuote(
            symbol: symbol,
            current: price,
            change: change,
            changePercent: percent,
            high: meta.regularMarketDayHigh ?? 0,
            low: meta.regularMarketDayLow ?? 0,
            open: meta.regularMarketDayOpen ?? 0,
            prevClose: prevClose,
            time: meta.regularMarketTime.map { Date(timeIntervalSince1970: $0) }
        )
    }

    /// Map the OHLCV series, aligned by index and dropping points with a null close.
    func toCandle(symbol: String, resolution: String) -> StockCandle {
        guard let result = chart.result?.first,
              let timestamps = result.timestamp,
              let quote = result.indicators?.quote?.first else {
            return StockCandle(symbol: symbol, resolution: resolution,
                               timestamps: [], opens: [], highs: [], lows: [], closes: [], volumes: [])
        }

        let closes = quote.close ?? []
        let count = min(timestamps.count, closes.count)

        var times: [Date] = []
        var opens: [Double] = []
        var highs: [Double] = []
        var lows: [Double] = []
        var closeSeries: [Double] = []
        var volumes: [Double] = []

        for i in 0..<count {
            guard let close = closes[i] else { continue }
            times.append(Date(timeIntervalSince1970: timestamps[i]))
            closeSeries.append(close)
            opens.append(quote.open?[i] ?? close)
            highs.append(quote.high?[i] ?? close)
            lows.append(quote.low?[i] ?? close)
            volumes.append(quote.volume?[i] ?? 0)
        }

        return StockCandle(
            symbol: symbol,
            resolution: resolution,
            timestamps: times,
            opens: opens,
            highs: highs,
            lows: lows,
            closes: closeSeries,
            volumes: volumes
        )
    }
}

extension YahooSearchItemDTO {
    func toSymbol() -> StockSymbol? {
        guard let symbol = symbol?.trimmingCharacters(in: .whitespacesAndNewlines),
              !symbol.isEmpty else { return nil }
        let description = shortname ?? longname ?? ""
        return StockSymbol(
            id: symbol,
            symbol: symbol,
            displaySymbol: symbol,
            description: description,
            type: StockType.from(quoteType),
            exchange: exchange,
            currency: nil,
            country: nil
        )
    }
}

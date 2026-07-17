//
//  ForexDto.swift
//  MiniPi
//
//  Forex-specific mappers over the shared Yahoo Finance DTOs (see StocksDto.swift):
//
//    • `/v8/finance/chart/{symbol}?interval=&range=` — returns a real-time rate (from
//      `meta`: regularMarketPrice/DayHigh/DayLow/DayOpen/previousClose/
//      regularMarketTime + `currency` = the quote currency) AND an OHLCV series
//      (from `timestamp` + `indicators.quote`) in ONE call. So `chart` powers the rate,
//      candles and per-pair list quotes.
//    • `/v1/finance/search?q=` — autocomplete; we keep only `quoteType == CURRENCY`
//      results and parse the `XXXYYY=X` symbol into base/quote.
//
//  Yahoo's JSON uses null entries for missing series points; the candle mapper drops
//  them (same as StocksDto).
//

import Foundation

// MARK: - Chart envelope → Forex domain

extension YahooChartEnvelopeDTO {

    /// Map the latest rate from `meta`. Change/percent are derived from
    /// `regularMarketPrice − previousClose`. The meta `currency` is the pair's quote
    /// currency, which drives rate formatting precision.
    func toForexQuote(symbol: String) -> ForexQuote? {
        guard let meta = chart.result?.first?.meta,
              let price = meta.regularMarketPrice,
              price != 0 else { return nil }

        let prevClose = meta.previousClose ?? meta.chartPreviousClose ?? price
        let change = price - prevClose
        let percent = prevClose != 0 ? (change / prevClose) * 100 : 0
        let quoteCurrency = meta.currency ?? ""

        return ForexQuote(
            symbol: symbol,
            rate: price,
            change: change,
            changePercent: percent,
            high: meta.regularMarketDayHigh ?? 0,
            low: meta.regularMarketDayLow ?? 0,
            open: meta.regularMarketDayOpen ?? 0,
            prevClose: prevClose,
            time: meta.regularMarketTime.map { Date(timeIntervalSince1970: $0) },
            quoteCurrency: quoteCurrency
        )
    }

    /// Map the OHLCV series, aligned by index and dropping points with a null close.
    func toForexCandle(symbol: String, resolution: String) -> ForexCandle {
        guard let result = chart.result?.first,
              let timestamps = result.timestamp,
              let quote = result.indicators?.quote?.first else {
            return ForexCandle(symbol: symbol, resolution: resolution,
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

        return ForexCandle(
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

// MARK: - Search item → Forex pair

extension YahooSearchItemDTO {

    /// Only CURRENCY results are forex pairs. Yahoo symbols look like "EURUSD=X" or
    /// "EURUSD=X"; parse into base/quote and build a `ForexPair`. Returns nil for
    /// non-currency results or un-parseable symbols.
    func toPair() -> ForexPair? {
        guard let quoteType = quoteType?.uppercased(), quoteType == "CURRENCY" else { return nil }
        guard let raw = symbol?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }

        // "EURUSD=X" → code "EURUSD"
        let code = raw.hasSuffix("=X") ? String(raw.dropLast(2)) : raw
        guard code.count == 6 else {
            // Some Yahoo currency results are single-currency (e.g. "USD=X"); skip those.
            return nil
        }
        let base = String(code.prefix(3)).uppercased()
        let quote = String(code.suffix(3)).uppercased()
        guard base.allSatisfy(\.isLetter), quote.allSatisfy(\.isLetter) else { return nil }

        let yahooSymbol = "\(base)\(quote)=X"
        let description = "\(ForexCurrencyNames.name(for: base)) / \(ForexCurrencyNames.name(for: quote))"
        return ForexPair(id: yahooSymbol, symbol: yahooSymbol, base: base, quote: quote, description: description)
    }
}

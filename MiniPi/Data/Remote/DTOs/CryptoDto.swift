//
//  CryptoDto.swift
//  MiniPi
//
//  Crypto-specific mappers over the shared Yahoo Finance DTOs (see StocksDto.swift):
//
//    • `/v8/finance/chart/{symbol}?interval=&range=` — returns a real-time price (from
//      `meta`: regularMarketPrice/DayHigh/DayLow/DayOpen/previousClose/
//      regularMarketTime + `currency` = the quote currency) AND an OHLCV series
//      (from `timestamp` + `indicators.quote`) in ONE call. So `chart` powers the price,
//      candles and per-coin list quotes.
//    • `/v1/finance/search?q=` — autocomplete; we keep only `quoteType == CRYPTOCURRENCY`
//      results and parse the `BTC-USD` symbol into base/quote.
//
//  IMPORTANT: mappers are named `toCrypto*` — `toQuote`/`toCandle`/`toPair`/`toSymbol`
//  already exist on these shared Yahoo DTOs (Stocks/Forex), so any other name collides
//  with an "ambiguous use" compile error. Same gotcha as the Forex mappers.
//
//  Yahoo's JSON uses null entries for missing series points; the candle mapper drops
//  them (same as StocksDto/ForexDto).
//

import Foundation

// MARK: - Chart envelope → Crypto domain

extension YahooChartEnvelopeDTO {

    /// Map the latest price from `meta`. Change/percent are derived from
    /// `regularMarketPrice − previousClose`. The meta `currency` is the coin's quote
    /// currency, which drives price formatting precision.
    func toCryptoQuote(symbol: String) -> CryptoQuote? {
        guard let meta = chart.result?.first?.meta,
              let price = meta.regularMarketPrice,
              price != 0 else { return nil }

        let prevClose = meta.previousClose ?? meta.chartPreviousClose ?? price
        let change = price - prevClose
        let percent = prevClose != 0 ? (change / prevClose) * 100 : 0
        let quoteCurrency = meta.currency ?? ""

        return CryptoQuote(
            symbol: symbol,
            price: price,
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
    func toCryptoCandle(symbol: String, resolution: String) -> CryptoCandle {
        guard let result = chart.result?.first,
              let timestamps = result.timestamp,
              let quote = result.indicators?.quote?.first else {
            return CryptoCandle(symbol: symbol, resolution: resolution,
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

        return CryptoCandle(
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

// MARK: - Search item → Crypto coin

extension YahooSearchItemDTO {

    /// Only CRYPTOCURRENCY results are coins. Yahoo symbols look like "BTC-USD"; parse
    /// into base/quote and build a `CryptoCoin`. Returns nil for non-crypto results or
    /// un-parseable symbols.
    func toCoin() -> CryptoCoin? {
        guard let quoteType = quoteType?.uppercased(), quoteType == "CRYPTOCURRENCY" else { return nil }
        guard let raw = symbol?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }

        // "BTC-USD" → ["BTC", "USD"]. Require an explicit quote currency.
        let parts = raw.split(separator: "-").map(String.init)
        guard parts.count == 2 else { return nil }
        let base = parts[0].uppercased()
        let quote = parts[1].uppercased()
        guard base.allSatisfy(\.isLetter), quote.allSatisfy(\.isLetter) else { return nil }

        let yahooSymbol = "\(base)-\(quote)"
        let description = shortname ?? longname ?? CryptoCoinNames.name(for: base)
        return CryptoCoin(id: yahooSymbol, symbol: yahooSymbol, base: base, quote: quote, description: description)
    }
}

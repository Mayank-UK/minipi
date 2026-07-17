//
//  Forex.swift
//  MiniPi
//
//  Domain models for the Forex feature. Mirrors Stocks layer-for-layer: plain value
//  types with the derived text helpers the UI needs. Used by Home (USD-quoted majors
//  + movers), Markets (majors / minors / exotics), Search (server autocomplete),
//  Watchlist (persisted snapshots) and Stats (charts).
//
//  Forex pairs are quoted as a rate (e.g. EUR/USD = 1.08245). Rates are plain numbers,
//  NOT money — so formatting uses a decimal precision that depends on the quote
//  currency (JPY pairs → 3 decimals, everything else → 5 decimals), never a currency
//  symbol. This is the forex analogue of the Stocks "index = points, not money" rule.
//

import Foundation

// MARK: - Currency pair

/// A tradeable forex pair. `symbol` is the string sent back to the Yahoo API
/// (e.g. "EURUSD=X", "USDJPY=X"); `base`/`quote` are the ISO currency codes that form
/// the human-friendly "EUR/USD" label.
struct ForexPair: Identifiable, Equatable {
    let id: String          // Yahoo symbol, e.g. "EURUSD=X"
    let symbol: String      // same as id — sent to the API
    let base: String        // e.g. "EUR"
    let quote: String       // e.g. "USD"

    /// Human-friendly label, e.g. "EUR/USD".
    var displaySymbol: String { "\(base)/\(quote)" }

    /// Full name, e.g. "Euro / US Dollar".
    let description: String

    /// A one-line label: "EUR/USD · Euro / US Dollar".
    var subtitle: String {
        let desc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return desc.isEmpty ? displaySymbol : desc
    }
}

// MARK: - Quote

/// Real-time (or near-real-time) rate quote for a pair. Fields mirror the Yahoo
/// `/v8/finance/chart` `meta` block. Change/percent are derived from
/// `regularMarketPrice − previousClose`.
struct ForexQuote: Equatable {
    let symbol: String
    let rate: Double            // current rate (regularMarketPrice)
    let change: Double          // absolute change vs prev close
    let changePercent: Double   // percent change vs prev close
    let high: Double            // day high
    let low: Double             // day low
    let open: Double            // day open
    let prevClose: Double       // previous close
    let time: Date?             // epoch seconds
    /// The quote currency (drives rate formatting precision + the detail stats).
    let quoteCurrency: String

    var isUp: Bool { change >= 0 }

    /// The rate as a plain number, precision by quote currency (JPY → 3 dp, else 5 dp).
    var rateText: String {
        Self.formattedRate(rate, quoteCurrency: quoteCurrency)
    }

    func changeText() -> String {
        let sign = change >= 0 ? "+" : ""
        let dp = ForexRatePrecision.decimals(for: quoteCurrency)
        return String(format: "%@%.\(dp)f (%@%.2f%%)", sign, change, sign, changePercent)
    }

    /// Compact "+0.35%" used by rows.
    var percentText: String {
        let sign = changePercent >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", sign, changePercent)
    }

    /// Formats a raw rate, picking precision by quote currency. Forex rates are points,
    /// not money, so this never emits a currency symbol.
    static func formattedRate(_ value: Double, quoteCurrency: String?) -> String {
        let dp = ForexRatePrecision.decimals(for: quoteCurrency)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = dp
        f.maximumFractionDigits = dp
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.\(dp)f", value)
    }
}

/// Rate decimal precision by quote currency. JPY-quoted pairs trade at ~3 pip precision;
/// everything else at ~5. Kept here so the row, detail and card all agree.
enum ForexRatePrecision {
    static func decimals(for quoteCurrency: String?) -> Int {
        (quoteCurrency?.uppercased() == "JPY") ? 3 : 5
    }
}

// MARK: - Candle series

/// OHLCV series for a pair over a window. Powers the detail chart + Stats.
struct ForexCandle: Equatable {
    let symbol: String
    let resolution: String
    let timestamps: [Date]
    let opens: [Double]
    let highs: [Double]
    let lows: [Double]
    let closes: [Double]
    let volumes: [Double]

    var isEmpty: Bool { closes.isEmpty }

    /// Last close in the series (the most recent rate point).
    var lastClose: Double? { closes.last }
}

// MARK: - Quote item (pair + quote)

/// A pair paired with its latest quote — the unit rendered in Home / Markets / Search /
/// Watchlist. Mirrors `StockQuoteItem`.
struct ForexQuoteItem: Identifiable, Equatable {
    let pair: ForexPair
    let quote: ForexQuote
    /// Recent close series for a sparkline (Home cards). Empty when not loaded.
    let sparkline: [Double]

    init(pair: ForexPair, quote: ForexQuote, sparkline: [Double] = []) {
        self.pair = pair
        self.quote = quote
        self.sparkline = sparkline
    }

    var id: String { pair.id }
}

// MARK: - Market overview (Home)

/// The Home tab dataset: USD-quoted majors + top movers. Forex has no "country" — the
/// Home view is always currencies compared to the US dollar.
struct ForexMarketOverview: Equatable {
    let baseLabel: String                // "USD"
    let pairs: [ForexQuoteItem]          // majors vs USD
    let topGainers: [ForexQuoteItem]
    let topLosers: [ForexQuoteItem]

    static let empty = ForexMarketOverview(baseLabel: "USD", pairs: [], topGainers: [], topLosers: [])
}

// MARK: - Markets segment

/// The Markets tab segmented control. Each maps to a curated list of pairs.
enum ForexSegment: String, CaseIterable, Identifiable {
    case majors
    case minors
    case exotics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .majors: return "Majors"
        case .minors: return "Minors"
        case .exotics: return "Exotics"
        }
    }

    var icon: String {
        switch self {
        case .majors: return "star.circle.fill"
        case .minors: return "circle.grid.2x2.fill"
        case .exotics: return "sparkles"
        }
    }
}

// MARK: - Candle resolution

/// Yahoo candle resolution. `D` = daily (used for the detail chart + Stats).
enum ForexResolution: String, CaseIterable {
    case minute = "1"
    case fiveMinute = "5"
    case fifteenMinute = "15"
    case thirtyMinute = "30"
    case hour = "60"
    case day = "D"
    case week = "W"
    case month = "M"
}

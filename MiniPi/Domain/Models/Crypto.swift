//
//  Crypto.swift
//  MiniPi
//
//  Domain models for the Crypto feature. Mirrors Forex/Stocks layer-for-layer: plain
//  value types with the derived text helpers the UI needs. Used by Home (coins vs USD +
//  movers), Search (server autocomplete), Watchlist (persisted snapshots) and Stats
//  (charts). Crypto has 4 tabs — no Markets tab (Home absorbs the browse role).
//
//  Crypto prices are quoted in fiat (USD by default) — so unlike forex rates or index
//  points, prices ARE money. Formatting uses a currency-style number with adaptive
//  decimal precision: 2 dp for normal coins, more dp for sub-dollar/sub-cent coins
//  (so DOGE/SHIB show meaningful prices rather than rounding to $0.00).
//

import Foundation

// MARK: - Coin

/// A tradeable cryptocurrency. `symbol` is the string sent to Yahoo (e.g. "BTC-USD");
/// `base`/`quote` are the asset codes forming the human-friendly "BTC/USD" label.
struct CryptoCoin: Identifiable, Equatable {
    let id: String          // Yahoo symbol, e.g. "BTC-USD"
    let symbol: String      // same as id — sent to the API
    let base: String        // e.g. "BTC"
    let quote: String       // e.g. "USD"

    /// Human-friendly label, e.g. "BTC/USD".
    var displaySymbol: String { "\(base)/\(quote)" }

    /// Full name, e.g. "Bitcoin".
    let description: String

    /// A one-line label: "Bitcoin" (falls back to the display symbol).
    var subtitle: String {
        let desc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return desc.isEmpty ? displaySymbol : desc
    }
}

// MARK: - Quote

/// Real-time (or near-real-time) price quote for a coin. Fields mirror the Yahoo
/// `/v8/finance/chart` `meta` block. Change/percent are derived from
/// `regularMarketPrice − previousClose`.
struct CryptoQuote: Equatable {
    let symbol: String
    let price: Double           // current price (regularMarketPrice)
    let change: Double          // absolute change vs prev close
    let changePercent: Double   // percent change vs prev close
    let high: Double            // day high
    let low: Double             // day low
    let open: Double            // day open
    let prevClose: Double       // previous close
    let time: Date?             // epoch seconds
    /// The quote currency (drives price formatting + the detail stats).
    let quoteCurrency: String

    var isUp: Bool { change >= 0 }

    /// The price as a plain number, with adaptive precision (sub-dollar coins get more
    /// decimals). Prices are money but emitted as a grouped number without a currency
    /// symbol so they line up with the stocks/forex row styling.
    var priceText: String {
        Self.formattedPrice(price, quoteCurrency: quoteCurrency)
    }

    func changeText() -> String {
        let sign = change >= 0 ? "+" : ""
        let dp = CryptoPricePrecision.decimals(for: abs(change) >= 1 ? change : nil)
        return String(format: "%@%.\(dp)f (%@%.2f%%)", sign, change, sign, changePercent)
    }

    /// Compact "+2.34%" used by rows.
    var percentText: String {
        let sign = changePercent >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", sign, changePercent)
    }

    /// Formats a raw price with adaptive precision. Large prices (≥ $1) show 2 dp;
    /// small prices show enough dp for the leading digits to be meaningful. Never emits
    /// a currency symbol — call sites decide whether to add one.
    static func formattedPrice(_ value: Double, quoteCurrency: String?) -> String {
        let dp = CryptoPricePrecision.decimals(for: value)
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = dp
        f.maximumFractionDigits = dp
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.\(dp)f", value)
    }
}

/// Adaptive decimal precision for crypto prices. ≥ $1 → 2 dp; smaller prices get more
/// dp so sub-cent coins (SHIB, PEPE) render meaningfully instead of "$0.00".
enum CryptoPricePrecision {
    static func decimals(for value: Double?) -> Int {
        guard let value, value > 0 else { return 2 }
        if value >= 1 { return 2 }
        // Count leading zeros after the decimal to keep ~4 significant digits.
        // e.g. 0.42 → 4, 0.0012 → 6, 0.000012 → 8.
        var v = value
        var dp = 2
        while v < 0.1, dp < 8 {
            v *= 10
            dp += 1
        }
        return dp
    }
}

// MARK: - Candle series

/// OHLCV series for a coin over a window. Powers the detail chart + Stats.
struct CryptoCandle: Equatable {
    let symbol: String
    let resolution: String
    let timestamps: [Date]
    let opens: [Double]
    let highs: [Double]
    let lows: [Double]
    let closes: [Double]
    let volumes: [Double]

    var isEmpty: Bool { closes.isEmpty }

    /// Last close in the series (the most recent price point).
    var lastClose: Double? { closes.last }
}

// MARK: - Quote item (coin + quote)

/// A coin paired with its latest quote — the unit rendered in Home / Search / Watchlist.
/// Mirrors `ForexQuoteItem` / `StockQuoteItem`.
struct CryptoQuoteItem: Identifiable, Equatable {
    let coin: CryptoCoin
    let quote: CryptoQuote
    /// Recent close series for a sparkline (Home cards). Empty when not loaded.
    let sparkline: [Double]

    init(coin: CryptoCoin, quote: CryptoQuote, sparkline: [Double] = []) {
        self.coin = coin
        self.quote = quote
        self.sparkline = sparkline
    }

    var id: String { coin.id }
}

// MARK: - Market overview (Home)

/// The Home tab dataset: USD-quoted coins + top movers. Crypto has no "country" — the
/// Home view is always coins compared to the US dollar.
struct CryptoMarketOverview: Equatable {
    let quoteLabel: String              // "USD"
    let all: [CryptoQuoteItem]          // curated coins vs USD
    let topGainers: [CryptoQuoteItem]
    let topLosers: [CryptoQuoteItem]

    static let empty = CryptoMarketOverview(quoteLabel: "USD", all: [], topGainers: [], topLosers: [])
}

// MARK: - Home segment

/// The Home tab segmented control. Home absorbs the Markets role: All coins, or the
/// movers split by sign.
enum CryptoSegment: String, CaseIterable, Identifiable {
    case all
    case topGainers
    case topLosers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .topGainers: return "Top Gainers"
        case .topLosers: return "Top Losers"
        }
    }

    var icon: String {
        switch self {
        case .all: return "bitcoinsign.circle.fill"
        case .topGainers: return "arrow.up.right.circle.fill"
        case .topLosers: return "arrow.down.right.circle.fill"
        }
    }
}

// MARK: - Candle resolution

/// Yahoo candle resolution. `D` = daily (used for the detail chart + Stats).
enum CryptoResolution: String, CaseIterable {
    case minute = "1"
    case fiveMinute = "5"
    case fifteenMinute = "15"
    case thirtyMinute = "30"
    case hour = "60"
    case day = "D"
    case week = "W"
    case month = "M"
}

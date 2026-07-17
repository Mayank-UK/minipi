//
//  Stocks.swift
//  MiniPi
//
//  Domain models for the Finnhub-backed Stocks feature. Used by Home (indices +
//  movers), Markets (indices / stocks / ETFs / commodities lists), Search (server
//  autocomplete), Watchlist (persisted snapshots) and Stats (charts). Mirrors
//  Weather/Earthquake: plain value types with the derived text helpers the UI needs.
//

import Foundation

// MARK: - Instrument type

/// The asset class an instrument belongs to. Drives the Markets tab segmentation
/// and the row icon. Strings mirror Finnhub's `type` field where possible.
enum StockType: String, Codable, CaseIterable {
    case stock
    case etf
    case trust
    case fund
    case index
    case forex
    case crypto
    case commodity
    case other

    /// Map an arbitrary Finnhub `type` string to our enum (unknown → other).
    static func from(_ raw: String?) -> StockType {
        guard let raw else { return .other }
        let lower = raw.lowercased()
        if lower.contains("etf") { return .etf }
        if lower.contains("index") { return .index }
        if lower.contains("forex") || lower.contains("currency") { return .forex }
        if lower.contains("crypto") { return .crypto }
        if lower.contains("commodit") { return .commodity }
        if lower.contains("trust") { return .trust }
        if lower.contains("fund") { return .fund }
        if lower.contains("stock") || lower.contains("common") || lower.contains("adr") {
            return .stock
        }
        return StockType(rawValue: lower) ?? .other
    }

    var title: String {
        switch self {
        case .stock: return "Stock"
        case .etf: return "ETF"
        case .trust: return "Trust"
        case .fund: return "Fund"
        case .index: return "Index"
        case .forex: return "Forex"
        case .crypto: return "Crypto"
        case .commodity: return "Commodity"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .stock: return "chart.line.uptrend.xyaxis"
        case .etf: return "shippingbox.fill"
        case .trust: return "building.2.fill"
        case .fund: return "piggy.bank.fill"
        case .index: return "list.number"
        case .forex: return "dollarsign.circle.fill"
        case .crypto: return "bitcoinsign.circle.fill"
        case .commodity: return "flame.fill"
        case .other: return "questionmark.circle"
        }
    }
}

// MARK: - Symbol

/// A tradeable instrument Finnhub can quote. `symbol` is the string sent back to
/// the API (e.g. "AAPL", "^GSPC"); `displaySymbol` is the human-friendly ticker.
struct StockSymbol: Identifiable, Equatable {
    let id: String
    let symbol: String
    let displaySymbol: String
    let description: String
    let type: StockType
    let exchange: String?
    let currency: String?
    let country: String?

    /// A one-line label: "AAPL · Apple Inc".
    var subtitle: String {
        let desc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return desc.isEmpty ? (exchange ?? symbol) : desc
    }
}

// MARK: - Quote

/// Real-time (or near-real-time) quote for a symbol. Fields mirror Finnhub `/quote`.
struct StockQuote: Equatable {
    let symbol: String
    let current: Double        // c — current price
    let change: Double         // d — absolute change vs prev close
    let changePercent: Double  // dp — percent change vs prev close
    let high: Double           // h — day high
    let low: Double            // l — day low
    let open: Double           // o — day open
    let prevClose: Double      // pc — previous close
    let time: Date?            // t — epoch seconds

    var isUp: Bool { change >= 0 }

    func priceText(currency: String? = nil) -> String {
        Self.formattedPrice(current, currency: currency)
    }

    func changeText() -> String {
        let sign = change >= 0 ? "+" : ""
        return String(format: "%@%.2f (%@%.2f%%)", sign, change, sign, changePercent)
    }

    /// Compact "+1.24%" used by rows.
    var percentText: String {
        let sign = changePercent >= 0 ? "+" : ""
        return String(format: "%@%.2f%%", sign, changePercent)
    }

    /// Formats a raw price, tolerating nil/zero currency.
    static func formattedPrice(_ value: Double, currency: String?) -> String {
        guard let currency, !currency.isEmpty else {
            return String(format: "%.2f", value)
        }
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    /// Formats an INDEX value as plain points (no currency symbol) — indices quote
    /// in points, not money, so "₹24,500" / "$5,400" is wrong; show "24,500.35".
    static func formattedPoints(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }
}

// MARK: - Candle series

/// OHLCV series for a symbol over a window. Powers the detail chart + Stats.
struct StockCandle: Equatable {
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

// MARK: - Profile

/// Company/instrument metadata from Finnhub `/stock/profile2`.
struct StockProfile: Equatable {
    let symbol: String
    let name: String?
    let logo: String?
    let country: String?
    let currency: String?
    let exchange: String?
    let industry: String?
    let marketCap: Double?      // USD (Finnhub reports in USD)
    let peRatio: Double?
}

// MARK: - Market overview (Home)

/// A symbol paired with its latest quote — the unit rendered in Home / Markets.
struct StockQuoteItem: Identifiable, Equatable {
    let symbol: StockSymbol
    let quote: StockQuote
    /// Recent close series for a sparkline (Home index cards). Empty when not loaded.
    let sparkline: [Double]

    init(symbol: StockSymbol, quote: StockQuote, sparkline: [Double] = []) {
        self.symbol = symbol
        self.quote = quote
        self.sparkline = sparkline
    }

    var id: String { symbol.id }
}

/// The Home tab dataset: indices + top movers for a country/exchange.
struct StockMarketOverview: Equatable {
    let country: String
    let exchange: String
    let indices: [StockQuoteItem]
    let topGainers: [StockQuoteItem]
    let topLosers: [StockQuoteItem]

    static let empty = StockMarketOverview(country: "", exchange: "", indices: [], topGainers: [], topLosers: [])
}

// MARK: - Markets segment

/// The Markets tab segmented control. Each maps to a curated list of symbols.
enum StockSegment: String, CaseIterable, Identifiable {
    case indices
    case stocks
    case etfs
    case commodities

    var id: String { rawValue }

    var title: String {
        switch self {
        case .indices: return "Indices"
        case .stocks: return "Stocks"
        case .etfs: return "ETFs"
        case .commodities: return "Commodities"
        }
    }

    var icon: String {
        switch self {
        case .indices: return "list.number"
        case .stocks: return "chart.line.uptrend.xyaxis"
        case .etfs: return "shippingbox.fill"
        case .commodities: return "flame.fill"
        }
    }
}

// MARK: - Candle resolution

/// Finnhub candle resolution. `D` = daily (used for the detail chart + Stats).
enum StockResolution: String, CaseIterable {
    case minute = "1"
    case fiveMinute = "5"
    case fifteenMinute = "15"
    case thirtyMinute = "30"
    case hour = "60"
    case day = "D"
    case week = "W"
    case month = "M"
}

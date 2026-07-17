//
//  StockUniverse.swift
//  MiniPi
//
//  Curated instrument lists per country/region for the Stocks Home + Markets tabs.
//  Yahoo Finance has no single "market overview" endpoint, so the Home dataset is
//  assembled by quoting a curated set of well-known symbols for the device's country
//  (resolved by `StocksCountryStore`). Quotes that fail or have no price (delisted /
//  rate-limited) are dropped by the repository.
//
//  Yahoo quotes NATIVE foreign tickers AND real index symbols on its free endpoints,
//  so each region uses that market's native tickers directly:
//    • Indices → the exchange's real index (^GSPC, ^NSEI, ^BSESN, ^FTSE, ^GDAXI,
//      ^N225, ^GSPTSE).
//    • Stocks → native tickers (RELIANCE.NS, HSBA.L, SAP.DE, 7203.T, RY.TO).
//  Adding a country = add a `StocksRegion` case + its symbols. Keep lists short —
//  each symbol is a chart call (Yahoo rate-limits heavy use with HTTP 429).
//

import Foundation

struct StocksRegion {
    /// ISO region code the store resolves to (e.g. "US", "IN", "GB").
    let code: String
    let displayName: String
    /// Yahoo exchange suffix / informational tag for the region.
    let exchange: String
    let currency: String
    let indices: [StockSymbol]
    let stocks: [StockSymbol]
    let etfs: [StockSymbol]
    let commodities: [StockSymbol]
}

enum StockUniverse {

    /// Resolve a region by ISO code, defaulting to the US market.
    static func region(for countryCode: String?) -> StocksRegion {
        let code = (countryCode ?? "US").uppercased()
        return allRegions[code] ?? usRegion
    }

    /// The regions selectable from the Home country picker.
    static let pickerRegions: [StocksRegion] = [
        usRegion, indiaRegion, ukRegion, germanyRegion, japanRegion, canadaRegion
    ]

    // MARK: - Region definitions

    private static func sym(_ s: String, _ display: String, _ desc: String, _ type: StockType) -> StockSymbol {
        StockSymbol(id: s, symbol: s, displaySymbol: display, description: desc, type: type,
                    exchange: nil, currency: nil, country: nil)
    }

    static let usRegion = StocksRegion(
        code: "US",
        displayName: "United States",
        exchange: "US",
        currency: "USD",
        indices: [
            sym("^GSPC", "^GSPC", "S&P 500", .index),
            sym("^DJI", "^DJI", "Dow Jones Industrial Average", .index),
            sym("^IXIC", "^IXIC", "Nasdaq Composite", .index),
        ],
        stocks: [
            sym("AAPL", "AAPL", "Apple Inc.", .stock),
            sym("MSFT", "MSFT", "Microsoft Corp.", .stock),
            sym("NVDA", "NVDA", "NVIDIA Corp.", .stock),
            sym("AMZN", "AMZN", "Amazon.com Inc.", .stock),
            sym("GOOGL", "GOOGL", "Alphabet Inc.", .stock),
            sym("META", "META", "Meta Platforms", .stock),
            sym("TSLA", "TSLA", "Tesla Inc.", .stock),
        ],
        etfs: [
            sym("SPY", "SPY", "SPDR S&P 500 ETF", .etf),
            sym("QQQ", "QQQ", "Invesco QQQ Trust", .etf),
            sym("DIA", "DIA", "SPDR Dow Jones ETF", .etf),
        ],
        commodities: [
            sym("GLD", "GLD", "SPDR Gold Shares", .commodity),
            sym("SLV", "SLV", "iShares Silver Trust", .commodity),
            sym("USO", "USO", "United States Oil Fund", .commodity),
        ]
    )

    static let indiaRegion = StocksRegion(
        code: "IN",
        displayName: "India",
        exchange: "NS",
        currency: "INR",
        indices: [
            sym("^NSEI", "^NSEI", "NIFTY 50", .index),
            sym("^BSESN", "^BSESN", "S&P BSE SENSEX", .index),
        ],
        stocks: [
            sym("RELIANCE.NS", "RELIANCE", "Reliance Industries", .stock),
            sym("TCS.NS", "TCS", "Tata Consultancy Services", .stock),
            sym("INFY.NS", "INFY", "Infosys Ltd.", .stock),
            sym("HDFCBANK.NS", "HDFCBANK", "HDFC Bank", .stock),
            sym("ICICIBANK.NS", "ICICIBANK", "ICICI Bank", .stock),
        ],
        etfs: [
            sym("NIFTYBEES.NS", "NIFTYBEES", "Nippon India NIFTY ETF", .etf),
        ],
        commodities: [
            sym("GOLDBEES.NS", "GOLDBEES", "Nippon India Gold ETF", .commodity),
        ]
    )

    static let ukRegion = StocksRegion(
        code: "GB",
        displayName: "United Kingdom",
        exchange: "L",
        currency: "GBP",
        indices: [
            sym("^FTSE", "^FTSE", "FTSE 100", .index),
        ],
        stocks: [
            sym("HSBA.L", "HSBA", "HSBC Holdings", .stock),
            sym("BP.L", "BP", "BP plc", .stock),
            sym("ULVR.L", "ULVR", "Unilever plc", .stock),
            sym("AZN.L", "AZN", "AstraZeneca plc", .stock),
        ],
        etfs: [], commodities: []
    )

    static let germanyRegion = StocksRegion(
        code: "DE",
        displayName: "Germany",
        exchange: "DE",
        currency: "EUR",
        indices: [
            sym("^GDAXI", "^GDAXI", "DAX", .index),
        ],
        stocks: [
            sym("SAP.DE", "SAP", "SAP SE", .stock),
            sym("SIE.DE", "SIE", "Siemens AG", .stock),
            sym("ALV.DE", "ALV", "Allianz SE", .stock),
        ],
        etfs: [], commodities: []
    )

    static let japanRegion = StocksRegion(
        code: "JP",
        displayName: "Japan",
        exchange: "T",
        currency: "JPY",
        indices: [
            sym("^N225", "^N225", "Nikkei 225", .index),
        ],
        stocks: [
            sym("7203.T", "TOYOTA", "Toyota Motor", .stock),
            sym("6758.T", "SONY", "Sony Group", .stock),
            sym("9984.T", "SOFTBANK", "SoftBank Group", .stock),
        ],
        etfs: [], commodities: []
    )

    static let canadaRegion = StocksRegion(
        code: "CA",
        displayName: "Canada",
        exchange: "TO",
        currency: "CAD",
        indices: [
            sym("^GSPTSE", "^GSPTSE", "S&P/TSX Composite", .index),
        ],
        stocks: [
            sym("RY.TO", "RY", "Royal Bank of Canada", .stock),
            sym("ENB.TO", "ENB", "Enbridge Inc.", .stock),
            sym("SHOP.TO", "SHOP", "Shopify Inc.", .stock),
        ],
        etfs: [], commodities: []
    )

    private static let allRegions: [String: StocksRegion] = [
        "US": usRegion, "IN": indiaRegion, "GB": ukRegion,
        "DE": germanyRegion, "JP": japanRegion, "CA": canadaRegion,
    ]
}

//
//  CryptoUniverse.swift
//  MiniPi
//
//  Curated coin lists for the Crypto Home tab. Yahoo Finance quotes cryptocurrencies via
//  the dash form (e.g. BTC-USD), so each coin is built from its base/quote codes. Home
//  is always coins compared to the US dollar (USD); the Home tab segments into
//  All / Top Gainers / Top Losers (split by sign in the repository). Coins that fail or
//  have no price are dropped by the repository.
//
//  Crypto has no Markets tab and no country resolver (unlike Stocks) — the curated
//  universe lives entirely here. Adding a coin = add it to `homeCoins` below. Keep the
//  list short — each coin is a chart call (Yahoo rate-limits heavy use with HTTP 429).
//

import Foundation

enum CryptoUniverse {

    /// The USD-quoted coins shown on Home ("coins compared to the dollar").
    static let homeCoins: [CryptoCoin] = [
        coin("BTC", "USD"),
        coin("ETH", "USD"),
        coin("BNB", "USD"),
        coin("SOL", "USD"),
        coin("XRP", "USD"),
        coin("ADA", "USD"),
        coin("AVAX", "USD"),
        coin("DOGE", "USD"),
        coin("DOT", "USD"),
        coin("LINK", "USD"),
        coin("MATIC", "USD"),
        coin("LTC", "USD"),
        coin("TRX", "USD"),
        coin("SHIB", "USD"),
        coin("UNI", "USD"),
    ]

    // MARK: - Builder

    /// Build a `CryptoCoin` from base/quote codes.
    static func coin(_ base: String, _ quote: String) -> CryptoCoin {
        let yahooSymbol = "\(base)-\(quote)"
        return CryptoCoin(
            id: yahooSymbol,
            symbol: yahooSymbol,
            base: base,
            quote: quote,
            description: CryptoCoinNames.name(for: base)
        )
    }
}

// MARK: - Coin name table

/// Coin ticker → full name, for the coin description / detail subtitle.
enum CryptoCoinNames {
    private static let names: [String: String] = [
        "BTC": "Bitcoin",
        "ETH": "Ethereum",
        "USDT": "Tether",
        "BNB": "BNB",
        "SOL": "Solana",
        "XRP": "XRP",
        "USDC": "USD Coin",
        "ADA": "Cardano",
        "AVAX": "Avalanche",
        "DOGE": "Dogecoin",
        "DOT": "Polkadot",
        "LINK": "Chainlink",
        "MATIC": "Polygon",
        "LTC": "Litecoin",
        "TRX": "TRON",
        "SHIB": "Shiba Inu",
        "UNI": "Uniswap",
        "PEPE": "Pepe",
        "ATOM": "Cosmos",
        "XLM": "Stellar",
        "NEAR": "NEAR Protocol",
        "APT": "Aptos",
        "FIL": "Filecoin",
        "ARB": "Arbitrum",
        "OP": "Optimism",
        "VET": "VeChain",
        "ICP": "Internet Computer",
        "SUI": "Sui",
        "SEI": "Sei",
        "TIA": "Celestia",
    ]

    static func name(for code: String) -> String {
        names[code.uppercased()] ?? code.uppercased()
    }
}

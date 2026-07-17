//
//  ForexUniverse.swift
//  MiniPi
//
//  Curated currency-pair lists for the Forex Home + Markets tabs. Yahoo Finance quotes
//  forex pairs via the `=X` suffix (e.g. EURUSD=X), so each pair is built from its
//  base/quote ISO codes. Home is always currencies compared to the US dollar (USD);
//  Markets segments into majors / minors / exotics. Pairs that fail or have no rate
//  are dropped by the repository.
//
//  Adding a pair = add it to the relevant list below. Keep lists short — each pair is a
//  chart call (Yahoo rate-limits heavy use with HTTP 429).
//

import Foundation

enum ForexUniverse {

    /// The USD-quoted majors shown on Home ("currencies compared to the dollar").
    static let homePairs: [ForexPair] = majors

    /// Majors: the seven most-traded pairs (always include USD).
    static let majors: [ForexPair] = [
        pair("EUR", "USD"),
        pair("GBP", "USD"),
        pair("USD", "JPY"),
        pair("USD", "CHF"),
        pair("AUD", "USD"),
        pair("USD", "CAD"),
        pair("NZD", "USD"),
    ]

    /// Minors (crosses): liquid pairs WITHOUT USD.
    static let minors: [ForexPair] = [
        pair("EUR", "GBP"),
        pair("EUR", "JPY"),
        pair("GBP", "JPY"),
        pair("AUD", "JPY"),
        pair("EUR", "AUD"),
        pair("GBP", "AUD"),
        pair("EUR", "CHF"),
        pair("AUD", "NZD"),
        pair("CAD", "JPY"),
        pair("CHF", "JPY"),
    ]

    /// Exotics: a currency vs a major, low-liquidity pairs.
    static let exotics: [ForexPair] = [
        pair("USD", "TRY"),
        pair("USD", "ZAR"),
        pair("USD", "MXN"),
        pair("USD", "SGD"),
        pair("USD", "HKD"),
        pair("USD", "SEK"),
        pair("USD", "NOK"),
        pair("USD", "PLN"),
        pair("EUR", "TRY"),
        pair("USD", "THB"),
    ]

    /// Pairs for a Markets segment.
    static func pairs(for segment: ForexSegment) -> [ForexPair] {
        switch segment {
        case .majors: return majors
        case .minors: return minors
        case .exotics: return exotics
        }
    }

    // MARK: - Builder

    /// Build a `ForexPair` from base/quote ISO codes.
    static func pair(_ base: String, _ quote: String) -> ForexPair {
        let yahooSymbol = "\(base)\(quote)=X"
        return ForexPair(
            id: yahooSymbol,
            symbol: yahooSymbol,
            base: base,
            quote: quote,
            description: "\(ForexCurrencyNames.name(for: base)) / \(ForexCurrencyNames.name(for: quote))"
        )
    }
}

// MARK: - Currency name table

/// ISO 4217 code → full currency name, for the pair description / detail subtitle.
enum ForexCurrencyNames {
    private static let names: [String: String] = [
        "USD": "US Dollar",
        "EUR": "Euro",
        "GBP": "British Pound",
        "JPY": "Japanese Yen",
        "CHF": "Swiss Franc",
        "AUD": "Australian Dollar",
        "CAD": "Canadian Dollar",
        "NZD": "New Zealand Dollar",
        "TRY": "Turkish Lira",
        "ZAR": "South African Rand",
        "MXN": "Mexican Peso",
        "SGD": "Singapore Dollar",
        "HKD": "Hong Kong Dollar",
        "SEK": "Swedish Krona",
        "NOK": "Norwegian Krone",
        "PLN": "Polish Zloty",
        "THB": "Thai Baht",
        "CNY": "Chinese Yuan",
        "INR": "Indian Rupee",
        "BRL": "Brazilian Real",
        "RUB": "Russian Ruble",
        "KRW": "South Korean Won",
        "DKK": "Danish Krone",
        "CZK": "Czech Koruna",
        "HUF": "Hungarian Forint",
    ]

    static func name(for code: String) -> String {
        names[code.uppercased()] ?? code.uppercased()
    }
}

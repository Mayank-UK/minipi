//
//  Indicator.swift
//  MiniPi
//
//  Domain models for the Indicators feature. Mirrors the AI Models layer: plain value
//  types with the derived text helpers the UI needs. Powers Home (catalog aggregates),
//  Ranking (countries sorted by an indicator, for a chosen year), Search (client-side
//  indicator filter), Compare (countries side by side across indicators) and Stats
//  (charts).
//
//  Source = World Bank Open Data API (`https://api.worldbank.org/v2`, no API key). The
//  country list is fetched live; the indicator set is a curated collection of important,
//  well-covered development metrics (poverty, health, education, environment). The full
//  yearly series is fetched per indicator (concurrently, drop-on-failure, like the Yahoo
//  bulk-quote pattern) so the user can pick a year; the catalog holds every observation
//  (country × indicator × year) and views derive client-side from it.
//
//  Indicators are mixed units — percentages, currency (GDP per capita), years, per-1000
//  rates and counts (population). Formatting is per `IndicatorFormat`, never a one-size
//  currency symbol. Some metrics are "lower is better" (poverty, mortality); Ranking
//  honours `higherIsBetter`.
//

import Foundation

// MARK: - Country

/// A World Bank country (aggregates filtered out). `id` is the ISO3 code (e.g. "USA").
struct Country: Identifiable, Equatable {
    let id: String          // ISO3 code, e.g. "USA"
    let name: String        // "United States"
    let iso2: String        // "US"
    let region: String      // "Latin America & Caribbean"
    let incomeLevel: String // "High income"
    let capital: String     // "Oranjestad"

    /// Emoji flag derived from the ISO2 code (regional indicator symbols).
    var flag: String {
        let upper = iso2.uppercased()
        guard upper.count == 2,
              let a = upper.first, let b = upper.last,
              let v1 = a.asciiValue, let v2 = b.asciiValue,
              (65...90).contains(v1), (65...90).contains(v2) else {
            return "🏳️"
        }
        let base: UInt32 = 0x1F1E6
        let s1 = UnicodeScalar(base + UInt32(v1 - 65))!
        let s2 = UnicodeScalar(base + UInt32(v2 - 65))!
        return String(s1) + String(s2)
    }

    /// One-line subtitle: region · income.
    var subtitle: String {
        "\(region.trimmingCharacters(in: .whitespaces)) · \(incomeLevel)"
    }
}

// MARK: - Indicator category

/// Topic grouping for the Search / Stats tabs. A curated, important set: Economy, Health,
/// Education, Environment.
enum IndicatorCategory: String, CaseIterable, Identifiable {
    case economy
    case health
    case education
    case environment

    var id: String { rawValue }

    var title: String {
        switch self {
        case .economy: return "Economy"
        case .health: return "Health"
        case .education: return "Education"
        case .environment: return "Environment"
        }
    }

    var icon: String {
        switch self {
        case .economy: return "banknote.fill"
        case .health: return "heart.text.clipboard"
        case .education: return "book.fill"
        case .environment: return "leaf.fill"
        }
    }
}

// MARK: - Indicator value format

/// How to render an indicator value. Indicators are mixed units; this keeps formatting
/// exact per indicator (percent / currency / years / per-1000 / compact count).
enum IndicatorFormat: Equatable {
    case percent
    case currency
    case years
    case perThousand
    case count

    /// Short unit label used in subtitles / chart axes.
    var unitLabel: String {
        switch self {
        case .percent: return "%"
        case .currency: return "USD"
        case .years: return "years"
        case .perThousand: return "per 1k"
        case .count: return "people"
        }
    }
}

// MARK: - Indicator definition

/// A curated World Bank indicator. Static metadata lives here (code / name / category /
/// format / direction); the values come from the live observation fetch.
struct Indicator: Identifiable, Equatable {
    let id: String              // World Bank code, e.g. "SP.DYN.LE00.IN"
    let name: String            // "Life expectancy at birth"
    let category: IndicatorCategory
    let format: IndicatorFormat
    let higherIsBetter: Bool    // false for poverty, mortality, etc.
    let sourceNote: String      // WB description for the detail sheet

    /// Short label under the name: category + unit.
    var subtitle: String {
        "\(category.title) · \(format.unitLabel)"
    }

    /// Format a value for this indicator. Returns "—" when there is no data.
    func formatValue(_ value: Double?) -> String {
        guard let value else { return "—" }
        switch format {
        case .percent:
            return String(format: "%.1f%%", value)
        case .currency:
            return Self.formatCurrency(value)
        case .years:
            return String(format: "%.1f yrs", value)
        case .perThousand:
            return String(format: "%.1f per 1k", value)
        case .count:
            return Self.formatCompact(value)
        }
    }

    /// Currency with grouping, no decimals (e.g. "$45,230").
    static func formatCurrency(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        let grouped = f.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
        return "$\(grouped)"
    }

    /// Compact count (1.43B / 340M / 12K).
    static func formatCompact(_ value: Double) -> String {
        if value >= 1_000_000_000 {
            return String(format: "%.2fB", value / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        }
        return String(format: "%.0f", value)
    }
}

/// The curated indicator set (≈ CryptoUniverse). Important, broadly-covered development
/// metrics across Economy / Health / Education / Environment. One entry per World Bank
/// code we fetch. Adding an indicator = one line here (the remote fetch loops over these
/// codes, drop-on-failure).
enum CuratedIndicators {
    static let all: [Indicator] = [
        Indicator(
            id: "SP.DYN.LE00.IN",
            name: "Life expectancy at birth",
            category: .health,
            format: .years,
            higherIsBetter: true,
            sourceNote: "Life expectancy at birth indicates the number of years a newborn infant would live if prevailing patterns of age-specific mortality rates were to stay the same throughout its life."
        ),
        Indicator(
            id: "NY.GDP.PCAP.CD",
            name: "GDP per capita",
            category: .economy,
            format: .currency,
            higherIsBetter: true,
            sourceNote: "GDP per capita is gross domestic product divided by midyear population. GDP is the sum of gross value added by all resident producers in the economy plus product taxes and minus subsidies not included in the value of products."
        ),
        Indicator(
            id: "SI.POV.DDAY",
            name: "Poverty headcount ($2.15/day)",
            category: .economy,
            format: .percent,
            higherIsBetter: false,
            sourceNote: "Poverty headcount ratio at $2.15 a day is the percentage of the population living on less than $2.15 a day at 2017 international prices."
        ),
        Indicator(
            id: "SP.POP.TOTL",
            name: "Population, total",
            category: .economy,
            format: .count,
            higherIsBetter: true,
            sourceNote: "Total population is based on the de facto definition of population, which counts all residents regardless of legal status or citizenship."
        ),
        Indicator(
            id: "SH.DYN.MORT",
            name: "Under-5 mortality rate",
            category: .health,
            format: .perThousand,
            higherIsBetter: false,
            sourceNote: "Under-five mortality rate is the probability per 1,000 that a newborn baby will die before reaching age five, if subject to age-specific mortality rates of the specified year."
        ),
        Indicator(
            id: "SH.H2O.BASW.ZS",
            name: "Basic drinking water access",
            category: .health,
            format: .percent,
            higherIsBetter: true,
            sourceNote: "People using at least basic drinking water services (% of population). Basic drinking water services are defined as an improved drinking water source located within 30 minutes round trip."
        ),
        Indicator(
            id: "SE.ADT.LITR.ZS",
            name: "Adult literacy rate",
            category: .education,
            format: .percent,
            higherIsBetter: true,
            sourceNote: "Adult literacy rate is the percentage of people ages 15 and above who can both read and write with understanding a short simple statement about their everyday life."
        ),
        Indicator(
            id: "SE.PRM.ENRR",
            name: "Primary school enrollment",
            category: .education,
            format: .percent,
            higherIsBetter: true,
            sourceNote: "Gross enrollment ratio is the number of students enrolled in primary education regardless of age, expressed as a percentage of the population of official primary education age."
        ),
        Indicator(
            id: "EG.ELC.ACCS.ZS",
            name: "Access to electricity",
            category: .environment,
            format: .percent,
            higherIsBetter: true,
            sourceNote: "Access to electricity is the percentage of population with access to electricity."
        ),
        Indicator(
            id: "AG.LND.FRST.ZS",
            name: "Forest area",
            category: .environment,
            format: .percent,
            higherIsBetter: true,
            sourceNote: "Forest area is land under natural or planted stands of trees of at least 5 meters in situ, whether productive or not, expressed as a percentage of total land area."
        ),
    ]

    /// The headline indicator used for Home's "Top Performers" list — picked for broad
    /// coverage and universal relevance.
    static let headline = all[0]
}

// MARK: - Observation

/// One data point: a country's value for an indicator in a specific year. The catalog
/// holds the full fetched series (all years in the window) so the user can pick a year.
struct Observation: Equatable {
    let countryId: String
    let indicatorId: String
    let year: Int
    let value: Double
}

// MARK: - Summary (Home aggregates)

/// Aggregate counts over the catalog, shown as StatTiles on Home.
struct WorldSummary: Equatable {
    let countryCount: Int
    let indicatorCount: Int
    let latestYear: Int       // most recent year seen across observations
    let dataPointCount: Int   // total observations cached

    static let empty = WorldSummary(countryCount: 0, indicatorCount: 0, latestYear: 0, dataPointCount: 0)

    static func build(countries: [Country], indicators: [Indicator], observations: [Observation]) -> WorldSummary {
        let latestYear = observations.map(\.year).max() ?? 0
        return WorldSummary(
            countryCount: countries.count,
            indicatorCount: indicators.count,
            latestYear: latestYear,
            dataPointCount: observations.count
        )
    }

    /// Compact year text for the Home tile ("2023" / "—").
    var latestYearText: String {
        latestYear > 0 ? "\(latestYear)" : "—"
    }
}

// MARK: - Catalog (cache-backed overview)

/// The full fetched dataset + aggregate summary. The cache type for this feature
/// (≈ `AIModelCatalog`). Cache-backed fetch; Ranking / Search / Compare / Stats derive
/// from `countries` / `indicators` / `observations` client-side, optionally filtered to a
/// selected year.
struct WorldDataCatalog: Equatable {
    let summary: WorldSummary
    let countries: [Country]
    let indicators: [Indicator]
    let observations: [Observation]

    static let empty = WorldDataCatalog(summary: .empty, countries: [], indicators: [], observations: [])
}

// MARK: - Search filter

/// Toggleable category filters on the Search tab. Client-side over the curated indicators.
/// (Kept as an enum rather than reusing `IndicatorCategory` directly so the "All" state is
/// expressible as an empty filter set, matching the app's AND-filter convention.)
enum IndicatorFilter: String, CaseIterable, Identifiable {
    case economy
    case health
    case education
    case environment

    var id: String { rawValue }

    var title: String { category.title }
    var icon: String { category.icon }

    var category: IndicatorCategory {
        switch self {
        case .economy: return .economy
        case .health: return .health
        case .education: return .education
        case .environment: return .environment
        }
    }

    func matches(_ indicator: Indicator) -> Bool {
        indicator.category == category
    }
}

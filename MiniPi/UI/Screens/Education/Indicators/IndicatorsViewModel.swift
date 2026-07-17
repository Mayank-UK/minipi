//
//  IndicatorsViewModel.swift
//  MiniPi
//
//  World Bank-backed Indicators feature. Mirrors AIModelsViewModel's overview flow for the
//  single cache-backed catalog fetch (Home aggregates), then derives Ranking / Search /
//  Compare / Stats client-side over the cached countries + observations — no per-item
//  network calls. Tabs: Home · Ranking · Search · Compare · Stats.
//
//  There is no Watchlist (so no save state), and the catalog already carries every
//  country's latest values, so opening a country detail sheet is instant (no sub-fetch).
//

import Foundation
import FactoryKit
import SwiftUI

@MainActor
class IndicatorsViewModel: ObservableObject {

    private let logger: AppLoggerProtocol
    private let fetchWorldDataUseCase: FetchWorldDataUseCase

    // MARK: - Catalog (Home + Ranking + Search + Compare + Stats)
    @Published var catalog: WorldDataCatalog?
    @Published var isLoading: Bool = false
    @Published var currentFailure: Failure?

    // MARK: - Tab
    @Published var selectedTab: IndicatorsTab = .home

    // MARK: - Ranking (countries ranked by a selected indicator, for a chosen year)
    @Published var selectedIndicator: Indicator = CuratedIndicators.headline
    /// `nil` = use each country's most recent available year ("Latest").
    @Published var selectedYear: Int? = nil
    /// Distinct years present in the data, descending — drives the year picker.
    @Published var availableYears: [Int] = []
    /// Cap the ranked list so the Ranking tab stays scrollable.
    let rankingLimit = 50

    // MARK: - Search (client-side over the curated indicators)
    @Published var searchQuery: String = ""
    @Published var searchFilters: Set<IndicatorFilter> = []

    // MARK: - Compare (countries side by side across indicators)
    @Published var compareSelection: [Country] = []
    @Published var compareQuery: String = ""
    @Published var showComparePicker: Bool = false
    let compareLimit = 4

    // MARK: - Stats (chart dimension = an indicator)
    @Published var statsIndicator: Indicator = CuratedIndicators.headline

    // MARK: - Country detail (sheet)
    @Published var detailCountry: Country?

    private var hasLoadedCatalog = false

    /// Lookup index: "countryId|indicatorId" -> [year: value]. Rebuilt when the catalog
    /// loads, so year-aware ranking/search over a 20k-point catalog stays O(countries).
    private var index: [String: [Int: Double]] = [:]

    init(
        logger: AppLoggerProtocol = Container.shared.viewModelLogger(),
        fetchWorldData: FetchWorldDataUseCase
    ) {
        self.logger = logger
        self.fetchWorldDataUseCase = fetchWorldData
        logger.info("IndicatorsViewModel initialized")
    }

    // MARK: - Catalog load

    func bootstrap() async {
        if hasLoadedCatalog { return }
        await loadCatalog(force: false)
    }

    func loadCatalog(force: Bool = false) async {
        if isLoading { return }
        if hasLoadedCatalog && !force { return }

        isLoading = true
        currentFailure = nil

        logger.info("Loading World Bank data catalog")
        let result = await fetchWorldDataUseCase.execute()

        switch result {
        case .success(let catalog):
            self.catalog = catalog
            self.hasLoadedCatalog = true
            ingest(catalog)
            logger.info("Loaded World Bank catalog: \(catalog.countries.count) countries, \(catalog.observations.count) data points")
        case .failure(let failure):
            self.currentFailure = failure
            logger.error("Failed to load World Bank catalog: \(failure.localizedDescription)")
        }

        isLoading = false
    }

    func clearError() {
        currentFailure = nil
    }

    /// Build the lookup index and the available-year list from a freshly loaded catalog.
    private func ingest(_ catalog: WorldDataCatalog) {
        var idx: [String: [Int: Double]] = [:]
        var years = Set<Int>()
        for o in catalog.observations {
            idx["\(o.countryId)|\(o.indicatorId)", default: [:]][o.year] = o.value
            years.insert(o.year)
        }
        index = idx
        availableYears = years.sorted(by: >)
        // Reset an out-of-range selection (e.g. after a refresh with a different window).
        if let y = selectedYear, !years.contains(y) {
            selectedYear = nil
        }
    }

    // MARK: - Value lookups (client-side over the cached observations)

    /// Value for a country × indicator. `year == nil` means each country's most recent
    /// available year ("Latest"); a concrete year requires that exact year to be present
    /// (countries missing that year return nil and drop out of rankings).
    func value(for countryId: String, indicatorId: String, year: Int? = nil) -> Double? {
        guard let series = index["\(countryId)|\(indicatorId)"] else { return nil }
        if let year {
            return series[year]
        }
        return series.max { $0.key < $1.key }?.value
    }

    /// Average value of an indicator across the countries that have data for the year
    /// (Home highlights). `year == nil` averages each country's latest value.
    func average(for indicatorId: String, year: Int? = nil) -> Double? {
        guard let catalog else { return nil }
        let values = catalog.countries.compactMap { value(for: $0.id, indicatorId: indicatorId, year: year) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Countries that have a value for the given indicator/year, ranked (higherIsBetter).
    func rankedCountries(for indicator: Indicator, year: Int? = nil) -> [Country] {
        guard let catalog else { return [] }
        return catalog.countries
            .compactMap { country -> (Country, Double)? in
                guard let v = value(for: country.id, indicatorId: indicator.id, year: year) else { return nil }
                return (country, v)
            }
            .sorted { indicator.higherIsBetter ? $0.1 > $1.1 : $0.1 < $1.1 }
            .map(\.0)
    }

    /// Top-N (Country, value) pairs for an indicator/year — used by Home highlights & Stats.
    func topValues(for indicator: Indicator, limit: Int, year: Int? = nil) -> [(Country, Double)] {
        guard let catalog else { return [] }
        return catalog.countries
            .compactMap { country -> (Country, Double)? in
                guard let v = value(for: country.id, indicatorId: indicator.id, year: year) else { return nil }
                return (country, v)
            }
            .sorted { indicator.higherIsBetter ? $0.1 > $1.1 : $0.1 < $1.1 }
            .prefix(limit)
            .map { ($0.0, $0.1) }
    }

    // MARK: - Ranking

    /// Countries ranked by the selected indicator + year, capped for scroll performance.
    var rankedCountries: [Country] {
        Array(rankedCountries(for: selectedIndicator, year: selectedYear).prefix(rankingLimit))
    }

    // MARK: - Search (client-side)

    var searchResults: [Indicator] {
        guard let catalog else { return [] }
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return catalog.indicators.filter { indicator in
            if !searchFilters.allSatisfy({ $0.matches(indicator) }) { return false }
            guard !query.isEmpty else { return true }
            if indicator.name.lowercased().contains(query) { return true }
            if indicator.id.lowercased().contains(query) { return true }
            if indicator.category.title.lowercased().contains(query) { return true }
            return false
        }
    }

    func toggleFilter(_ filter: IndicatorFilter) {
        if searchFilters.contains(filter) {
            searchFilters.remove(filter)
        } else {
            searchFilters.insert(filter)
        }
    }

    /// Pick an indicator (from Search or a StatTile) and jump to its ranking.
    func focusIndicator(_ indicator: Indicator) {
        selectedIndicator = indicator
        selectedTab = .ranking
    }

    // MARK: - Compare

    func isInCompare(_ country: Country) -> Bool {
        compareSelection.contains(where: { $0.id == country.id })
    }

    var canAddToCompare: Bool {
        compareSelection.count < compareLimit
    }

    func toggleCompare(_ country: Country) {
        if let index = compareSelection.firstIndex(where: { $0.id == country.id }) {
            compareSelection.remove(at: index)
        } else if compareSelection.count < compareLimit {
            compareSelection.append(country)
        }
    }

    func removeFromCompare(_ country: Country) {
        compareSelection.removeAll { $0.id == country.id }
    }

    /// Catalog countries matching the compare picker search, minus those already selected.
    var compareCandidates: [Country] {
        guard let catalog else { return [] }
        let query = compareQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return catalog.countries.filter { country in
            !isInCompare(country) && (query.isEmpty
                || country.name.lowercased().contains(query)
                || country.id.lowercased().contains(query)
                || country.region.lowercased().contains(query))
        }
    }

    // MARK: - Detail

    func openDetail(_ country: Country) {
        detailCountry = country
    }

    func closeDetail() {
        detailCountry = nil
    }
}

// MARK: - Tab model

enum IndicatorsTab: Hashable, CaseIterable {
    case home, ranking, search, compare, stats

    var title: String {
        switch self {
        case .home: return "Home"
        case .ranking: return "Ranking"
        case .search: return "Search"
        case .compare: return "Compare"
        case .stats: return "Stats"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .ranking: return "list.number"
        case .search: return "magnifyingglass"
        case .compare: return "rectangle.split.3x1"
        case .stats: return "chart.bar.fill"
        }
    }
}

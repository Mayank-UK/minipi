//
//  AIModelsViewModel.swift
//  MiniPi
//
//  OpenRouter-backed AI Models feature. Mirrors CryptoViewModel's overview flow for the
//  single cache-backed catalog fetch (Home aggregates), then derives Ranking / Search /
//  Compare client-side over the cached models — no per-item network calls. Tabs:
//  Home · Ranking · Search · Compare.
//
//  There is no Watchlist (so no save state), and the catalog already carries every
//  model's full data, so opening a detail sheet is instant (no sub-fetch).
//

import Foundation
import FactoryKit
import SwiftUI

@MainActor
class AIModelsViewModel: ObservableObject {

    private let logger: AppLoggerProtocol
    private let fetchCatalogUseCase: FetchAIModelCatalogUseCase

    // MARK: - Catalog (Home + Ranking + Search + Compare)
    @Published var catalog: AIModelCatalog?
    @Published var isLoading: Bool = false
    @Published var currentFailure: Failure?

    // MARK: - Tab
    @Published var selectedTab: AIModelsTab = .home

    // MARK: - Ranking
    @Published var selectedRank: AIModelRank = .overall
    /// Cap the ranked list so the Ranking tab stays scrollable over a 300+ catalog.
    let rankingLimit = 50

    // MARK: - Search (client-side over the cached catalog)
    @Published var searchQuery: String = ""
    @Published var searchFilters: Set<AIModelFilter> = []

    // MARK: - Compare
    @Published var compareSelection: [AIModel] = []
    @Published var compareQuery: String = ""
    @Published var showComparePicker: Bool = false
    let compareLimit = 4

    // MARK: - Detail (sheet)
    @Published var detailModel: AIModel?

    private var hasLoadedCatalog = false

    init(
        logger: AppLoggerProtocol = Container.shared.viewModelLogger(),
        fetchCatalog: FetchAIModelCatalogUseCase
    ) {
        self.logger = logger
        self.fetchCatalogUseCase = fetchCatalog
        logger.info("AIModelsViewModel initialized")
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

        logger.info("Loading AI model catalog")
        let result = await fetchCatalogUseCase.execute()

        switch result {
        case .success(let catalog):
            self.catalog = catalog
            self.hasLoadedCatalog = true
            logger.info("Loaded AI model catalog: \(catalog.models.count) models")
        case .failure(let failure):
            self.currentFailure = failure
            logger.error("Failed to load AI model catalog: \(failure.localizedDescription)")
        }

        isLoading = false
    }

    func clearError() {
        currentFailure = nil
    }

    // MARK: - Ranking

    /// Models ranked by the selected dimension, capped for scroll performance.
    var rankedModels: [AIModel] {
        guard let catalog else { return [] }
        return Array(selectedRank.sort(catalog.models).prefix(rankingLimit))
    }

    // MARK: - Search (client-side)

    var searchResults: [AIModel] {
        guard let catalog else { return [] }
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return catalog.models.filter { model in
            // Every active filter must pass (AND across filters).
            if !searchFilters.allSatisfy({ $0.matches(model) }) { return false }
            guard !query.isEmpty else { return true }
            if model.name.lowercased().contains(query) { return true }
            if model.id.lowercased().contains(query) { return true }
            if model.provider.lowercased().contains(query) { return true }
            return false
        }
    }

    func toggleFilter(_ filter: AIModelFilter) {
        if searchFilters.contains(filter) {
            searchFilters.remove(filter)
        } else {
            searchFilters.insert(filter)
        }
    }

    /// Jump from a Home StatTile to the Search tab with a filter pre-applied.
    func openFilterFromHome(_ filter: AIModelFilter) {
        searchQuery = ""
        searchFilters = [filter]
        selectedTab = .search
    }

    // MARK: - Compare

    func isInCompare(_ model: AIModel) -> Bool {
        compareSelection.contains(where: { $0.id == model.id })
    }

    var canAddToCompare: Bool {
        compareSelection.count < compareLimit
    }

    func toggleCompare(_ model: AIModel) {
        if let index = compareSelection.firstIndex(where: { $0.id == model.id }) {
            compareSelection.remove(at: index)
        } else if compareSelection.count < compareLimit {
            compareSelection.append(model)
        }
    }

    func removeFromCompare(_ model: AIModel) {
        compareSelection.removeAll { $0.id == model.id }
    }

    /// Catalog models matching the compare picker search, minus those already selected.
    var compareCandidates: [AIModel] {
        guard let catalog else { return [] }
        let query = compareQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return catalog.models.filter { model in
            !isInCompare(model) && (query.isEmpty || model.name.lowercased().contains(query) || model.id.lowercased().contains(query))
        }
    }

    // MARK: - Detail

    func openDetail(_ model: AIModel) {
        detailModel = model
    }

    func closeDetail() {
        detailModel = nil
    }
}

// MARK: - Tab model

enum AIModelsTab: Hashable, CaseIterable {
    case home, ranking, search, compare

    var title: String {
        switch self {
        case .home: return "Home"
        case .ranking: return "Ranking"
        case .search: return "Search"
        case .compare: return "Compare"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .ranking: return "list.number"
        case .search: return "magnifyingglass"
        case .compare: return "rectangle.split.3x1"
        }
    }
}

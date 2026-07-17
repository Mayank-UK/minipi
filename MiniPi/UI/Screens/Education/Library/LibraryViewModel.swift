//
//  LibraryViewModel.swift
//  MiniPi
//
//  Open Library-backed Library feature. Mirrors CryptoViewModel: isLoading /
//  currentFailure for the Home overview, the tab selection (Home · Search · Ranking ·
//  Watchlist), a server-backed book search (debounced, scoped to books/authors/subjects),
//  an on-demand trending load for the Ranking tab, an on-demand detail load for the book
//  sheet, and a persisted watchlist.
//

import Foundation
import FactoryKit
import SwiftUI
import Combine

@MainActor
class LibraryViewModel: ObservableObject {

    private let logger: AppLoggerProtocol
    private let fetchOverviewUseCase: FetchLibraryOverviewUseCase
    private let searchLibraryUseCase: SearchLibraryUseCase
    private let trendingUseCase: TrendingLibraryUseCase
    private let fetchWorkUseCase: FetchLibraryWorkUseCase
    let watchlist: LibraryWatchlistStore

    // MARK: - Home overview
    @Published var homeOverview: LibraryHomeOverview?
    @Published var isLoading: Bool = false
    @Published var currentFailure: Failure?

    // MARK: - Tab + search scope
    @Published var selectedTab: LibraryTab = .home
    @Published var selectedScope: LibrarySearchScope = .books

    // MARK: - Search (server-backed, debounced)
    @Published var searchQuery: String = ""
    @Published var searchResults: [LibraryWork] = []
    @Published var isSearching: Bool = false
    @Published var searchFailure: Failure?
    private var searchTask: Task<Void, Never>?

    // MARK: - Discover (the Search tab's default content when the query is empty, so the
    // screen never looks broken/empty before the user types)
    @Published var discoverBooks: [LibraryWork] = []
    @Published var isDiscoverLoading: Bool = false
    private var hasLoadedDiscover = false

    // MARK: - Ranking (trending)
    @Published var trendingPeriod: LibraryTrendingPeriod = .now
    @Published var trendingBooks: [LibraryWork] = []
    @Published var isTrendingLoading: Bool = false
    @Published var trendingFailure: Failure?

    // MARK: - Detail (sheet)
    @Published var detailWork: LibraryWork?
    @Published var detail: LibraryBookDetail?
    @Published var isLoadingDetail: Bool = false
    @Published var detailFailure: Failure?

    private var hasLoadedOverview = false

    init(
        logger: AppLoggerProtocol = Container.shared.viewModelLogger(),
        fetchOverview: FetchLibraryOverviewUseCase,
        searchLibrary: SearchLibraryUseCase,
        trending: TrendingLibraryUseCase,
        fetchWork: FetchLibraryWorkUseCase,
        watchlist: LibraryWatchlistStore
    ) {
        self.logger = logger
        self.fetchOverviewUseCase = fetchOverview
        self.searchLibraryUseCase = searchLibrary
        self.trendingUseCase = trending
        self.fetchWorkUseCase = fetchWork
        self.watchlist = watchlist

        logger.info("LibraryViewModel initialized")
    }

    // MARK: - Home overview

    func bootstrap() async {
        if hasLoadedOverview { return }
        await loadOverview(force: false)
    }

    func loadOverview(force: Bool = false) async {
        if isLoading { return }
        if hasLoadedOverview && !force { return }

        isLoading = true
        currentFailure = nil

        logger.info("Loading library overview")
        let result = await fetchOverviewUseCase.execute()

        switch result {
        case .success(let overview):
            self.homeOverview = overview
            self.hasLoadedOverview = true
            logger.info("Loaded library overview: \(overview.trendingBooks.count) trending, \(overview.popularSubjects.count) subjects")
        case .failure(let failure):
            self.currentFailure = failure
            logger.error("Failed to load library overview: \(failure.localizedDescription)")
        }

        isLoading = false
    }

    func clearError() {
        currentFailure = nil
    }

    // MARK: - Search (server-backed, debounced)

    /// Schedule a debounced search. Cancels pending/in-flight searches so only the latest
    /// query wins. First keystroke after a pause pays the debounce; explicit drill-downs
    /// (Home subject tap) can pass `immediate: true`.
    func scheduleSearch(immediate: Bool = false) {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchTask?.cancel()
            searchResults = []
            isSearching = false
            return
        }

        searchTask?.cancel()
        searchTask = Task { [weak self] in
            guard let self else { return }
            if !immediate {
                try? await Task.sleep(nanoseconds: 350_000_000)
                if Task.isCancelled { return }
            }
            await self.performSearch(query: query)
        }
    }

    /// Re-run the current query against a new scope (filter chip tap).
    func searchCurrentScope(immediate: Bool = true) {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        scheduleSearch(immediate: immediate)
    }

    private func performSearch(query: String) async {
        if isSearching { return }
        isSearching = true
        searchFailure = nil

        logger.info("Running library search for \(query) (\(selectedScope.rawValue))")
        let result = await searchLibraryUseCase.execute(query: query, scope: selectedScope)

        if Task.isCancelled { isSearching = false; return }

        switch result {
        case .success(let works):
            self.searchResults = works
            logger.info("Search returned \(works.count) works")
        case .failure(let failure):
            self.searchResults = []
            self.searchFailure = failure
            logger.error("Search failed: \(failure.localizedDescription)")
        }

        isSearching = false
    }

    func clearSearchError() {
        searchFailure = nil
    }

    // MARK: - Discover (Search tab default content)

    /// Loads the "Popular right now" list shown when the Search tab has no query yet.
    /// Reuses the trending data source (`.now`) so there's no new endpoint; loads once.
    func loadDiscover(force: Bool = false) async {
        if isDiscoverLoading { return }
        if hasLoadedDiscover && !force { return }

        isDiscoverLoading = true
        let result = await trendingUseCase.execute(period: .now)
        if case .success(let works) = result {
            self.discoverBooks = works
            self.hasLoadedDiscover = true
            logger.info("Loaded \(works.count) discover works")
        }
        isDiscoverLoading = false
    }

    // MARK: - Ranking (trending)

    func loadTrending(period: LibraryTrendingPeriod = .now, force: Bool = false) async {
        if isTrendingLoading { return }
        if period == trendingPeriod && !trendingBooks.isEmpty && !force { return }

        trendingPeriod = period
        isTrendingLoading = true
        trendingFailure = nil

        logger.info("Loading trending (\(period.rawValue))")
        let result = await trendingUseCase.execute(period: period)

        switch result {
        case .success(let works):
            self.trendingBooks = works
            logger.info("Loaded \(works.count) trending works (\(period.rawValue))")
        case .failure(let failure):
            self.trendingFailure = failure
            logger.error("Trending failed: \(failure.localizedDescription)")
        }

        isTrendingLoading = false
    }

    func clearTrendingError() {
        trendingFailure = nil
    }

    // MARK: - Watchlist

    func toggleWatchlist(work: LibraryWork) {
        watchlist.toggle(work: work)
    }

    func isSaved(_ work: LibraryWork) -> Bool {
        watchlist.contains(id: work.id)
    }

    /// Home StatTile → jump to a tab (mirrors Indicators/AIModels tappable StatTiles).
    func openTab(_ tab: LibraryTab) {
        selectedTab = tab
    }

    /// Home subject tile → pre-fill a subject search and switch to the Search tab.
    func searchSubject(_ subject: LibrarySubject) {
        selectedTab = .search
        prefillSearch(scope: .subjects, query: subject.displayName)
    }

    /// Search-tab author/subject discover tap → pre-fill a scoped query and run it. Also the
    /// engine behind the Home subject shortcut.
    func prefillSearch(scope: LibrarySearchScope, query: String) {
        selectedScope = scope
        searchQuery = query
        scheduleSearch(immediate: true)
    }

    /// "Popular authors" for the Search tab's empty-query Authors scope — derived from the
    /// trending works (no trending-authors endpoint exists). Sorted by appearance count.
    var discoverAuthors: [LibraryAuthorSummary] {
        var counts: [String: Int] = [:]
        for work in discoverBooks {
            for author in work.authors {
                let name = author.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                counts[name, default: 0] += 1
            }
        }
        return counts
            .map { LibraryAuthorSummary(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count || ($0.count == $1.count && $0.name < $1.name) }
    }

    // MARK: - Detail

    func openDetail(_ work: LibraryWork) {
        detailWork = work
        detail = nil
        detailFailure = nil
        Task { await loadDetail(for: work) }
    }

    func closeDetail() {
        detailWork = nil
    }

    func loadDetail(for work: LibraryWork) async {
        isLoadingDetail = true
        detailFailure = nil

        let result = await fetchWorkUseCase.execute(id: work.id)
        if case .success(let detail) = result {
            self.detail = detail
        } else if case .failure(let failure) = result {
            self.detailFailure = failure
        }

        isLoadingDetail = false
    }

    func clearDetailError() {
        detailFailure = nil
    }
}

// MARK: - Tab model

enum LibraryTab: Hashable, CaseIterable {
    case home, search, ranking, watchlist

    var title: String {
        switch self {
        case .home: return "Home"
        case .search: return "Search"
        case .ranking: return "Ranking"
        case .watchlist: return "Watchlist"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .ranking: return "list.number"
        case .watchlist: return "star.fill"
        }
    }
}

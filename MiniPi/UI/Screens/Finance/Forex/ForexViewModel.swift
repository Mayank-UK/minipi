//
//  ForexViewModel.swift
//  MiniPi
//
//  Yahoo-backed Forex feature. Mirrors StocksViewModel: isLoading / currentFailure for
//  the Home dataset, the tab selection (Home · Markets · Search · Watchlist · Stats), a
//  server-backed pair search (debounced), on-demand rate/candle loads for the detail
//  sheet, and a persisted watchlist.
//
//  Forex has no "country" — the Home view is always currencies compared to the US
//  dollar, so there is no country store (unlike Stocks).
//

import Foundation
import FactoryKit
import SwiftUI
import Combine

@MainActor
class ForexViewModel: ObservableObject {

    private let logger: AppLoggerProtocol
    private let fetchOverviewUseCase: FetchForexOverviewUseCase
    private let rateUseCase: ForexRateUseCase
    private let ratesUseCase: ForexRatesUseCase
    private let candlesUseCase: ForexCandlesUseCase
    private let searchForexUseCase: SearchForexUseCase
    let watchlist: ForexWatchlistStore

    // MARK: - Market overview (Home + Stats)
    @Published var marketOverview: ForexMarketOverview?
    @Published var isLoading: Bool = false
    @Published var currentFailure: Failure?

    // MARK: - Tab + segment
    @Published var selectedTab: ForexTab = .home
    @Published var selectedSegment: ForexSegment = .majors

    // MARK: - Markets list (segment rates)
    @Published var marketsQuotes: [ForexQuoteItem] = []
    @Published var isLoadingMarkets: Bool = false
    @Published var marketsFailure: Failure?
    private var loadedMarketSegment: ForexSegment?

    // MARK: - Search (server autocomplete, debounced)
    @Published var searchQuery: String = ""
    @Published var searchResults: [ForexQuoteItem] = []
    @Published var isSearching: Bool = false
    @Published var searchFailure: Failure?
    private var searchTask: Task<Void, Never>?

    // MARK: - Watchlist rates
    @Published var watchlistQuotes: [ForexQuoteItem] = []

    // MARK: - Detail (sheet)
    @Published var detailPair: ForexPair?
    @Published var detailQuote: ForexQuote?
    @Published var detailCandle: ForexCandle?
    @Published var isLoadingDetail: Bool = false
    @Published var detailFailure: Failure?

    private var hasLoadedOverview = false

    init(
        logger: AppLoggerProtocol = Container.shared.viewModelLogger(),
        fetchOverview: FetchForexOverviewUseCase,
        rate: ForexRateUseCase,
        rates: ForexRatesUseCase,
        candles: ForexCandlesUseCase,
        searchForex: SearchForexUseCase,
        watchlist: ForexWatchlistStore
    ) {
        self.logger = logger
        self.fetchOverviewUseCase = fetchOverview
        self.rateUseCase = rate
        self.ratesUseCase = rates
        self.candlesUseCase = candles
        self.searchForexUseCase = searchForex
        self.watchlist = watchlist

        logger.info("ForexViewModel initialized")
    }

    // MARK: - Market overview (Home + Stats)

    func bootstrap() async {
        if hasLoadedOverview { return }
        await loadOverview(force: false)
    }

    func loadOverview(force: Bool = false) async {
        if isLoading { return }
        if hasLoadedOverview && !force { return }

        isLoading = true
        currentFailure = nil

        logger.info("Loading forex overview (USD majors)")
        let result = await fetchOverviewUseCase.execute()

        switch result {
        case .success(let overview):
            self.marketOverview = overview
            self.hasLoadedOverview = true
            logger.info("Loaded forex overview: \(overview.pairs.count) majors")
        case .failure(let failure):
            self.currentFailure = failure
            logger.error("Failed to load forex overview: \(failure.localizedDescription)")
        }

        isLoading = false
    }

    func clearError() {
        currentFailure = nil
    }

    // MARK: - Markets segment rates

    /// Pairs for the active segment.
    func pairs(for segment: ForexSegment) -> [ForexPair] {
        ForexUniverse.pairs(for: segment)
    }

    func selectSegment(_ segment: ForexSegment) {
        selectedSegment = segment
        Task { await loadMarkets(force: false) }
    }

    func loadMarkets(force: Bool = false) async {
        if isLoadingMarkets { return }
        if loadedMarketSegment == selectedSegment && !force { return }

        isLoadingMarkets = true
        marketsFailure = nil

        let pairs = pairs(for: selectedSegment)
        logger.info("Loading markets rates for \(selectedSegment.rawValue) (\(pairs.count) pairs)")
        let result = await ratesUseCase.execute(pairs: pairs)

        switch result {
        case .success(let items):
            self.marketsQuotes = items
            self.loadedMarketSegment = selectedSegment
            logger.info("Markets returned \(items.count) rates")
        case .failure(let failure):
            self.marketsFailure = failure
            logger.error("Markets failed: \(failure.localizedDescription)")
        }

        isLoadingMarkets = false
    }

    // MARK: - Search (server autocomplete, debounced)

    /// Schedule a debounced search. Cancels pending/in-flight searches so only the
    /// latest query wins. First keystroke after a pause pays the debounce; explicit
    /// drill-downs can pass `immediate: true`.
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

    private func performSearch(query: String) async {
        if isSearching { return }
        isSearching = true
        searchFailure = nil

        logger.info("Running forex search for \(query)")
        let result = await searchForexUseCase.execute(query: query)

        if Task.isCancelled { isSearching = false; return }

        switch result {
        case .success(let pairs):
            // Quote the matched pairs so the results list shows live rates.
            let quoted = await ratesUseCase.execute(pairs: pairs)
            self.searchResults = quoted.successValue ?? []
            logger.info("Search returned \(pairs.count) pairs, \(self.searchResults.count) quoted")
        case .failure(let failure):
            self.searchFailure = failure
            logger.error("Search failed: \(failure.localizedDescription)")
        }

        isSearching = false
    }

    func clearSearchError() {
        searchFailure = nil
    }

    // MARK: - Watchlist

    func refreshWatchlist() async {
        let pairs = watchlist.pairs
        guard !pairs.isEmpty else { watchlistQuotes = []; return }
        let result = await ratesUseCase.execute(pairs: pairs)
        if case .success(let items) = result {
            watchlistQuotes = items
            // Keep saved snapshots' last rate in sync.
            for item in items {
                watchlist.updateQuote(for: item.pair.id, quote: item.quote)
            }
        }
    }

    func toggleWatchlist(pair: ForexPair, quote: ForexQuote?) {
        watchlist.toggle(pair: pair, quote: quote)
        Task { await refreshWatchlist() }
    }

    func isSaved(_ pair: ForexPair) -> Bool {
        watchlist.contains(id: pair.id)
    }

    // MARK: - Detail

    func openDetail(_ pair: ForexPair) {
        detailPair = pair
        detailQuote = nil
        detailCandle = nil
        detailFailure = nil
        Task { await loadDetail(for: pair) }
    }

    func closeDetail() {
        detailPair = nil
    }

    func loadDetail(for pair: ForexPair) async {
        isLoadingDetail = true
        detailFailure = nil

        async let rateResult = rateUseCase.execute(symbol: pair.symbol)
        async let candleResult = candlesUseCase.execute(ForexCandleQuery(symbol: pair.symbol, resolution: .day, days: 90))

        let rateR = await rateResult
        let candleR = await candleResult

        if case .success(let q) = rateR { self.detailQuote = q }
        if case .success(let c) = candleR { self.detailCandle = c }

        if rateR.isFailure && candleR.isFailure {
            self.detailFailure = rateR.failureValue ?? candleR.failureValue
        }

        isLoadingDetail = false
    }

    func clearDetailError() {
        detailFailure = nil
    }
}

// MARK: - Tab model

enum ForexTab: Hashable, CaseIterable {
    case home, markets, search, watchlist, stats

    var title: String {
        switch self {
        case .home: return "Home"
        case .markets: return "Markets"
        case .search: return "Search"
        case .watchlist: return "Watchlist"
        case .stats: return "Stats"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .markets: return "chart.bar.fill"
        case .search: return "magnifyingglass"
        case .watchlist: return "star.fill"
        case .stats: return "chart.line.uptrend.xyaxis"
        }
    }
}

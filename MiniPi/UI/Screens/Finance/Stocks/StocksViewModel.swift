//
//  StocksViewModel.swift
//  MiniPi
//
//  Finnhub-backed Stocks feature. Mirrors WeatherViewModel: isLoading / currentFailure
//  for the Home dataset, the tab selection (Home · Markets · Search · Watchlist · Stats),
//  a server-backed instrument search (debounced), on-demand quote/candle/profile loads
//  for the detail sheet, and a persisted watchlist + country.
//
//  Default market is resolved from the device region (Locale.current.region) via
//  StocksCountryStore; the Home country picker overrides it and persists.
//

import Foundation
import FactoryKit
import SwiftUI
import Combine

@MainActor
class StocksViewModel: ObservableObject {

    private let logger: AppLoggerProtocol
    private let fetchMarketOverviewUseCase: FetchMarketOverviewUseCase
    private let quoteUseCase: QuoteUseCase
    private let quotesUseCase: QuotesUseCase
    private let candlesUseCase: CandlesUseCase
    private let searchStocksUseCase: SearchStocksUseCase
    private let profileUseCase: StockProfileUseCase
    let watchlist: StocksWatchlistStore
    let countryStore: StocksCountryStore

    // MARK: - Market overview (Home + Stats)
    @Published var marketOverview: StockMarketOverview?
    @Published var isLoading: Bool = false
    @Published var currentFailure: Failure?

    // MARK: - Tab + segment
    @Published var selectedTab: StocksTab = .home
    @Published var selectedSegment: StockSegment = .indices

    // MARK: - Markets list (segment quotes)
    @Published var marketsQuotes: [StockQuoteItem] = []
    @Published var isLoadingMarkets: Bool = false
    @Published var marketsFailure: Failure?
    private var loadedMarketSegment: StockSegment?

    // MARK: - Search (server autocomplete, debounced)
    @Published var searchQuery: String = ""
    @Published var searchResults: [StockQuoteItem] = []
    @Published var isSearching: Bool = false
    @Published var searchFailure: Failure?
    private var searchTask: Task<Void, Never>?

    // MARK: - Watchlist quotes
    @Published var watchlistQuotes: [StockQuoteItem] = []

    // MARK: - Detail (sheet)
    @Published var detailSymbol: StockSymbol?
    @Published var detailQuote: StockQuote?
    @Published var detailProfile: StockProfile?
    @Published var detailCandle: StockCandle?
    @Published var isLoadingDetail: Bool = false
    @Published var detailFailure: Failure?

    private var hasLoadedOverview = false

    init(
        logger: AppLoggerProtocol = Container.shared.viewModelLogger(),
        fetchMarketOverview: FetchMarketOverviewUseCase,
        quote: QuoteUseCase,
        quotes: QuotesUseCase,
        candles: CandlesUseCase,
        searchStocks: SearchStocksUseCase,
        profile: StockProfileUseCase,
        watchlist: StocksWatchlistStore,
        countryStore: StocksCountryStore
    ) {
        self.logger = logger
        self.fetchMarketOverviewUseCase = fetchMarketOverview
        self.quoteUseCase = quote
        self.quotesUseCase = quotes
        self.candlesUseCase = candles
        self.searchStocksUseCase = searchStocks
        self.profileUseCase = profile
        self.watchlist = watchlist
        self.countryStore = countryStore

        logger.info("StocksViewModel initialized")
    }

    // MARK: - Region / country

    var activeCountry: String { countryStore.countryCode }

    var activeRegion: StocksRegion {
        StockUniverse.region(for: countryStore.countryCode)
    }

    func selectCountry(_ code: String) {
        countryStore.set(code)
        hasLoadedOverview = false
        loadedMarketSegment = nil
        marketsQuotes = []
        Task {
            await loadOverview(force: true)
            if selectedTab == .markets { await loadMarkets(force: true) }
        }
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

        logger.info("Loading market overview for \(activeCountry)")
        let result = await fetchMarketOverviewUseCase.execute(country: activeCountry)

        switch result {
        case .success(let overview):
            self.marketOverview = overview
            self.hasLoadedOverview = true
            logger.info("Loaded market overview for \(overview.country)")
        case .failure(let failure):
            self.currentFailure = failure
            logger.error("Failed to load market overview: \(failure.localizedDescription)")
        }

        isLoading = false
    }

    func clearError() {
        currentFailure = nil
    }

    // MARK: - Markets segment quotes

    /// Symbols for the active segment + region.
    func symbols(for segment: StockSegment) -> [StockSymbol] {
        let region = activeRegion
        switch segment {
        case .indices: return region.indices
        case .stocks: return region.stocks
        case .etfs: return region.etfs
        case .commodities: return region.commodities
        }
    }

    func selectSegment(_ segment: StockSegment) {
        selectedSegment = segment
        Task { await loadMarkets(force: false) }
    }

    func loadMarkets(force: Bool = false) async {
        if isLoadingMarkets { return }
        if loadedMarketSegment == selectedSegment && !force { return }

        isLoadingMarkets = true
        marketsFailure = nil

        let symbols = symbols(for: selectedSegment)
        logger.info("Loading markets quotes for \(selectedSegment.rawValue) (\(symbols.count) symbols)")
        let result = await quotesUseCase.execute(symbols: symbols)

        switch result {
        case .success(let items):
            self.marketsQuotes = items
            self.loadedMarketSegment = selectedSegment
            logger.info("Markets returned \(items.count) quotes")
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

        logger.info("Running instrument search for \(query)")
        let result = await searchStocksUseCase.execute(query: query)

        if Task.isCancelled { isSearching = false; return }

        switch result {
        case .success(let symbols):
            // Quote the matched symbols so the results list shows live prices.
            let quoted = await quotesUseCase.execute(symbols: symbols)
            self.searchResults = quoted.successValue ?? []
            logger.info("Search returned \(symbols.count) symbols, \(self.searchResults.count) quoted")
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
        let symbols = watchlist.symbols
        guard !symbols.isEmpty else { watchlistQuotes = []; return }
        let result = await quotesUseCase.execute(symbols: symbols)
        if case .success(let items) = result {
            watchlistQuotes = items
            // Keep saved snapshots' last price in sync.
            for item in items {
                watchlist.updateQuote(for: item.symbol.id, quote: item.quote)
            }
        }
    }

    func toggleWatchlist(symbol: StockSymbol, quote: StockQuote?, currency: String?) {
        watchlist.toggle(symbol: symbol, quote: quote, currency: currency)
        Task { await refreshWatchlist() }
    }

    func isSaved(_ symbol: StockSymbol) -> Bool {
        watchlist.contains(id: symbol.id)
    }

    // MARK: - Detail

    func openDetail(_ symbol: StockSymbol) {
        detailSymbol = symbol
        detailQuote = nil
        detailProfile = nil
        detailCandle = nil
        detailFailure = nil
        Task { await loadDetail(for: symbol) }
    }

    func closeDetail() {
        detailSymbol = nil
    }

    func loadDetail(for symbol: StockSymbol) async {
        isLoadingDetail = true
        detailFailure = nil

        async let quoteResult = quoteUseCase.execute(symbol: symbol.symbol, currency: symbol.currency)
        async let candleResult = candlesUseCase.execute(StocksCandleQuery(symbol: symbol.symbol, resolution: .day, days: 90))
        async let profileResult = profileUseCase.execute(symbol: symbol.symbol)

        let quoteR = await quoteResult
        let candleR = await candleResult
        let profileR = await profileResult

        if case .success(let q) = quoteR { self.detailQuote = q }
        if case .success(let c) = candleR { self.detailCandle = c }
        if case .success(let p) = profileR { self.detailProfile = p }

        if quoteR.isFailure && candleR.isFailure && profileR.isFailure {
            self.detailFailure = quoteR.failureValue ?? candleR.failureValue ?? profileR.failureValue
        }

        isLoadingDetail = false
    }

    func clearDetailError() {
        detailFailure = nil
    }
}

// MARK: - Tab model

enum StocksTab: Hashable, CaseIterable {
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

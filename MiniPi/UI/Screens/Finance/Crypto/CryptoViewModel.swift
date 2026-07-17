//
//  CryptoViewModel.swift
//  MiniPi
//
//  Yahoo-backed Crypto feature. Mirrors ForexViewModel minus the Markets tab: isLoading /
//  currentFailure for the Home dataset, the tab selection (Home · Search · Watchlist ·
//  Stats), a server-backed coin search (debounced), on-demand price/candle loads for the
//  detail sheet, and a persisted watchlist.
//
//  Crypto has no "country" and no Markets tab — the Home view is always coins compared
//  to the US dollar, segmented into All / Top Gainers / Top Losers (split by sign in the
//  repository).
//

import Foundation
import FactoryKit
import SwiftUI
import Combine

@MainActor
class CryptoViewModel: ObservableObject {

    private let logger: AppLoggerProtocol
    private let fetchOverviewUseCase: FetchCryptoOverviewUseCase
    private let priceUseCase: CryptoPriceUseCase
    private let pricesUseCase: CryptoPricesUseCase
    private let candlesUseCase: CryptoCandlesUseCase
    private let searchCryptoUseCase: SearchCryptoUseCase
    let watchlist: CryptoWatchlistStore

    // MARK: - Market overview (Home + Stats)
    @Published var marketOverview: CryptoMarketOverview?
    @Published var isLoading: Bool = false
    @Published var currentFailure: Failure?

    // MARK: - Tab + Home segment
    @Published var selectedTab: CryptoTab = .home
    @Published var selectedSegment: CryptoSegment = .all

    // MARK: - Search (server autocomplete, debounced)
    @Published var searchQuery: String = ""
    @Published var searchResults: [CryptoQuoteItem] = []
    @Published var isSearching: Bool = false
    @Published var searchFailure: Failure?
    private var searchTask: Task<Void, Never>?

    // MARK: - Watchlist prices
    @Published var watchlistQuotes: [CryptoQuoteItem] = []

    // MARK: - Detail (sheet)
    @Published var detailCoin: CryptoCoin?
    @Published var detailQuote: CryptoQuote?
    @Published var detailCandle: CryptoCandle?
    @Published var isLoadingDetail: Bool = false
    @Published var detailFailure: Failure?

    private var hasLoadedOverview = false

    init(
        logger: AppLoggerProtocol = Container.shared.viewModelLogger(),
        fetchOverview: FetchCryptoOverviewUseCase,
        price: CryptoPriceUseCase,
        prices: CryptoPricesUseCase,
        candles: CryptoCandlesUseCase,
        searchCrypto: SearchCryptoUseCase,
        watchlist: CryptoWatchlistStore
    ) {
        self.logger = logger
        self.fetchOverviewUseCase = fetchOverview
        self.priceUseCase = price
        self.pricesUseCase = prices
        self.candlesUseCase = candles
        self.searchCryptoUseCase = searchCrypto
        self.watchlist = watchlist

        logger.info("CryptoViewModel initialized")
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

        logger.info("Loading crypto overview (USD coins)")
        let result = await fetchOverviewUseCase.execute()

        switch result {
        case .success(let overview):
            self.marketOverview = overview
            self.hasLoadedOverview = true
            logger.info("Loaded crypto overview: \(overview.all.count) coins")
        case .failure(let failure):
            self.currentFailure = failure
            logger.error("Failed to load crypto overview: \(failure.localizedDescription)")
        }

        isLoading = false
    }

    func clearError() {
        currentFailure = nil
    }

    /// Coins for the active Home segment (All / Top Gainers / Top Losers).
    func items(for segment: CryptoSegment) -> [CryptoQuoteItem] {
        guard let overview = marketOverview else { return [] }
        switch segment {
        case .all: return overview.all
        case .topGainers: return overview.topGainers
        case .topLosers: return overview.topLosers
        }
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

        logger.info("Running crypto search for \(query)")
        let result = await searchCryptoUseCase.execute(query: query)

        if Task.isCancelled { isSearching = false; return }

        switch result {
        case .success(let coins):
            // Quote the matched coins so the results list shows live prices.
            let quoted = await pricesUseCase.execute(coins: coins)
            self.searchResults = quoted.successValue ?? []
            logger.info("Search returned \(coins.count) coins, \(self.searchResults.count) quoted")
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
        let coins = watchlist.coins
        guard !coins.isEmpty else { watchlistQuotes = []; return }
        let result = await pricesUseCase.execute(coins: coins)
        if case .success(let items) = result {
            watchlistQuotes = items
            // Keep saved snapshots' last price in sync.
            for item in items {
                watchlist.updateQuote(for: item.coin.id, quote: item.quote)
            }
        }
    }

    func toggleWatchlist(coin: CryptoCoin, quote: CryptoQuote?) {
        watchlist.toggle(coin: coin, quote: quote)
        Task { await refreshWatchlist() }
    }

    func isSaved(_ coin: CryptoCoin) -> Bool {
        watchlist.contains(id: coin.id)
    }

    // MARK: - Detail

    func openDetail(_ coin: CryptoCoin) {
        detailCoin = coin
        detailQuote = nil
        detailCandle = nil
        detailFailure = nil
        Task { await loadDetail(for: coin) }
    }

    func closeDetail() {
        detailCoin = nil
    }

    func loadDetail(for coin: CryptoCoin) async {
        isLoadingDetail = true
        detailFailure = nil

        async let priceResult = priceUseCase.execute(symbol: coin.symbol)
        async let candleResult = candlesUseCase.execute(CryptoCandleQuery(symbol: coin.symbol, resolution: .day, days: 90))

        let priceR = await priceResult
        let candleR = await candleResult

        if case .success(let q) = priceR { self.detailQuote = q }
        if case .success(let c) = candleR { self.detailCandle = c }

        if priceR.isFailure && candleR.isFailure {
            self.detailFailure = priceR.failureValue ?? candleR.failureValue
        }

        isLoadingDetail = false
    }

    func clearDetailError() {
        detailFailure = nil
    }
}

// MARK: - Tab model

enum CryptoTab: Hashable, CaseIterable {
    case home, search, watchlist, stats

    var title: String {
        switch self {
        case .home: return "Home"
        case .search: return "Search"
        case .watchlist: return "Watchlist"
        case .stats: return "Stats"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .watchlist: return "star.fill"
        case .stats: return "chart.line.uptrend.xyaxis"
        }
    }
}

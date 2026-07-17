//
//  CryptoRepositoryImpl.swift
//  MiniPi
//
//  Mirrors ForexRepositoryImplementation: remote-first, persist to the local cache on
//  success, fall back to the cache on network/server error. Reuses safeRepositoryCall /
//  ExceptionMapper / the Failure family — no new error mechanism. The market overview
//  (Home + Stats) is cache-backed; price / candles / bulk-prices / search are one-shot.
//
//  Yahoo's `/v8/finance/chart` returns price + candle in one call, so price() and
//  candles() are thin ranges over `remote.chart`. The bulk-price fan-out fires chart
//  per coin concurrently via a TaskGroup and drops per-coin failures (unknown coin /
//  rate-limited), so one bad coin never blanks a list — same drop-on-failure pattern
//  as Stocks/Forex.
//

import Foundation
import FactoryKit

class CryptoRepositoryImplementation: CryptoRepository {

    private let remote: CryptoRemoteDataSource
    private let local: CryptoLocalDataSource
    private let logger: AppLoggerProtocol

    init(
        remote: CryptoRemoteDataSource,
        local: CryptoLocalDataSource,
        logger: AppLoggerProtocol = Container.shared.repositoryLogger()
    ) {
        self.remote = remote
        self.local = local
        self.logger = logger

        logger.info("CryptoRepository initialized")
    }

    // MARK: - Market overview (Home + Stats) — cache-backed

    func marketOverview() async -> Result<CryptoMarketOverview> {

        logger.info("Starting marketOverview operation (USD coins)")

        return await safeRepositoryCall(

            call: { [weak self] in
                guard let self else {
                    throw ServerException("Repository deallocated during operation")
                }

                // Quote the curated coins, then split movers by % change.
                let items = await self.bulkQuoteCoins(CryptoUniverse.homeCoins)

                // Gainers = strictly positive % (green), losers = strictly negative %
                // (red). Splitting by sign (not just top/bottom-N of one sort) avoids a
                // coin appearing in "gainers" with a red/negative change on a down day.
                let gainers = Array(
                    items
                        .filter { $0.quote.changePercent > 0 }
                        .sorted { $0.quote.changePercent > $1.quote.changePercent }
                        .prefix(5)
                )
                let losers = Array(
                    items
                        .filter { $0.quote.changePercent < 0 }
                        .sorted { $0.quote.changePercent < $1.quote.changePercent }
                        .prefix(5)
                )

                let overview = CryptoMarketOverview(
                    quoteLabel: "USD",
                    all: items,
                    topGainers: gainers,
                    topLosers: losers
                )

                logger.info("Built crypto overview: \(items.count) coins, \(gainers.count) gainers, \(losers.count) losers")

                logger.debug("Updating local cache with crypto overview")
                try self.local.replaceCryptoOverview(overview)
                logger.notice("Local cache updated with crypto overview")

                return overview
            },

            onNetworkError: { [weak self] networkException in
                self?.cachedFallback(on: networkException)
                    ?? .failure(ExceptionMapper.mapExceptionToFailure(networkException))
            },

            onServerError: { [weak self] serverException in
                self?.cachedFallback(on: serverException)
                    ?? .failure(ExceptionMapper.mapExceptionToFailure(serverException))
            }
        )
    }

    // MARK: - Price (one-shot)

    func price(_ symbol: String) async -> Result<CryptoQuote> {
        logger.info("Starting price operation (symbol: \(symbol))")
        return await safeRepositoryCall { [weak self] in
            guard let self else { throw ServerException("Repository deallocated during operation") }
            let chart = try await self.remote.chart(symbol: symbol, range: "1d", interval: "1d")
            guard let quote = chart.toCryptoQuote(symbol: symbol) else {
                throw ServerException("No price for \(symbol)", context: "CryptoRepository.price")
            }
            return quote
        }
    }

    // MARK: - Candles (one-shot)

    func candles(_ query: CryptoCandleQuery) async -> Result<CryptoCandle> {
        logger.info("Starting candles operation (symbol: \(query.symbol))")
        return await safeRepositoryCall { [weak self] in
            guard let self else { throw ServerException("Repository deallocated during operation") }
            let days = max(1, Int(query.to.timeIntervalSince(query.from) / 86_400))
            let range = CryptoRemoteDataSourceImpl.range(forDays: days)
            let chart = try await self.remote.chart(symbol: query.symbol, range: range, interval: "1d")
            return chart.toCryptoCandle(symbol: query.symbol, resolution: query.resolution.rawValue)
        }
    }

    // MARK: - Bulk prices (one-shot, concurrent fan-out)

    func prices(for coins: [CryptoCoin]) async -> Result<[CryptoQuoteItem]> {
        logger.info("Starting prices operation for \(coins.count) coins")
        return await safeRepositoryCall { [weak self] in
            guard let self else { throw ServerException("Repository deallocated during operation") }
            return await self.bulkQuoteCoins(coins)
        }
    }

    // MARK: - Search (one-shot)

    func search(query: String) async -> Result<[CryptoCoin]> {
        logger.info("Starting search operation (query: \(query))")
        return await safeRepositoryCall { [weak self] in
            guard let self else { throw ServerException("Repository deallocated during operation") }
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return [CryptoCoin]() }
            let results = try await self.remote.search(trimmed)
            logger.notice("Search returned \(results.count) results")
            return results.compactMap { $0.toCoin() }
        }
    }

    // MARK: - Concurrent bulk quote

    /// Quotes a list of coins concurrently via the chart endpoint, dropping any that
    /// fail or have no price. Fetches a 3-month daily series so each item also carries a
    /// sparkline (Home cards) with visible movement — a 1-month window moved too little
    /// to read as anything but a flat line. The chart call returns price (meta) and the
    /// series in one go. Preserves the input order.
    private func bulkQuoteCoins(_ coins: [CryptoCoin]) async -> [CryptoQuoteItem] {
        await withTaskGroup(of: (Int, CryptoQuoteItem?).self) { [weak self] group in
            for (index, coin) in coins.enumerated() {
                group.addTask {
                    guard let self else { return (index, nil) }
                    do {
                        let chart = try await self.remote.chart(symbol: coin.symbol, range: "3mo", interval: "1d")
                        guard let quote = chart.toCryptoQuote(symbol: coin.symbol) else { return (index, nil) }
                        // Sparkline = the daily close series (non-nil).
                        let sparkline = chart.toCryptoCandle(symbol: coin.symbol, resolution: "D").closes
                        return (index, CryptoQuoteItem(coin: coin, quote: quote, sparkline: sparkline))
                    } catch {
                        return (index, nil)
                    }
                }
            }
            var collected: [(Int, CryptoQuoteItem)] = []
            for await item in group {
                if let value = item.1 { collected.append((item.0, value)) }
            }
            return collected.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    // MARK: - Shared cache fallback (market overview only)

    private func cachedFallback(on exception: AppException) -> Result<CryptoMarketOverview>? {
        logger.error("Falling back to cache after: \(exception.localizedDescription)", privacy: .privateData)
        do {
            if let cached = try local.fetchCryptoOverview() {
                logger.notice("Retrieved cached crypto overview")
                return .success(cached)
            }
            return .failure(ExceptionMapper.mapExceptionToFailure(exception))
        } catch {
            let cacheFailure = ExceptionMapper.mapExceptionToFailure(
                error as? DatabaseException ?? DatabaseException.readFailed()
            )
            logger.error("Cache read failed: \(cacheFailure.localizedDescription)", privacy: .privateData)
            let base = ExceptionMapper.mapExceptionToFailure(exception)
            return .failure(NetworkFailure(base.message, severity: base.severity, cause: cacheFailure))
        }
    }
}

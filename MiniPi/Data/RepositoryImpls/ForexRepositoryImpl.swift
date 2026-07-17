//
//  ForexRepositoryImpl.swift
//  MiniPi
//
//  Mirrors StocksRepositoryImplementation: remote-first, persist to the local cache on
//  success, fall back to the cache on network/server error. Reuses safeRepositoryCall /
//  ExceptionMapper / the Failure family — no new error mechanism. The market overview
//  (Home + Stats) is cache-backed; rate / candles / bulk-rates / search are one-shot.
//
//  Yahoo's `/v8/finance/chart` returns rate + candle in one call, so rate() and
//  candles() are thin ranges over `remote.chart`. The bulk-rate fan-out fires chart
//  per pair concurrently via a TaskGroup and drops per-pair failures (unknown pair /
//  rate-limited), so one bad pair never blanks a list — same drop-on-failure pattern
//  as Stocks.
//

import Foundation
import FactoryKit

class ForexRepositoryImplementation: ForexRepository {

    private let remote: ForexRemoteDataSource
    private let local: ForexLocalDataSource
    private let logger: AppLoggerProtocol

    init(
        remote: ForexRemoteDataSource,
        local: ForexLocalDataSource,
        logger: AppLoggerProtocol = Container.shared.repositoryLogger()
    ) {
        self.remote = remote
        self.local = local
        self.logger = logger

        logger.info("ForexRepository initialized")
    }

    // MARK: - Market overview (Home + Stats) — cache-backed

    func marketOverview() async -> Result<ForexMarketOverview> {

        logger.info("Starting marketOverview operation (USD majors)")

        return await safeRepositoryCall(

            call: { [weak self] in
                guard let self else {
                    throw ServerException("Repository deallocated during operation")
                }

                // Quote the USD majors, then split movers by % change.
                let items = await self.bulkQuotePairs(ForexUniverse.homePairs)

                // Gainers = strictly positive % (green), losers = strictly negative %
                // (red). Splitting by sign (not just top/bottom-N of one sort) avoids a
                // pair appearing in "gainers" with a red/negative change on a down day.
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

                let overview = ForexMarketOverview(
                    baseLabel: "USD",
                    pairs: items,
                    topGainers: gainers,
                    topLosers: losers
                )

                logger.info("Built forex overview: \(items.count) majors, \(gainers.count) gainers, \(losers.count) losers")

                logger.debug("Updating local cache with forex overview")
                try self.local.replaceForexOverview(overview)
                logger.notice("Local cache updated with forex overview")

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

    // MARK: - Rate (one-shot)

    func rate(_ symbol: String) async -> Result<ForexQuote> {
        logger.info("Starting rate operation (symbol: \(symbol))")
        return await safeRepositoryCall { [weak self] in
            guard let self else { throw ServerException("Repository deallocated during operation") }
            let chart = try await self.remote.chart(symbol: symbol, range: "1d", interval: "1d")
            guard let quote = chart.toForexQuote(symbol: symbol) else {
                throw ServerException("No rate for \(symbol)", context: "ForexRepository.rate")
            }
            return quote
        }
    }

    // MARK: - Candles (one-shot)

    func candles(_ query: ForexCandleQuery) async -> Result<ForexCandle> {
        logger.info("Starting candles operation (symbol: \(query.symbol))")
        return await safeRepositoryCall { [weak self] in
            guard let self else { throw ServerException("Repository deallocated during operation") }
            let days = max(1, Int(query.to.timeIntervalSince(query.from) / 86_400))
            let range = ForexRemoteDataSourceImpl.range(forDays: days)
            let chart = try await self.remote.chart(symbol: query.symbol, range: range, interval: "1d")
            return chart.toForexCandle(symbol: query.symbol, resolution: query.resolution.rawValue)
        }
    }

    // MARK: - Bulk rates (one-shot, concurrent fan-out)

    func rates(for pairs: [ForexPair]) async -> Result<[ForexQuoteItem]> {
        logger.info("Starting rates operation for \(pairs.count) pairs")
        return await safeRepositoryCall { [weak self] in
            guard let self else { throw ServerException("Repository deallocated during operation") }
            return await self.bulkQuotePairs(pairs)
        }
    }

    // MARK: - Search (one-shot)

    func search(query: String) async -> Result<[ForexPair]> {
        logger.info("Starting search operation (query: \(query))")
        return await safeRepositoryCall { [weak self] in
            guard let self else { throw ServerException("Repository deallocated during operation") }
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return [ForexPair]() }
            let results = try await self.remote.search(trimmed)
            logger.notice("Search returned \(results.count) results")
            return results.compactMap { $0.toPair() }
        }
    }

    // MARK: - Concurrent bulk quote

    /// Quotes a list of pairs concurrently via the chart endpoint, dropping any that
    /// fail or have no rate. Fetches a 3-month daily series so each item also carries a
    /// sparkline (Home cards) with visible movement — a 1-month window moved too little
    /// to read as anything but a flat line. The chart call returns rate (meta) and the
    /// series in one go. Preserves the input order.
    private func bulkQuotePairs(_ pairs: [ForexPair]) async -> [ForexQuoteItem] {
        await withTaskGroup(of: (Int, ForexQuoteItem?).self) { [weak self] group in
            for (index, pair) in pairs.enumerated() {
                group.addTask {
                    guard let self else { return (index, nil) }
                    do {
                        let chart = try await self.remote.chart(symbol: pair.symbol, range: "3mo", interval: "1d")
                        guard let quote = chart.toForexQuote(symbol: pair.symbol) else { return (index, nil) }
                        // Sparkline = the daily close series (non-nil).
                        let sparkline = chart.toForexCandle(symbol: pair.symbol, resolution: "D").closes
                        return (index, ForexQuoteItem(pair: pair, quote: quote, sparkline: sparkline))
                    } catch {
                        return (index, nil)
                    }
                }
            }
            var collected: [(Int, ForexQuoteItem)] = []
            for await item in group {
                if let value = item.1 { collected.append((item.0, value)) }
            }
            return collected.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    // MARK: - Shared cache fallback (market overview only)

    private func cachedFallback(on exception: AppException) -> Result<ForexMarketOverview>? {
        logger.error("Falling back to cache after: \(exception.localizedDescription)", privacy: .privateData)
        do {
            if let cached = try local.fetchForexOverview() {
                logger.notice("Retrieved cached forex overview")
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

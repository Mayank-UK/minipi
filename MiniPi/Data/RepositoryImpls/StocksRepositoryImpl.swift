//
//  StocksRepositoryImpl.swift
//  MiniPi
//
//  Mirrors WeatherRepositoryImplementation: remote-first, persist to the local cache
//  on success, fall back to the cache on network/server error. Reuses
//  safeRepositoryCall / ExceptionMapper / the Failure family — no new error mechanism.
//  The market overview (Home + Stats) is cache-backed; quote / candles / search /
//  profile / bulk-quotes are one-shot.
//
//  Yahoo's `/v8/finance/chart` returns quote + candle in one call, so quote() and
//  candles() are thin ranges over `remote.chart`. The bulk-quote fan-out fires chart
//  per symbol concurrently via a TaskGroup and drops per-symbol failures (unknown
//  ticker / rate-limited), so one bad symbol never blanks a list — mirroring the
//  weather globe-points approach.
//
//  `profile` is best-effort: Yahoo's assetProfile endpoint needs a crumb/cookie we
//  don't fetch, so it returns nil and the detail view falls back to the symbol's
//  description (the search shortname). The chart meta still provides currency /
//  exchange for the detail stats.
//

import Foundation
import FactoryKit

class StocksRepositoryImplementation: StocksRepository {

    private let remote: StocksRemoteDataSource
    private let local: StocksLocalDataSource
    private let logger: AppLoggerProtocol

    init(
        remote: StocksRemoteDataSource,
        local: StocksLocalDataSource,
        logger: AppLoggerProtocol = Container.shared.repositoryLogger()
    ) {
        self.remote = remote
        self.local = local
        self.logger = logger

        logger.info("StocksRepository initialized")
    }

    // MARK: - Market overview (Home + Stats) — cache-backed

    func marketOverview(country: String) async -> Result<StockMarketOverview> {

        logger.info("Starting marketOverview operation (country: \(country))")

        return await safeRepositoryCall(

            call: { [weak self] in
                guard let self else {
                    throw ServerException("Repository deallocated during operation")
                }

                let region = StockUniverse.region(for: country)
                logger.debug("Building market overview for \(region.displayName)")

                // Quote the region's indices + stocks, then split movers by % change.
                let universe = region.indices + region.stocks
                let items = await self.bulkQuoteSymbols(universe)

                let indexTickers = Set(region.indices.map { $0.symbol })
                let indices = items.filter { indexTickers.contains($0.symbol.symbol) }
                let tradable = items.filter { !indexTickers.contains($0.symbol.symbol) }

                // Gainers = strictly positive % (green), losers = strictly negative %
                // (red). Splitting by sign (not just top/bottom-N of one sort) avoids
                // a stock appearing in "gainers" with a red/negative change on a down
                // day, which read as wrong.
                let gainers = Array(
                    tradable
                        .filter { $0.quote.changePercent > 0 }
                        .sorted { $0.quote.changePercent > $1.quote.changePercent }
                        .prefix(5)
                )
                let losers = Array(
                    tradable
                        .filter { $0.quote.changePercent < 0 }
                        .sorted { $0.quote.changePercent < $1.quote.changePercent }
                        .prefix(5)
                )

                let overview = StockMarketOverview(
                    country: region.displayName,
                    exchange: region.exchange,
                    indices: indices,
                    topGainers: gainers,
                    topLosers: losers
                )

                logger.info("Built market overview: \(indices.count) indices, \(gainers.count) gainers, \(losers.count) losers")

                logger.debug("Updating local cache with market overview")
                try self.local.replaceMarketOverview(overview)
                logger.notice("Local cache updated with market overview")

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

    // MARK: - Quote (one-shot)

    func quote(_ symbol: String, currency: String?) async -> Result<StockQuote> {
        logger.info("Starting quote operation (symbol: \(symbol))")
        return await safeRepositoryCall { [weak self] in
            guard let self else { throw ServerException("Repository deallocated during operation") }
            let chart = try await self.remote.chart(symbol: symbol, range: "1d", interval: "1d")
            guard let quote = chart.toQuote(symbol: symbol) else {
                throw ServerException("No quote for \(symbol)", context: "StocksRepository.quote")
            }
            return quote
        }
    }

    // MARK: - Candles (one-shot)

    func candles(_ query: StocksCandleQuery) async -> Result<StockCandle> {
        logger.info("Starting candles operation (symbol: \(query.symbol))")
        return await safeRepositoryCall { [weak self] in
            guard let self else { throw ServerException("Repository deallocated during operation") }
            let days = max(1, Int(query.to.timeIntervalSince(query.from) / 86_400))
            let range = StocksRemoteDataSourceImpl.range(forDays: days)
            let chart = try await self.remote.chart(symbol: query.symbol, range: range, interval: "1d")
            return chart.toCandle(symbol: query.symbol, resolution: query.resolution.rawValue)
        }
    }

    // MARK: - Bulk quotes (one-shot, concurrent fan-out)

    func quotes(for symbols: [StockSymbol]) async -> Result<[StockQuoteItem]> {
        logger.info("Starting quotes operation for \(symbols.count) symbols")
        return await safeRepositoryCall { [weak self] in
            guard let self else { throw ServerException("Repository deallocated during operation") }
            return await self.bulkQuoteSymbols(symbols)
        }
    }

    // MARK: - Search (one-shot)

    func search(query: String) async -> Result<[StockSymbol]> {
        logger.info("Starting search operation (query: \(query))")
        return await safeRepositoryCall { [weak self] in
            guard let self else { throw ServerException("Repository deallocated during operation") }
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return [StockSymbol]() }
            let results = try await self.remote.search(trimmed)
            logger.notice("Search returned \(results.count) results")
            return results.compactMap { $0.toSymbol() }
        }
    }

    // MARK: - Profile (best-effort → nil)

    func profile(_ symbol: String) async -> Result<StockProfile?> {
        // Yahoo's assetProfile endpoint requires a crumb we don't fetch; the detail
        // view falls back to the symbol description (search shortname) + chart meta.
        return .success(nil)
    }

    // MARK: - Concurrent bulk quote

    /// Quotes a list of symbols concurrently via the chart endpoint, dropping any
    /// that fail or have no price. Fetches a 1-month daily series so each item also
    /// carries a sparkline (Home index cards) — the chart call returns quote (meta)
    /// and the series in one go. Preserves the input order.
    private func bulkQuoteSymbols(_ symbols: [StockSymbol]) async -> [StockQuoteItem] {
        await withTaskGroup(of: (Int, StockQuoteItem?).self) { [weak self] group in
            for (index, symbol) in symbols.enumerated() {
                group.addTask {
                    guard let self else { return (index, nil) }
                    do {
                        let chart = try await self.remote.chart(symbol: symbol.symbol, range: "1mo", interval: "1d")
                        guard let quote = chart.toQuote(symbol: symbol.symbol) else { return (index, nil) }
                        // Sparkline = the daily close series (non-nil).
                        let sparkline = chart.toCandle(symbol: symbol.symbol, resolution: "D").closes
                        return (index, StockQuoteItem(symbol: symbol, quote: quote, sparkline: sparkline))
                    } catch {
                        return (index, nil)
                    }
                }
            }
            var collected: [(Int, StockQuoteItem)] = []
            for await item in group {
                if let value = item.1 { collected.append((item.0, value)) }
            }
            return collected.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    // MARK: - Shared cache fallback (market overview only)

    private func cachedFallback(on exception: AppException) -> Result<StockMarketOverview>? {
        logger.error("Falling back to cache after: \(exception.localizedDescription)", privacy: .privateData)
        do {
            if let cached = try local.fetchMarketOverview() {
                logger.notice("Retrieved cached market overview")
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

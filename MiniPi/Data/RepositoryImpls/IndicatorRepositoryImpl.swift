//
//  IndicatorRepositoryImpl.swift
//  MiniPi
//
//  Mirrors AIModelRepositoryImplementation: remote-first, persist to the local cache on
//  success, fall back to the cache on network/server error. Reuses safeRepositoryCall /
//  ExceptionMapper / the Failure family — no new error mechanism. The catalog (Home /
//  Ranking / Search / Compare / Stats) is the one cache-backed fetch.
//
//  The fetch assembles the dataset from a country-list call plus one observation call per
//  curated indicator. Indicator calls fan out concurrently via a TaskGroup and DROP per-
//  indicator failures (unknown indicator / rate-limited), so one bad indicator never
//  blanks the feature — the same drop-on-failure pattern the Yahoo bulk-quote and weather
//  globe-points fetches use. Per country × indicator we keep only the latest non-null
//  value (max year) before caching.
//

import Foundation
import FactoryKit

class IndicatorRepositoryImplementation: IndicatorRepository {

    private let remote: IndicatorRemoteDataSource
    private let local: IndicatorLocalDataSource
    private let logger: AppLoggerProtocol

    init(
        remote: IndicatorRemoteDataSource,
        local: IndicatorLocalDataSource,
        logger: AppLoggerProtocol = Container.shared.repositoryLogger()
    ) {
        self.remote = remote
        self.local = local
        self.logger = logger

        logger.info("IndicatorRepository initialized")
    }

    // MARK: - Catalog (Home + Ranking + Search + Compare + Stats) — cache-backed

    func catalog() async -> Result<WorldDataCatalog> {

        logger.info("Starting World Bank data catalog operation")

        return await safeRepositoryCall(

            call: { [weak self] in
                guard let self else {
                    throw ServerException("Repository deallocated during operation")
                }

                let indicators = CuratedIndicators.all
                let countries = try await self.remote.countries()
                logger.info("Fetched \(countries.count) countries, \(indicators.count) indicators")

                // Fan out observation calls per indicator, drop-on-failure.
                let observations = await self.fetchAllObservations(codes: indicators.map { $0.id })

                // Keep the full yearly series, restricted to real countries (drops World
                // Bank aggregate rows like "World", "EU", income groups). The UI picks the
                // year; we store them all.
                let countryIds = Set(countries.map { $0.id })
                let series = observations.filter { countryIds.contains($0.countryId) }
                logger.info("Kept \(series.count) observations (full series, real countries)")

                let summary = WorldSummary.build(countries: countries, indicators: indicators, observations: series)
                let catalog = WorldDataCatalog(summary: summary, countries: countries, indicators: indicators, observations: series)

                logger.info("Built World Bank catalog: \(countries.count) countries, \(series.count) data points")

                logger.debug("Updating local cache with World Bank catalog")
                try self.local.replaceWorldData(catalog)
                logger.notice("Local cache updated with World Bank catalog")

                return catalog
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

    // MARK: - Bulk observation fetch (drop-on-failure)

    /// Concurrently fetch observations for every curated indicator. Per-indicator failures
    /// are dropped (returns nil via `try?`) so the rest still populate the catalog.
    private func fetchAllObservations(codes: [String]) async -> [Observation] {
        await withTaskGroup(of: [Observation]?.self) { group in
            for code in codes {
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    do {
                        return try await self.remote.observations(for: code)
                    } catch {
                        self.logger.error("Dropped indicator \(code) after: \(error.localizedDescription)", privacy: .privateData)
                        return nil
                    }
                }
            }
            var all: [Observation] = []
            for await result in group {
                if let rows = result {
                    all.append(contentsOf: rows)
                }
            }
            return all
        }
    }

    /// Keep only the most recent (max year) observation per (country, indicator) pair.
    // (Full yearly series is now stored; year selection is handled client-side.)

    // MARK: - Shared cache fallback

    private func cachedFallback(on exception: AppException) -> Result<WorldDataCatalog>? {
        logger.error("Falling back to cache after: \(exception.localizedDescription)", privacy: .privateData)
        do {
            if let cached = try local.fetchWorldData() {
                logger.notice("Retrieved cached World Bank catalog")
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

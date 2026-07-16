//
//  EarthquakeRepositoryImpl.swift
//  MiniPi
//
//  Mirrors AsteroidRepositoryImplementation: remote-first, persist to the local
//  DB on success, fall back to the cache on network/server error. Reuses
//  safeRepositoryCall / ExceptionMapper / the Failure family — no new error
//  mechanism. Feed fetch is cache-backed; query + lookup are one-shot (no list
//  cache fallback), matching how the asteroid feed vs. lookup differ.
//

import Foundation
import FactoryKit

class EarthquakeRepositoryImplementation: EarthquakeRepository {

    private let remote: EarthquakeRemoteDataSource
    private let local: EarthquakeLocalDataSource
    private let logger: AppLoggerProtocol

    init(
        remote: EarthquakeRemoteDataSource,
        local: EarthquakeLocalDataSource,
        logger: AppLoggerProtocol = Container.shared.repositoryLogger()
    ) {
        self.remote = remote
        self.local = local
        self.logger = logger

        logger.info("EarthquakeRepository initialized")
    }

    // MARK: - Feed (Home / Map / Watchlist)

    func fetchEarthquakes(feed: EarthquakeFeed) async -> Result<[Earthquake]> {

        logger.info("Starting fetchEarthquakes operation (feed: \(feed.rawValue))")

        return await safeRepositoryCall(

            call: { [weak self] in

                guard let self else {
                    throw ServerException("Repository deallocated during operation")
                }

                logger.debug("Fetching \(feed.pathSegment) feed from USGS")
                let collection = try await self.remote.fetchFeed(feed)
                let dtos = collection.features
                logger.info("Successfully fetched \(dtos.count) earthquakes from USGS")

                logger.debug("Updating local database with \(dtos.count) earthquakes")
                try self.local.replaceEarthquakes(dtos)
                logger.notice("Database updated successfully with \(dtos.count) earthquakes")

                return dtos.map { $0.toEarthquake() }
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

    // MARK: - Query (Search) — one-shot, no list cache fallback

    func queryEarthquakes(_ query: EarthquakeQuery) async -> Result<[Earthquake]> {

        logger.info("Starting queryEarthquakes operation")

        return await safeRepositoryCall(

            call: { [weak self] in
                guard let self else {
                    throw ServerException("Repository deallocated during operation")
                }
                let collection = try await self.remote.query(query)
                logger.notice("Query returned \(collection.features.count) earthquakes")
                return collection.features.map { $0.toEarthquake() }
            }
        )
    }

    // MARK: - Lookup — one-shot

    func lookupEarthquake(id: String) async -> Result<Earthquake> {

        logger.info("Starting lookupEarthquake operation for id \(id)")

        return await safeRepositoryCall(

            call: { [weak self] in
                guard let self else {
                    throw ServerException("Repository deallocated during operation")
                }
                let collection = try await self.remote.lookup(id: id)
                guard let feature = collection.features.first else {
                    throw ServerException("No earthquake returned for id \(id)")
                }
                logger.notice("Looked up earthquake \(feature.id ?? id)")
                return feature.toEarthquake()
            }
        )
    }

    // MARK: - Shared cache fallback (feed only)

    private func cachedFallback(on exception: AppException) -> Result<[Earthquake]>? {
        logger.error("Falling back to cache after: \(exception.localizedDescription)", privacy: .privateData)
        do {
            let cached = try local.fetchEarthquakes()
            if !cached.isEmpty {
                logger.notice("Retrieved \(cached.count) earthquakes from cache")
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

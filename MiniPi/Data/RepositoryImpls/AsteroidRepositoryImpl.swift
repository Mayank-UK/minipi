//
//  AsteroidRepositoryImpl.swift
//  MiniPi
//
//  Mirrors PostRepositoryImplementation: remote-first, persist to the local DB on success,
//  fall back to the cache on network/server error. Reuses safeRepositoryCall / ExceptionMapper
//  / the Failure family — no new error mechanism (Module A §A.6).
//

import Foundation
import FactoryKit

class AsteroidRepositoryImplementation: AsteroidRepository {

    private let apiService: APIServiceProtocol
    private let database: DatabaseServiceProtocol
    private let logger: AppLoggerProtocol

    init(
        apiService: APIServiceProtocol,
        database: DatabaseServiceProtocol,
        logger: AppLoggerProtocol = Container.shared.repositoryLogger()
    ) {
        self.apiService = apiService
        self.database = database
        self.logger = logger

        logger.info("AsteroidRepository initialized")
    }

    func fetchAsteroids() async -> Result<[Asteroid]> {

        logger.info("Starting fetchAsteroids operation")

        // 7-day window centered on today (NASA `feed` allows max 7 days).
        let (startDate, endDate) = Self.weekWindow()

        return await safeRepositoryCall(

            call: { [weak self] in

                guard let self else {
                    throw ServerException("Repository deallocated during operation")
                }

                logger.debug("Fetching asteroid feed from NASA NeoWs")
                let feed = try await self.apiService.fetchAsteroidFeed(
                    startDate: startDate,
                    endDate: endDate
                )
                logger.info("Successfully fetched \(feed.elementCount) asteroids from API")

                // Flatten the date → [asteroid] dictionary, keeping a stable, date-sorted order.
                let dtos = Self.flatten(feed: feed)
                logger.debug("Updating local database with \(dtos.count) asteroids")
                try self.database.replaceAsteroids(dtos)
                logger.notice("Database updated successfully with \(dtos.count) asteroids")

                let asteroids = dtos.map { $0.toAsteroid() }
                logger.info("Returning \(asteroids.count) asteroids to caller")
                return asteroids
            },

            onNetworkError: { [weak self] networkException in

                guard let self else {
                    return .failure(
                        ExceptionMapper.mapExceptionToFailure(networkException)
                    )
                }

                self.logger.error("Network error occurred: \(networkException.localizedDescription)", privacy: .privateData)

                do {
                    self.logger.debug("Attempting to fetch cached asteroids from database")
                    let cached = try self.database.fetchAsteroids()

                    if !cached.isEmpty {
                        self.logger.notice("Successfully retrieved \(cached.count) asteroids from cache")
                        return .success(cached)
                    }

                    self.logger.error("Cache is empty, returning network failure")
                    return .failure(
                        ExceptionMapper.mapExceptionToFailure(networkException)
                    )
                } catch {
                    let cacheFailure = ExceptionMapper.mapExceptionToFailure(
                        error as? DatabaseException ?? DatabaseException.readFailed()
                    )

                    self.logger.error("Cache read failed: \(cacheFailure.localizedDescription)", privacy: .privateData)

                    let chainedFailure = NetworkFailure(
                        "Network failed - cache also unavailable",
                        severity: .warning,
                        cause: cacheFailure
                    )

                    return .failure(chainedFailure)
                }
            },

            onServerError: { [weak self] serverException in

                guard let self else {
                    return .failure(
                        ExceptionMapper.mapExceptionToFailure(serverException)
                    )
                }

                self.logger.error("Server error occurred: \(serverException.localizedDescription)", privacy: .privateData)

                do {
                    self.logger.debug("Attempting to fetch cached asteroids from database")
                    let cached = try self.database.fetchAsteroids()

                    if !cached.isEmpty {
                        self.logger.notice("Successfully retrieved \(cached.count) asteroids from cache")
                        return .success(cached)
                    }

                    self.logger.error("Cache is empty, returning server failure")
                    return .failure(
                        ExceptionMapper.mapExceptionToFailure(serverException)
                    )
                } catch {
                    let cacheFailure = ExceptionMapper.mapExceptionToFailure(
                        error as? DatabaseException ?? DatabaseException.readFailed()
                    )

                    self.logger.fault("Cache read failed: \(cacheFailure.localizedDescription)", privacy: .privateData)

                    let chainedFailure = ServerFailure(
                        "Server failed - cache also unavailable",
                        severity: .critical,
                        cause: cacheFailure,
                        statusCode: serverException.statusCode
                    )

                    return .failure(chainedFailure)
                }
            }
        )
    }

    /// Orbital asteroids for the 3D scene (Module A §A.4). Uses NASA's `neo/browse`
    /// catalog, which returns bodies already carrying `orbital_data` and spread across
    /// the whole NEO population — so the scene fills space all around the Sun instead
    /// of clustering near Earth like the close-approach `feed`. A handful of pages
    /// (pageSize × pageCount) gives a well-populated sky in just a few requests.
    func fetchOrbitalAsteroids() async -> Result<[Asteroid]> {

        logger.info("Starting fetchOrbitalAsteroids operation")

        return await safeRepositoryCall(

            call: { [weak self] in

                guard let self else {
                    throw ServerException("Repository deallocated during operation")
                }

                let pageSize = 20
                let pageCount = 5   // 5 × 20 = up to 100 catalog asteroids
                logger.debug("Fetching \(pageCount) browse pages (size \(pageSize)) from NASA NeoWs")

                let api = self.apiService
                let log = self.logger
                let pages: [NeoBrowseDTO] = await withTaskGroup(of: NeoBrowseDTO?.self) { group in
                    for page in 0..<pageCount {
                        group.addTask {
                            do { return try await api.fetchAsteroidBrowse(page: page, size: pageSize) }
                            catch {
                                log.error("Browse page \(page) failed: \(error.localizedDescription)", privacy: .privateData)
                                return nil
                            }
                        }
                    }
                    var out: [NeoBrowseDTO] = []
                    for await result in group {
                        if let result { out.append(result) }
                    }
                    return out
                }

                // Flatten, keep only bodies with usable orbital elements, dedupe by id.
                var seen = Set<String>()
                let dtos: [AsteroidDTO] = pages.flatMap { $0.nearEarthObjects }
                    .filter { $0.orbitalData != nil }
                    .filter { seen.insert($0.id).inserted }

                logger.notice("Got \(dtos.count) orbital asteroids from \(pages.count)/\(pageCount) browse pages")
                guard !dtos.isEmpty else {
                    throw ServerException("No orbital asteroids returned by browse")
                }
                try self.database.replaceAsteroids(dtos)

                return dtos.map { $0.toAsteroid() }
            },

            onNetworkError: { [weak self] networkException in
                self?.cachedFallback(on: networkException) ??
                    .failure(ExceptionMapper.mapExceptionToFailure(networkException))
            },

            onServerError: { [weak self] serverException in
                self?.cachedFallback(on: serverException) ??
                    .failure(ExceptionMapper.mapExceptionToFailure(serverException))
            }
        )
    }

    /// Single-body lookup via NASA `neo/{id}` — full detail incl. `orbital_data`.
    /// Powers the Search tab's numeric-id query. No list-level cache fallback (one
    /// body), so errors map straight to a `Failure`.
    func lookupAsteroid(id: String) async -> Result<Asteroid> {

        logger.info("Starting lookupAsteroid operation for id \(id)")

        return await safeRepositoryCall(

            call: { [weak self] in
                guard let self else {
                    throw ServerException("Repository deallocated during operation")
                }
                let dto = try await self.apiService.fetchAsteroidLookup(id: id)
                logger.notice("Looked up asteroid \(dto.id) (\(dto.name))")
                return dto.toAsteroid()
            }
        )
    }

    /// Shared cache-fallback used by both fetch paths: return cached asteroids on
    /// failure, a chained failure if the cache read itself throws, else the mapped failure.
    private func cachedFallback(on exception: AppException) -> Result<[Asteroid]>? {
        logger.error("Falling back to cache after: \(exception.localizedDescription)", privacy: .privateData)
        do {
            let cached = try database.fetchAsteroids()
            if !cached.isEmpty {
                logger.notice("Retrieved \(cached.count) asteroids from cache")
                return .success(cached)
            }
            return .failure(ExceptionMapper.mapExceptionToFailure(exception))
        } catch {
            let cacheFailure = ExceptionMapper.mapExceptionToFailure(
                error as? DatabaseException ?? DatabaseException.readFailed()
            )
            logger.error("Cache read failed: \(cacheFailure.localizedDescription)", privacy: .privateData)
            let base = ExceptionMapper.mapExceptionToFailure(exception)
            // Chain the cache failure onto the original failure's cause path.
            return .failure(NetworkFailure(base.message, severity: base.severity, cause: cacheFailure))
        }
    }

    // MARK: - Helpers

    /// ISO yyyy-MM-dd strings for today and today + 6 days.
    private static func weekWindow() -> (String, String) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]
        let now = Date()
        let start = fmt.string(from: now)
        if let plusSix = Calendar.current.date(byAdding: .day, value: 6, to: now) {
            return (start, fmt.string(from: plusSix))
        }
        return (start, start)
    }

    /// Flatten the feed's date-keyed dictionary into a date-sorted asteroid list.
    private static func flatten(feed: NeoFeedDTO) -> [AsteroidDTO] {
        feed.nearEarthObjects
            .sorted(by: { $0.key < $1.key })
            .flatMap { $0.value }
    }
}

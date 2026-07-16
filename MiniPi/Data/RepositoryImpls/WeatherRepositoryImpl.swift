//
//  WeatherRepositoryImpl.swift
//  MiniPi
//
//  Mirrors EarthquakeRepositoryImplementation: remote-first, persist to the local
//  cache on success, fall back to the cache on network/server error. Reuses
//  safeRepositoryCall / ExceptionMapper / the Failure family — no new error
//  mechanism. Forecast fetch is cache-backed; search + globe points are one-shot.
//
//  The globe-points fan-out fires `current.json` per city concurrently via a
//  TaskGroup and drops per-city failures, so one bad city never blanks the globe.
//

import Foundation
import FactoryKit

class WeatherRepositoryImplementation: WeatherRepository {

    private let remote: WeatherRemoteDataSource
    private let local: WeatherLocalDataSource
    private let logger: AppLoggerProtocol

    init(
        remote: WeatherRemoteDataSource,
        local: WeatherLocalDataSource,
        logger: AppLoggerProtocol = Container.shared.repositoryLogger()
    ) {
        self.remote = remote
        self.local = local
        self.logger = logger

        logger.info("WeatherRepository initialized")
    }

    // MARK: - Forecast (Home + Stats) — cache-backed

    func fetchForecast(_ query: WeatherQuery) async -> Result<WeatherForecast> {

        logger.info("Starting fetchForecast operation (query: \(query.query), days: \(query.days))")

        return await safeRepositoryCall(

            call: { [weak self] in

                guard let self else {
                    throw ServerException("Repository deallocated during operation")
                }

                logger.debug("Fetching forecast from WeatherAPI.com")
                let dto = try await self.remote.forecast(query)
                let forecast = dto.toForecast()
                logger.info("Successfully fetched forecast for \(forecast.location.name)")

                logger.debug("Updating local cache with forecast")
                try self.local.replaceForecast(forecast)
                logger.notice("Local cache updated with forecast")

                return forecast
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

    // MARK: - Search (Home) — one-shot

    func searchCities(query: String) async -> Result<[WeatherLocation]> {

        logger.info("Starting searchCities operation (query: \(query))")

        return await safeRepositoryCall(

            call: { [weak self] in
                guard let self else {
                    throw ServerException("Repository deallocated during operation")
                }
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return [WeatherLocation]() }
                let results = try await self.remote.search(trimmed)
                logger.notice("Search returned \(results.count) cities")
                return results.map { $0.toLocation() }
            }
        )
    }

    // MARK: - Globe points (Map) — one-shot, concurrent fan-out

    // MARK: - Shared cache fallback (forecast only)

    private func cachedFallback(on exception: AppException) -> Result<WeatherForecast>? {
        logger.error("Falling back to cache after: \(exception.localizedDescription)", privacy: .privateData)
        do {
            if let cached = try local.fetchForecast() {
                logger.notice("Retrieved cached forecast")
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

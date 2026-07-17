//
//  FakeAppDatabase.swift
//  IosDevelopersGuide
//
//  Created by Mayank Upadhyay on 03/07/26.
//

import Foundation
import FactoryKit

// Just make it for a single feature to test the DB functionality at least once, do not maintain it for all the features
// `DbScenario` now lives in `Core/Scenario/DbScenario.swift`.

final class FakeAppDatabase: LocalDataStore {

    private var scenario: DbScenario
    private var cachedPosts: [Post] = []
    private var cachedAsteroids: [Asteroid] = []
    private var cachedEarthquakes: [Earthquake] = []
    private var cachedForecast: WeatherForecast?
    private var cachedMarketOverview: StockMarketOverview?
    private let logger: AppLoggerProtocol

    // Scenario is supplied by the DI module from AppConfiguration (single source of truth) — no
    // default here so the value can't drift.
    init(scenario: DbScenario, logger: AppLoggerProtocol = Container.shared.databaseLogger()) {
         self.scenario = scenario
         self.logger = logger
         logger.info("FakeAppDatabase initialized with scenario: \(scenario)")
    }

    func setScenario(_ scenario: DbScenario) {
        self.scenario = scenario
        logger.notice("FakeAppDatabase scenario changed to: \(scenario)")
    }

    func fetchPosts() throws -> [Post] {

        logger.debug("FakeAppDatabase: fetchPosts called with scenario: \(scenario)")

        switch scenario {

        case .success:
            logger.info("FakeAppDatabase: returning \(cachedPosts.count) cached posts")
            return cachedPosts

        case .empty:
            logger.notice("FakeAppDatabase: returning \(cachedPosts.count) posts (empty scenario, reflects current cache)")
            return cachedPosts

        case .readError:
            logger.error("FakeAppDatabase: simulating read error")
            throw DatabaseException.readFailed(
                cause: nil,
                context: "FakeAppDatabase.fetchPosts"
            )

        case .writeError:
            logger.info("FakeAppDatabase: returning \(cachedPosts.count) cached posts (writeError scenario)")
            return cachedPosts

        case .connectionFailed:
            logger.error("FakeAppDatabase: simulating connection failure")
            throw DatabaseException.connectionFailed(
                cause: nil,
                context: "FakeAppDatabase.fetchPosts"
            )
        }
    }

    func replacePosts(_ posts: [PostDTO]) throws {

        logger.debug("FakeAppDatabase: replacePosts called with \(posts.count) posts")

        switch scenario {

        case .success,
             .empty,
             .readError:
            logger.debug("FakeAppDatabase: caching \(posts.count) posts")
            cachedPosts = posts.map {
                Post(
                    id: $0.id,
                    title: $0.title,
                    body: $0.body
                )
            }
            logger.notice("FakeAppDatabase: successfully cached \(posts.count) posts")

        case .writeError:
            logger.error("FakeAppDatabase: simulating write error")
            throw DatabaseException.writeFailed(
                cause: nil,
                context: "FakeAppDatabase.replacePosts"
            )

        case .connectionFailed:
            logger.error("FakeAppDatabase: simulating connection failure")
            throw DatabaseException.connectionFailed(
                cause: nil,
                context: "FakeAppDatabase.replacePosts"
            )
        }
    }

    func clearPosts() throws {

        logger.debug("FakeAppDatabase: clearPosts called")

        switch scenario {

        case .success,
             .empty,
             .readError:
            logger.debug("FakeAppDatabase: clearing all cached posts")
            cachedPosts.removeAll()
            logger.notice("FakeAppDatabase: successfully cleared posts")

        case .writeError:
            logger.error("FakeAppDatabase: simulating write error on clear")
            throw DatabaseException.writeFailed(
                cause: nil,
                context: "FakeAppDatabase.clearPosts"
            )

        case .connectionFailed:
            logger.error("FakeAppDatabase: simulating connection failure on clear")
            throw DatabaseException.connectionFailed(
                cause: nil,
                context: "FakeAppDatabase.clearPosts"
            )
        }
    }

    // MARK: - Asteroid cache (Module A)
    // Mirrors the posts surface. Reuses the same scenario so the fake DB behaves
    // consistently with the rest of the app's failure simulation.

    func fetchAsteroids() throws -> [Asteroid] {
        logger.debug("FakeAppDatabase: fetchAsteroids called with scenario: \(scenario)")
        switch scenario {
        case .success, .empty, .writeError:
            return cachedAsteroids
        case .readError:
            throw DatabaseException.readFailed(cause: nil, context: "FakeAppDatabase.fetchAsteroids")
        case .connectionFailed:
            throw DatabaseException.connectionFailed(cause: nil, context: "FakeAppDatabase.fetchAsteroids")
        }
    }

    func replaceAsteroids(_ asteroids: [AsteroidDTO]) throws {
        logger.debug("FakeAppDatabase: replaceAsteroids called with \(asteroids.count) asteroids")
        switch scenario {
        case .success, .empty, .readError:
            cachedAsteroids = asteroids.map { $0.toAsteroid() }
        case .writeError:
            throw DatabaseException.writeFailed(cause: nil, context: "FakeAppDatabase.replaceAsteroids")
        case .connectionFailed:
            throw DatabaseException.connectionFailed(cause: nil, context: "FakeAppDatabase.replaceAsteroids")
        }
    }

    // MARK: - Earthquake cache
    // Minimal conformance to keep `LocalDataStore` compiling. Not exercised in
    // dev (USE_FAKE_DATABASE=NO); mirrors the asteroid surface so behaviour is
    // consistent if the fake DB is ever toggled on for this feature.

    func fetchEarthquakes() throws -> [Earthquake] {
        logger.debug("FakeAppDatabase: fetchEarthquakes called with scenario: \(scenario)")
        switch scenario {
        case .success, .empty, .writeError:
            return cachedEarthquakes
        case .readError:
            throw DatabaseException.readFailed(cause: nil, context: "FakeAppDatabase.fetchEarthquakes")
        case .connectionFailed:
            throw DatabaseException.connectionFailed(cause: nil, context: "FakeAppDatabase.fetchEarthquakes")
        }
    }

    func replaceEarthquakes(_ earthquakes: [GeoJSONFeatureDTO]) throws {
        logger.debug("FakeAppDatabase: replaceEarthquakes called with \(earthquakes.count) earthquakes")
        switch scenario {
        case .success, .empty, .readError:
            cachedEarthquakes = earthquakes.map { $0.toEarthquake() }
        case .writeError:
            throw DatabaseException.writeFailed(cause: nil, context: "FakeAppDatabase.replaceEarthquakes")
        case .connectionFailed:
            throw DatabaseException.connectionFailed(cause: nil, context: "FakeAppDatabase.replaceEarthquakes")
        }
    }

    // MARK: - Weather cache
    // Minimal conformance to keep `LocalDataStore` compiling. Not exercised in dev
    // (USE_FAKE_DATABASE=NO); no real fake forecast data (house rule).

    func fetchForecast() throws -> WeatherForecast? {
        logger.debug("FakeAppDatabase: fetchForecast called with scenario: \(scenario)")
        switch scenario {
        case .success, .empty, .writeError:
            return cachedForecast
        case .readError:
            throw DatabaseException.readFailed(cause: nil, context: "FakeAppDatabase.fetchForecast")
        case .connectionFailed:
            throw DatabaseException.connectionFailed(cause: nil, context: "FakeAppDatabase.fetchForecast")
        }
    }

    func replaceForecast(_ forecast: WeatherForecast) throws {
        logger.debug("FakeAppDatabase: replaceForecast called for \(forecast.location.name)")
        switch scenario {
        case .success, .empty, .readError:
            cachedForecast = forecast
        case .writeError:
            throw DatabaseException.writeFailed(cause: nil, context: "FakeAppDatabase.replaceForecast")
        case .connectionFailed:
            throw DatabaseException.connectionFailed(cause: nil, context: "FakeAppDatabase.replaceForecast")
        }
    }

    // MARK: - Stocks cache
    // Minimal conformance to keep `LocalDataStore` compiling. Not exercised in dev
    // (USE_FAKE_DATABASE=NO); no real fake stocks data (house rule).

    func fetchMarketOverview() throws -> StockMarketOverview? {
        logger.debug("FakeAppDatabase: fetchMarketOverview called with scenario: \(scenario)")
        switch scenario {
        case .success, .empty, .writeError:
            return cachedMarketOverview
        case .readError:
            throw DatabaseException.readFailed(cause: nil, context: "FakeAppDatabase.fetchMarketOverview")
        case .connectionFailed:
            throw DatabaseException.connectionFailed(cause: nil, context: "FakeAppDatabase.fetchMarketOverview")
        }
    }

    func replaceMarketOverview(_ overview: StockMarketOverview) throws {
        logger.debug("FakeAppDatabase: replaceMarketOverview called for \(overview.country)")
        switch scenario {
        case .success, .empty, .readError:
            cachedMarketOverview = overview
        case .writeError:
            throw DatabaseException.writeFailed(cause: nil, context: "FakeAppDatabase.replaceMarketOverview")
        case .connectionFailed:
            throw DatabaseException.connectionFailed(cause: nil, context: "FakeAppDatabase.replaceMarketOverview")
        }
    }

    // MARK: - Forex cache
    // Minimal conformance to keep `LocalDataStore` compiling. Not exercised in dev
    // (USE_FAKE_DATABASE=NO); no real fake forex data (house rule).

    private var cachedForexOverview: ForexMarketOverview?

    func fetchForexOverview() throws -> ForexMarketOverview? {
        logger.debug("FakeAppDatabase: fetchForexOverview called with scenario: \(scenario)")
        switch scenario {
        case .success, .empty, .writeError:
            return cachedForexOverview
        case .readError:
            throw DatabaseException.readFailed(cause: nil, context: "FakeAppDatabase.fetchForexOverview")
        case .connectionFailed:
            throw DatabaseException.connectionFailed(cause: nil, context: "FakeAppDatabase.fetchForexOverview")
        }
    }

    func replaceForexOverview(_ overview: ForexMarketOverview) throws {
        logger.debug("FakeAppDatabase: replaceForexOverview called for \(overview.baseLabel)")
        switch scenario {
        case .success, .empty, .readError:
            cachedForexOverview = overview
        case .writeError:
            throw DatabaseException.writeFailed(cause: nil, context: "FakeAppDatabase.replaceForexOverview")
        case .connectionFailed:
            throw DatabaseException.connectionFailed(cause: nil, context: "FakeAppDatabase.replaceForexOverview")
        }
    }

    // MARK: - Crypto cache
    // Minimal conformance to keep `LocalDataStore` compiling. Not exercised in dev
    // (USE_FAKE_DATABASE=NO); no real fake crypto data (house rule).

    private var cachedCryptoOverview: CryptoMarketOverview?

    func fetchCryptoOverview() throws -> CryptoMarketOverview? {
        logger.debug("FakeAppDatabase: fetchCryptoOverview called with scenario: \(scenario)")
        switch scenario {
        case .success, .empty, .writeError:
            return cachedCryptoOverview
        case .readError:
            throw DatabaseException.readFailed(cause: nil, context: "FakeAppDatabase.fetchCryptoOverview")
        case .connectionFailed:
            throw DatabaseException.connectionFailed(cause: nil, context: "FakeAppDatabase.fetchCryptoOverview")
        }
    }

    func replaceCryptoOverview(_ overview: CryptoMarketOverview) throws {
        logger.debug("FakeAppDatabase: replaceCryptoOverview called for \(overview.quoteLabel)")
        switch scenario {
        case .success, .empty, .readError:
            cachedCryptoOverview = overview
        case .writeError:
            throw DatabaseException.writeFailed(cause: nil, context: "FakeAppDatabase.replaceCryptoOverview")
        case .connectionFailed:
            throw DatabaseException.connectionFailed(cause: nil, context: "FakeAppDatabase.replaceCryptoOverview")
        }
    }

    // MARK: - AI model cache
    // Minimal conformance to keep `LocalDataStore` compiling. Not exercised in dev
    // (USE_FAKE_DATABASE=NO); no real fake AI data (house rule).

    private var cachedAIModelCatalog: AIModelCatalog?

    func fetchAIModelCatalog() throws -> AIModelCatalog? {
        logger.debug("FakeAppDatabase: fetchAIModelCatalog called with scenario: \(scenario)")
        switch scenario {
        case .success, .empty, .writeError:
            return cachedAIModelCatalog
        case .readError:
            throw DatabaseException.readFailed(cause: nil, context: "FakeAppDatabase.fetchAIModelCatalog")
        case .connectionFailed:
            throw DatabaseException.connectionFailed(cause: nil, context: "FakeAppDatabase.fetchAIModelCatalog")
        }
    }

    func replaceAIModelCatalog(_ catalog: AIModelCatalog) throws {
        logger.debug("FakeAppDatabase: replaceAIModelCatalog called for \(catalog.models.count) models")
        switch scenario {
        case .success, .empty, .readError:
            cachedAIModelCatalog = catalog
        case .writeError:
            throw DatabaseException.writeFailed(cause: nil, context: "FakeAppDatabase.replaceAIModelCatalog")
        case .connectionFailed:
            throw DatabaseException.connectionFailed(cause: nil, context: "FakeAppDatabase.replaceAIModelCatalog")
        }
    }

    // MARK: - World Bank (Indicators) cache
    // Minimal conformance to keep `LocalDataStore` compiling. Not exercised in dev
    // (USE_FAKE_DATABASE=NO); no real fake indicator data (house rule).

    private var cachedWorldData: WorldDataCatalog?

    func fetchWorldData() throws -> WorldDataCatalog? {
        logger.debug("FakeAppDatabase: fetchWorldData called with scenario: \(scenario)")
        switch scenario {
        case .success, .empty, .writeError:
            return cachedWorldData
        case .readError:
            throw DatabaseException.readFailed(cause: nil, context: "FakeAppDatabase.fetchWorldData")
        case .connectionFailed:
            throw DatabaseException.connectionFailed(cause: nil, context: "FakeAppDatabase.fetchWorldData")
        }
    }

    func replaceWorldData(_ catalog: WorldDataCatalog) throws {
        logger.debug("FakeAppDatabase: replaceWorldData called for \(catalog.countries.count) countries")
        switch scenario {
        case .success, .empty, .readError:
            cachedWorldData = catalog
        case .writeError:
            throw DatabaseException.writeFailed(cause: nil, context: "FakeAppDatabase.replaceWorldData")
        case .connectionFailed:
            throw DatabaseException.connectionFailed(cause: nil, context: "FakeAppDatabase.replaceWorldData")
        }
    }
}
//
//  AppDatabase.swift
//  MiniPi
//
//  The single local store engine (in-memory here; swap for Core Data / SwiftData /
//  GRDB / Realm later — the protocols below stay the same). One shared instance
//  backs every feature's local data source: a database is one engine, not one
//  per feature.
//
//  Feature access is segregated through narrow protocols (PostLocalDataSource,
//  AsteroidLocalDataSource) so a repository only sees the slice it needs.
//  `LocalDataStore` is the union the concrete store conforms to; the DI module
//  resolves it once and hands out the narrow views.
//

import Foundation
import FactoryKit

// MARK: - Feature-narrow local data source protocols

protocol PostLocalDataSource {
    func fetchPosts() throws -> [Post]
    func replacePosts(_ posts: [PostDTO]) throws
    func clearPosts() throws
}

protocol AsteroidLocalDataSource {
    func fetchAsteroids() throws -> [Asteroid]
    func replaceAsteroids(_ asteroids: [AsteroidDTO]) throws
}

protocol EarthquakeLocalDataSource {
    func fetchEarthquakes() throws -> [Earthquake]
    func replaceEarthquakes(_ earthquakes: [GeoJSONFeatureDTO]) throws
}

protocol WeatherLocalDataSource {
    /// The last cached forecast (Home/Stats dataset). `nil` when nothing is cached.
    func fetchForecast() throws -> WeatherForecast?
    func replaceForecast(_ forecast: WeatherForecast) throws
}

protocol StocksLocalDataSource {
    /// The last cached market overview (Home/Stats dataset). `nil` when nothing is cached.
    func fetchMarketOverview() throws -> StockMarketOverview?
    func replaceMarketOverview(_ overview: StockMarketOverview) throws
}

protocol ForexLocalDataSource {
    /// The last cached forex overview (Home/Stats dataset). `nil` when nothing is cached.
    func fetchForexOverview() throws -> ForexMarketOverview?
    func replaceForexOverview(_ overview: ForexMarketOverview) throws
}

protocol CryptoLocalDataSource {
    /// The last cached crypto overview (Home/Stats dataset). `nil` when nothing is cached.
    func fetchCryptoOverview() throws -> CryptoMarketOverview?
    func replaceCryptoOverview(_ overview: CryptoMarketOverview) throws
}

protocol AIModelLocalDataSource {
    /// The last cached AI model catalog (Home/Ranking/Search/Compare dataset). `nil` when nothing is cached.
    func fetchAIModelCatalog() throws -> AIModelCatalog?
    func replaceAIModelCatalog(_ catalog: AIModelCatalog) throws
}

protocol IndicatorLocalDataSource {
    /// The last cached World Bank dataset (Home/Ranking/Search/Compare/Stats). `nil` when nothing is cached.
    func fetchWorldData() throws -> WorldDataCatalog?
    func replaceWorldData(_ catalog: WorldDataCatalog) throws
}

protocol LibraryLocalDataSource {
    /// The last cached library home overview (trending books + popular subjects). `nil` when nothing is cached.
    func fetchLibraryOverview() throws -> LibraryHomeOverview?
    func replaceLibraryOverview(_ overview: LibraryHomeOverview) throws
}

/// Union of every feature's local-data-source protocol — what a concrete store
/// (AppDatabase, FakeAppDatabase) conforms to. Resolved once in `DatabaseModule`;
/// repositories receive the narrow slice they depend on.
protocol LocalDataStore: PostLocalDataSource, AsteroidLocalDataSource, EarthquakeLocalDataSource, WeatherLocalDataSource, StocksLocalDataSource, ForexLocalDataSource, CryptoLocalDataSource, AIModelLocalDataSource, IndicatorLocalDataSource, LibraryLocalDataSource {}

// MARK: - Concrete in-memory store

final class AppDatabase: LocalDataStore {

    static let shared = AppDatabase()

    private let logger: AppLoggerProtocol
    private var cachedPosts: [Post] = []
    private var cachedAsteroids: [Asteroid] = []
    private var cachedEarthquakes: [Earthquake] = []
    private var cachedForecast: WeatherForecast?
    private var cachedMarketOverview: StockMarketOverview?
    private var cachedForexOverview: ForexMarketOverview?
    private var cachedCryptoOverview: CryptoMarketOverview?
    private var cachedAIModelCatalog: AIModelCatalog?
    private var cachedWorldData: WorldDataCatalog?
    private var cachedLibraryOverview: LibraryHomeOverview?

    private init(logger: AppLoggerProtocol = Container.shared.databaseLogger()) {
        self.logger = logger
        logger.info("AppDatabase initialized (in-memory)")
    }

    func fetchPosts() throws -> [Post] {
        logger.debug("Fetching \(cachedPosts.count) posts (in-memory)")
        return cachedPosts
    }

    func replacePosts(_ posts: [PostDTO]) throws {
        logger.debug("Replacing \(posts.count) posts (in-memory)")
        cachedPosts = posts.map {
            Post(id: $0.id, title: $0.title, body: $0.body)
        }
    }

    func clearPosts() throws {
        logger.debug("Clearing posts (in-memory)")
        cachedPosts.removeAll()
    }

    func fetchAsteroids() throws -> [Asteroid] {
        logger.debug("Fetching \(cachedAsteroids.count) asteroids (in-memory)")
        return cachedAsteroids
    }

    func replaceAsteroids(_ asteroids: [AsteroidDTO]) throws {
        logger.debug("Replacing \(asteroids.count) asteroids (in-memory)")
        cachedAsteroids = asteroids.map { $0.toAsteroid() }
    }

    func fetchEarthquakes() throws -> [Earthquake] {
        logger.debug("Fetching \(cachedEarthquakes.count) earthquakes (in-memory)")
        return cachedEarthquakes
    }

    func replaceEarthquakes(_ earthquakes: [GeoJSONFeatureDTO]) throws {
        logger.debug("Replacing \(earthquakes.count) earthquakes (in-memory)")
        cachedEarthquakes = earthquakes.map { $0.toEarthquake() }
    }

    func fetchForecast() throws -> WeatherForecast? {
        logger.debug("Fetching cached forecast (in-memory)")
        return cachedForecast
    }

    func replaceForecast(_ forecast: WeatherForecast) throws {
        logger.debug("Caching forecast for \(forecast.location.name) (in-memory)")
        cachedForecast = forecast
    }

    func fetchMarketOverview() throws -> StockMarketOverview? {
        logger.debug("Fetching cached market overview (in-memory)")
        return cachedMarketOverview
    }

    func replaceMarketOverview(_ overview: StockMarketOverview) throws {
        logger.debug("Caching market overview for \(overview.country) (in-memory)")
        cachedMarketOverview = overview
    }

    func fetchForexOverview() throws -> ForexMarketOverview? {
        logger.debug("Fetching cached forex overview (in-memory)")
        return cachedForexOverview
    }

    func replaceForexOverview(_ overview: ForexMarketOverview) throws {
        logger.debug("Caching forex overview vs \(overview.baseLabel) (in-memory)")
        cachedForexOverview = overview
    }

    func fetchCryptoOverview() throws -> CryptoMarketOverview? {
        logger.debug("Fetching cached crypto overview (in-memory)")
        return cachedCryptoOverview
    }

    func replaceCryptoOverview(_ overview: CryptoMarketOverview) throws {
        logger.debug("Caching crypto overview vs \(overview.quoteLabel) (in-memory)")
        cachedCryptoOverview = overview
    }

    func fetchAIModelCatalog() throws -> AIModelCatalog? {
        logger.debug("Fetching cached AI model catalog (in-memory)")
        return cachedAIModelCatalog
    }

    func replaceAIModelCatalog(_ catalog: AIModelCatalog) throws {
        logger.debug("Caching AI model catalog: \(catalog.models.count) models (in-memory)")
        cachedAIModelCatalog = catalog
    }

    func fetchWorldData() throws -> WorldDataCatalog? {
        logger.debug("Fetching cached World Bank catalog (in-memory)")
        return cachedWorldData
    }

    func replaceWorldData(_ catalog: WorldDataCatalog) throws {
        logger.debug("Caching World Bank catalog: \(catalog.countries.count) countries, \(catalog.observations.count) data points (in-memory)")
        cachedWorldData = catalog
    }

    func fetchLibraryOverview() throws -> LibraryHomeOverview? {
        logger.debug("Fetching cached library overview (in-memory)")
        return cachedLibraryOverview
    }

    func replaceLibraryOverview(_ overview: LibraryHomeOverview) throws {
        logger.debug("Caching library overview: \(overview.trendingBooks.count) trending, \(overview.popularSubjects.count) subjects (in-memory)")
        cachedLibraryOverview = overview
    }
}

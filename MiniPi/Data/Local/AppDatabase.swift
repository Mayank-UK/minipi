//
//  AppDatabase.swift
//  MiniPi
//
//  Default (non-fake) database service. This starter project uses a simple
//  in-memory store so the app compiles and runs with zero extra setup.
//  Swap this out for a real persistence layer (Core Data, SwiftData, GRDB,
//  Realm, etc.) when you need on-disk storage — the `DatabaseServiceProtocol`
//  surface and the DI wiring in `DatabaseModule` stay the same.
//

import Foundation
import FactoryKit

protocol DatabaseServiceProtocol {
    func fetchPosts() throws -> [Post]
    func replacePosts(_ posts: [PostDTO]) throws
    func clearPosts() throws

    // Asteroid cache (Module A) — mirrors the Posts cache surface.
    func fetchAsteroids() throws -> [Asteroid]
    func replaceAsteroids(_ asteroids: [AsteroidDTO]) throws
}

final class AppDatabase: DatabaseServiceProtocol {

    static let shared = AppDatabase()

    private let logger: AppLoggerProtocol
    private var cachedPosts: [Post] = []
    private var cachedAsteroids: [Asteroid] = []

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
}

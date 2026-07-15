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
}

final class AppDatabase: DatabaseServiceProtocol {

    static let shared = AppDatabase()

    private let logger: AppLoggerProtocol
    private var cachedPosts: [Post] = []

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
}

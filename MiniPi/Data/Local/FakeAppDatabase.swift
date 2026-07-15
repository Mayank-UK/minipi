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

final class FakeAppDatabase: DatabaseServiceProtocol {

    private var scenario: DbScenario
    private var cachedPosts: [Post] = []
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
}

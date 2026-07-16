//
//  PostRepository.swift
//  IosDevelopersGuide
//
//  Created by Mayank Upadhyay on 22/08/24.
//

import Foundation
import FactoryKit

class PostRepositoryImplementation: PostRepository {

    private let remote: PostRemoteDataSource
    private let local: PostLocalDataSource
    private let logger: AppLoggerProtocol

    init(
        remote: PostRemoteDataSource,
        local: PostLocalDataSource,
        logger: AppLoggerProtocol = Container.shared.repositoryLogger()
    ) {
        self.remote = remote
        self.local = local
        self.logger = logger

        logger.info("PostRepository initialized")
    }

    func fetchPosts() async -> Result<[Post]> {

        logger.info("Starting fetchPosts operation")

        return await safeRepositoryCall(

            call: { [weak self] in

                guard let self else {
                    throw ServerException("Repository deallocated during operation")
                }

                logger.debug("Fetching posts from remote API")
                let remotePosts = try await self.remote.fetchPosts()
                logger.info("Successfully fetched \(remotePosts.count) posts from API")

                logger.debug("Updating local database with remote posts")
                try self.local.replacePosts(remotePosts)
                logger.notice("Database updated successfully with \(remotePosts.count) posts")

                let posts = remotePosts.map {
                    Post(
                        id: $0.id,
                        title: $0.title,
                        body: $0.body
                    )
                }

                logger.info("Returning \(posts.count) posts to caller")
                return posts
            },

            onNetworkError: { [weak self] networkException in

                guard let self else {
                    return .failure(
                        ExceptionMapper.mapExceptionToFailure(networkException)
                    )
                }

                self.logger.error("Network error occurred: \(networkException.localizedDescription)", privacy: .privateData)

                do {

                    self.logger.debug("Attempting to fetch cached posts from database")
                    let cachedPosts = try self.local.fetchPosts()

                    if !cachedPosts.isEmpty {
                        self.logger.notice("Successfully retrieved \(cachedPosts.count) posts from cache")
                        return .success(cachedPosts)
                    }

                    self.logger.error("Cache is empty, returning network failure")
                    return .failure(
                        ExceptionMapper.mapExceptionToFailure(networkException)
                    )

                } catch {

                    let cacheFailure = ExceptionMapper.mapExceptionToFailure(
                        error as? DatabaseException ??
                        DatabaseException.readFailed()
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

                    self.logger.debug("Attempting to fetch cached posts from database")
                    let cachedPosts = try self.local.fetchPosts()

                    if !cachedPosts.isEmpty {
                        self.logger.notice("Successfully retrieved \(cachedPosts.count) posts from cache")
                        return .success(cachedPosts)
                    }

                    self.logger.error("Cache is empty, returning server failure")
                    return .failure(
                        ExceptionMapper.mapExceptionToFailure(serverException)
                    )

                } catch {

                    let cacheFailure = ExceptionMapper.mapExceptionToFailure(
                        error as? DatabaseException ??
                        DatabaseException.readFailed()
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
}

//
//  AIModelRepositoryImpl.swift
//  MiniPi
//
//  Mirrors CryptoRepositoryImplementation: remote-first, persist to the local cache on
//  success, fall back to the cache on network/server error. Reuses safeRepositoryCall /
//  ExceptionMapper / the Failure family — no new error mechanism. The catalog (Home /
//  Ranking / Search / Compare) is the one cache-backed fetch.
//
//  OpenRouter's single endpoint returns the entire catalog, so this fetch also builds the
//  aggregate summary (AIModelSummary.build) before caching — Ranking / Search / Compare
//  then derive from the cached models client-side.
//

import Foundation
import FactoryKit

class AIModelRepositoryImplementation: AIModelRepository {

    private let remote: AIModelRemoteDataSource
    private let local: AIModelLocalDataSource
    private let logger: AppLoggerProtocol

    init(
        remote: AIModelRemoteDataSource,
        local: AIModelLocalDataSource,
        logger: AppLoggerProtocol = Container.shared.repositoryLogger()
    ) {
        self.remote = remote
        self.local = local
        self.logger = logger

        logger.info("AIModelRepository initialized")
    }

    // MARK: - Catalog (Home + Ranking + Search + Compare) — cache-backed

    func catalog() async -> Result<AIModelCatalog> {

        logger.info("Starting AI model catalog operation")

        return await safeRepositoryCall(

            call: { [weak self] in
                guard let self else {
                    throw ServerException("Repository deallocated during operation")
                }

                let models = try await self.remote.catalog()
                let summary = AIModelSummary.build(from: models)
                let catalog = AIModelCatalog(summary: summary, models: models)

                logger.info("Built AI model catalog: \(models.count) models, \(summary.providerCount) providers")

                logger.debug("Updating local cache with AI model catalog")
                try self.local.replaceAIModelCatalog(catalog)
                logger.notice("Local cache updated with AI model catalog")

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

    // MARK: - Shared cache fallback

    private func cachedFallback(on exception: AppException) -> Result<AIModelCatalog>? {
        logger.error("Falling back to cache after: \(exception.localizedDescription)", privacy: .privateData)
        do {
            if let cached = try local.fetchAIModelCatalog() {
                logger.notice("Retrieved cached AI model catalog")
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

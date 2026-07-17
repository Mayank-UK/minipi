//
//  LibraryRepositoryImpl.swift
//  MiniPi
//
//  Mirrors CryptoRepositoryImplementation: remote-first, persist to the local cache on
//  success, fall back to the cache on network/server error. Reuses safeRepositoryCall /
//  ExceptionMapper / the Failure family — no new error mechanism. The Home overview
//  (trending books + popular subjects) is cache-backed; search / trending / work-detail
//  are one-shot.
//
//  Home fans out one subject call per curated popular subject via a TaskGroup and drops
//  per-subject failures (archived/empty subject / rate-limited), so one bad subject never
//  blanks the feature — the same drop-on-failure pattern as the Yahoo bulk-quote and World
//  Bank indicator fetches.
//

import Foundation
import FactoryKit

class LibraryRepositoryImplementation: LibraryRepository {

    private let remote: LibraryRemoteDataSource
    private let local: LibraryLocalDataSource
    private let logger: AppLoggerProtocol

    init(
        remote: LibraryRemoteDataSource,
        local: LibraryLocalDataSource,
        logger: AppLoggerProtocol = Container.shared.repositoryLogger()
    ) {
        self.remote = remote
        self.local = local
        self.logger = logger

        logger.info("LibraryRepository initialized")
    }

    // MARK: - Home overview (cache-backed)

    func homeOverview() async -> Result<LibraryHomeOverview> {

        logger.info("Starting library homeOverview operation")

        return await safeRepositoryCall(

            call: { [weak self] in
                guard let self else {
                    throw ServerException("Repository deallocated during operation")
                }

                // Trending books (now) + popular subjects, concurrently.
                async let trending = self.remote.trending(.now, limit: 12)
                let subjects = await self.fetchPopularSubjects()

                let trendingBooks: [LibraryWork]
                do {
                    trendingBooks = try await trending.toWorks()
                } catch {
                    // Trending is best-effort for Home — don't fail the whole overview if
                    // only the trending call broke (subjects may still render).
                    logger.error("Trending fetch failed: \(error.localizedDescription)", privacy: .privateData)
                    trendingBooks = []
                }

                let overview = LibraryHomeOverview(
                    trendingBooks: trendingBooks,
                    popularSubjects: subjects
                )

                logger.info("Built library overview: \(trendingBooks.count) trending, \(subjects.count) subjects")

                logger.debug("Updating local cache with library overview")
                try self.local.replaceLibraryOverview(overview)
                logger.notice("Local cache updated with library overview")

                return overview
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

    // MARK: - Search (one-shot)

    func search(_ query: String, scope: LibrarySearchScope) async -> Result<[LibraryWork]> {
        logger.info("Starting search operation (query: \(query), scope: \(scope.rawValue))")
        return await safeRepositoryCall { [weak self] in
            guard let self else { throw ServerException("Repository deallocated during operation") }
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return [LibraryWork]() }

            let response: LibrarySearchResponseDTO
            switch scope {
            case .books:
                response = try await self.remote.searchWorks(query: trimmed, author: nil, subject: nil, limit: 30)
            case .authors:
                response = try await self.remote.searchWorks(query: nil, author: trimmed, subject: nil, limit: 30)
            case .subjects:
                response = try await self.remote.searchWorks(query: nil, author: nil, subject: trimmed, limit: 30)
            }
            let works = response.toWorks()
            logger.notice("Search returned \(works.count) works")
            return works
        }
    }

    // MARK: - Trending (one-shot)

    func trending(period: LibraryTrendingPeriod) async -> Result<[LibraryWork]> {
        logger.info("Starting trending operation (period: \(period.rawValue))")
        return await safeRepositoryCall { [weak self] in
            guard let self else { throw ServerException("Repository deallocated during operation") }
            let response = try await self.remote.trending(period, limit: 50)
            let works = response.toWorks()
            logger.notice("Trending returned \(works.count) works (\(period.rawValue))")
            return works
        }
    }

    // MARK: - Work detail (one-shot)

    func workDetail(_ id: String) async -> Result<LibraryBookDetail> {
        logger.info("Starting workDetail operation (id: \(id))")
        return await safeRepositoryCall { [weak self] in
            guard let self else { throw ServerException("Repository deallocated during operation") }
            let dto = try await self.remote.work(id)
            return dto.toLibraryBookDetail(id: id, fallbackTitle: "")
        }
    }

    // MARK: - Concurrent popular-subject fetch

    /// Fetches each curated popular subject concurrently, dropping any that fail. Preserves
    /// the curated order. Each entry carries the live `work_count` for the Home aggregate.
    private func fetchPopularSubjects() async -> [LibrarySubject] {
        let entries = LibrarySubjects.popular
        return await withTaskGroup(of: (Int, LibrarySubject?).self) { [weak self] group in
            for (index, entry) in entries.enumerated() {
                group.addTask {
                    guard let self else { return (index, nil) }
                    do {
                        let response = try await self.remote.subject(entry.slug, limit: 1)
                        return (index, response.toSubject(slug: entry.slug))
                    } catch {
                        // Fall back to a metadata-only subject (count 0) so the grid still
                        // shows the tile and the tap-to-search shortcut still works.
                        return (index, LibrarySubject(slug: entry.slug, displayName: entry.displayName, workCount: 0))
                    }
                }
            }
            var collected: [(Int, LibrarySubject)] = []
            for await item in group {
                if let value = item.1 { collected.append((item.0, value)) }
            }
            return collected.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    // MARK: - Shared cache fallback (home overview only)

    private func cachedFallback(on exception: AppException) -> Result<LibraryHomeOverview>? {
        logger.error("Falling back to cache after: \(exception.localizedDescription)", privacy: .privateData)
        do {
            if let cached = try local.fetchLibraryOverview() {
                logger.notice("Retrieved cached library overview")
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

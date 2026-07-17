//
//  LibraryRepository.swift
//  MiniPi
//
//  Domain contract for the Library feature (Open Library). Mirrors CryptoRepository: one
//  cache-backed fetch (the Home overview — trending books + popular subjects) and several
//  one-shot lookups (search, trending by period, work detail). No API key.
//

import Foundation

protocol LibraryRepository {
    /// Trending books + curated popular subjects (Home). Cache-backed: remote-first,
    /// persists to the local store on success, falls back to the cache on network/server
    /// error.
    func homeOverview() async -> Result<LibraryHomeOverview>

    /// Search works by free-text query scoped to books / authors / subjects (one-shot).
    func search(_ query: String, scope: LibrarySearchScope) async -> Result<[LibraryWork]>

    /// Trending books for a period window (Ranking, one-shot).
    func trending(period: LibraryTrendingPeriod) async -> Result<[LibraryWork]>

    /// Full detail for one work (detail sheet, one-shot).
    func workDetail(_ id: String) async -> Result<LibraryBookDetail>
}

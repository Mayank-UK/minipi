//
//  AIModelRepository.swift
//  MiniPi
//
//  Domain contract for the AI Models feature. One cache-backed fetch — the OpenRouter
//  catalog — which the Home aggregates, Ranking sorts, Search filters and Compare all
//  derive client-side. Mirrors the Crypto overview contract: remote-first, persist to
//  the local store on success, fall back to the cache on network/server error.
//

import Foundation

protocol AIModelRepository {
    /// The full model catalog + aggregate summary (Home / Ranking / Search / Compare).
    /// Cache-backed: remote-first, persists to the local store on success, falls back
    /// to the cache on network/server error.
    func catalog() async -> Result<AIModelCatalog>
}

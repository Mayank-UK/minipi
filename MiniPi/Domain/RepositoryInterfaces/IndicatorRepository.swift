//
//  IndicatorRepository.swift
//  MiniPi
//
//  Domain contract for the Indicators feature. Mirrors AIModelRepository: one
//  cache-backed fetch that returns the whole dataset (countries + indicators + latest
//  observations + summary). Ranking / Search / Compare / Stats derive client-side.
//

import Foundation

protocol IndicatorRepository {
    /// Cache-backed: remote-first, persists to the local store, falls back to the cache.
    func catalog() async -> Result<WorldDataCatalog>
}

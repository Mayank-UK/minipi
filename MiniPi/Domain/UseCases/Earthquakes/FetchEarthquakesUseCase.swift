//
//  FetchEarthquakesUseCase.swift
//  MiniPi
//
//  Business action: load a USGS summary feed (default all_week). Mirrors
//  FetchAsteroidsUseCase — a thin wrapper over the repository.
//

import Foundation

class FetchEarthquakesUseCase {
    private let repository: EarthquakeRepository

    init(repository: EarthquakeRepository) {
        self.repository = repository
    }

    func execute(feed: EarthquakeFeed = .week) async -> Result<[Earthquake]> {
        await repository.fetchEarthquakes(feed: feed)
    }
}

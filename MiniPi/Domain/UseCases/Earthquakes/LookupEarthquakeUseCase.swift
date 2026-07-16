//
//  LookupEarthquakeUseCase.swift
//  MiniPi
//
//  Business action: full detail for one USGS event by id (Search numeric-id query
//  and detail-sheet enrichment). Mirrors LookupAsteroidUseCase.
//

import Foundation

class LookupEarthquakeUseCase {
    private let repository: EarthquakeRepository

    init(repository: EarthquakeRepository) {
        self.repository = repository
    }

    func execute(id: String) async -> Result<Earthquake> {
        await repository.lookupEarthquake(id: id)
    }
}

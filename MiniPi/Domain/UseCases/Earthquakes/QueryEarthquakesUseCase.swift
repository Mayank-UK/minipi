//
//  QueryEarthquakesUseCase.swift
//  MiniPi
//
//  Business action: filtered search over USGS FDSNWS `query`. Powers the Search
//  tab's magnitude / depth / time-window / sort filters (applied server-side).
//

import Foundation

class QueryEarthquakesUseCase {
    private let repository: EarthquakeRepository

    init(repository: EarthquakeRepository) {
        self.repository = repository
    }

    func execute(_ query: EarthquakeQuery) async -> Result<[Earthquake]> {
        await repository.queryEarthquakes(query)
    }
}

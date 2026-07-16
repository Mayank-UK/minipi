//
//  SearchCitiesUseCase.swift
//  MiniPi
//
//  Business action: autocomplete city search over WeatherAPI.com `search.json`.
//  Powers the Home tab's search bar (one-shot per debounced query).
//

import Foundation

class SearchCitiesUseCase {
    private let repository: WeatherRepository

    init(repository: WeatherRepository) {
        self.repository = repository
    }

    func execute(query: String) async -> Result<[WeatherLocation]> {
        await repository.searchCities(query: query)
    }
}

//
//  FetchForecastUseCase.swift
//  MiniPi
//
//  Business action: load a full forecast (current + hours + days + astronomy + air
//  quality) for a location. Powers Home + Stats. Mirrors FetchEarthquakesUseCase —
//  a thin wrapper over the repository.
//

import Foundation

class FetchForecastUseCase {
    private let repository: WeatherRepository

    init(repository: WeatherRepository) {
        self.repository = repository
    }

    func execute(_ query: WeatherQuery) async -> Result<WeatherForecast> {
        await repository.fetchForecast(query)
    }
}

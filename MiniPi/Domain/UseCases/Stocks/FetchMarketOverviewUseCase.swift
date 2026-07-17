//
//  FetchMarketOverviewUseCase.swift
//  MiniPi
//
//  Business action: load the Home dataset (indices + top movers) for a country.
//  Cache-backed. Mirrors FetchForecastUseCase — a thin wrapper over the repository.
//

import Foundation

class FetchMarketOverviewUseCase {
    private let repository: StocksRepository

    init(repository: StocksRepository) {
        self.repository = repository
    }

    func execute(country: String) async -> Result<StockMarketOverview> {
        await repository.marketOverview(country: country)
    }
}

//
//  FetchForexOverviewUseCase.swift
//  MiniPi
//
//  Business action: load the Home dataset (USD-quoted majors + top movers).
//  Cache-backed. Mirrors FetchMarketOverviewUseCase — a thin wrapper over the repository.
//

import Foundation

class FetchForexOverviewUseCase {
    private let repository: ForexRepository

    init(repository: ForexRepository) {
        self.repository = repository
    }

    func execute() async -> Result<ForexMarketOverview> {
        await repository.marketOverview()
    }
}

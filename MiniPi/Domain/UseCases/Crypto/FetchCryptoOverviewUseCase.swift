//
//  FetchCryptoOverviewUseCase.swift
//  MiniPi
//
//  Business action: load the Home dataset (USD-quoted coins + top movers).
//  Cache-backed. Mirrors FetchForexOverviewUseCase — a thin wrapper over the repository.
//

import Foundation

class FetchCryptoOverviewUseCase {
    private let repository: CryptoRepository

    init(repository: CryptoRepository) {
        self.repository = repository
    }

    func execute() async -> Result<CryptoMarketOverview> {
        await repository.marketOverview()
    }
}

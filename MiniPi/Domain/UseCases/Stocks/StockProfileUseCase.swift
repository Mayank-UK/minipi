//
//  StockProfileUseCase.swift
//  MiniPi
//
//  Business action: fetch company/instrument metadata from Finnhub `profile2`
//  (one-shot). Powers the detail header (logo, industry, market cap, P/E).
//

import Foundation

class StockProfileUseCase {
    private let repository: StocksRepository

    init(repository: StocksRepository) {
        self.repository = repository
    }

    func execute(symbol: String) async -> Result<StockProfile?> {
        await repository.profile(symbol)
    }
}

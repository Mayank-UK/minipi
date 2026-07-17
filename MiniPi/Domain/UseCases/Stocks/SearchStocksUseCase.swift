//
//  SearchStocksUseCase.swift
//  MiniPi
//
//  Business action: autocomplete instrument search over Finnhub `search.json`.
//  Powers the Search tab (one-shot per debounced query). Mirrors SearchCitiesUseCase.
//

import Foundation

class SearchStocksUseCase {
    private let repository: StocksRepository

    init(repository: StocksRepository) {
        self.repository = repository
    }

    func execute(query: String) async -> Result<[StockSymbol]> {
        await repository.search(query: query)
    }
}

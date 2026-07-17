//
//  SearchForexUseCase.swift
//  MiniPi
//
//  Business action: autocomplete currency-pair search over Yahoo `/v1/finance/search`
//  (filtered to CURRENCY results). Powers the Search tab (one-shot per debounced query).
//  Mirrors SearchStocksUseCase.
//

import Foundation

class SearchForexUseCase {
    private let repository: ForexRepository

    init(repository: ForexRepository) {
        self.repository = repository
    }

    func execute(query: String) async -> Result<[ForexPair]> {
        await repository.search(query: query)
    }
}

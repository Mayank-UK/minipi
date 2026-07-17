//
//  SearchCryptoUseCase.swift
//  MiniPi
//
//  Business action: autocomplete coin search over Yahoo `/v1/finance/search`
//  (filtered to CRYPTOCURRENCY results). Powers the Search tab (one-shot per debounced
//  query). Mirrors SearchForexUseCase.
//

import Foundation

class SearchCryptoUseCase {
    private let repository: CryptoRepository

    init(repository: CryptoRepository) {
        self.repository = repository
    }

    func execute(query: String) async -> Result<[CryptoCoin]> {
        await repository.search(query: query)
    }
}

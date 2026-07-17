//
//  CryptoPriceUseCase.swift
//  MiniPi
//
//  Business action: fetch the latest price for a single coin (one-shot). Powers detail
//  headers + list refreshes. Mirrors ForexRateUseCase.
//

import Foundation

class CryptoPriceUseCase {
    private let repository: CryptoRepository

    init(repository: CryptoRepository) {
        self.repository = repository
    }

    func execute(symbol: String) async -> Result<CryptoQuote> {
        await repository.price(symbol)
    }
}

/// Bulk price fetch for a list of coins (one-shot, concurrent, per-coin failure
/// tolerant). Powers Search/Watchlist lists. Mirrors ForexRatesUseCase.
class CryptoPricesUseCase {
    private let repository: CryptoRepository

    init(repository: CryptoRepository) {
        self.repository = repository
    }

    func execute(coins: [CryptoCoin]) async -> Result<[CryptoQuoteItem]> {
        await repository.prices(for: coins)
    }
}

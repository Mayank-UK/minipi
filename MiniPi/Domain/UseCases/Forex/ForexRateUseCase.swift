//
//  ForexRateUseCase.swift
//  MiniPi
//
//  Business action: fetch the latest rate for a single pair (one-shot). Powers detail
//  headers + list refreshes. Mirrors QuoteUseCase.
//

import Foundation

class ForexRateUseCase {
    private let repository: ForexRepository

    init(repository: ForexRepository) {
        self.repository = repository
    }

    func execute(symbol: String) async -> Result<ForexQuote> {
        await repository.rate(symbol)
    }
}

/// Bulk rate fetch for a list of pairs (one-shot, concurrent, per-pair failure
/// tolerant). Powers Markets/Search/Watchlist lists. Mirrors QuotesUseCase.
class ForexRatesUseCase {
    private let repository: ForexRepository

    init(repository: ForexRepository) {
        self.repository = repository
    }

    func execute(pairs: [ForexPair]) async -> Result<[ForexQuoteItem]> {
        await repository.rates(for: pairs)
    }
}

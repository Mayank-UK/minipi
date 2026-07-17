//
//  QuoteUseCase.swift
//  MiniPi
//
//  Business action: fetch the latest quote for a single symbol (one-shot).
//  Powers detail headers + list refreshes.
//

import Foundation

class QuoteUseCase {
    private let repository: StocksRepository

    init(repository: StocksRepository) {
        self.repository = repository
    }

    func execute(symbol: String, currency: String? = nil) async -> Result<StockQuote> {
        await repository.quote(symbol, currency: currency)
    }
}

/// Bulk quote fetch for a list of symbols (one-shot, concurrent, per-symbol failure
/// tolerant). Powers Markets/Search/Watchlist lists.
class QuotesUseCase {
    private let repository: StocksRepository

    init(repository: StocksRepository) {
        self.repository = repository
    }

    func execute(symbols: [StockSymbol]) async -> Result<[StockQuoteItem]> {
        await repository.quotes(for: symbols)
    }
}

//
//  CandlesUseCase.swift
//  MiniPi
//
//  Business action: load the OHLCV candle series for a symbol over a window
//  (one-shot). Powers the detail chart + Stats.
//

import Foundation

class CandlesUseCase {
    private let repository: StocksRepository

    init(repository: StocksRepository) {
        self.repository = repository
    }

    func execute(_ query: StocksCandleQuery) async -> Result<StockCandle> {
        await repository.candles(query)
    }
}

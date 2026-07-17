//
//  ForexCandlesUseCase.swift
//  MiniPi
//
//  Business action: load the OHLCV candle series for a pair over a window (one-shot).
//  Powers the detail chart + Stats. Mirrors CandlesUseCase.
//

import Foundation

class ForexCandlesUseCase {
    private let repository: ForexRepository

    init(repository: ForexRepository) {
        self.repository = repository
    }

    func execute(_ query: ForexCandleQuery) async -> Result<ForexCandle> {
        await repository.candles(query)
    }
}

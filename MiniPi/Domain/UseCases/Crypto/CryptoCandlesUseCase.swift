//
//  CryptoCandlesUseCase.swift
//  MiniPi
//
//  Business action: load the OHLCV candle series for a coin over a window (one-shot).
//  Powers the detail chart + Stats. Mirrors ForexCandlesUseCase.
//

import Foundation

class CryptoCandlesUseCase {
    private let repository: CryptoRepository

    init(repository: CryptoRepository) {
        self.repository = repository
    }

    func execute(_ query: CryptoCandleQuery) async -> Result<CryptoCandle> {
        await repository.candles(query)
    }
}

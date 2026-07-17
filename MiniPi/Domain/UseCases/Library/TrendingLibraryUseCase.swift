//
//  TrendingLibraryUseCase.swift
//  MiniPi
//
//  Business action: load trending books for a period window (Open Library `/trending`).
//  Powers the Ranking tab (one-shot per selected period).
//

import Foundation

class TrendingLibraryUseCase {
    private let repository: LibraryRepository

    init(repository: LibraryRepository) {
        self.repository = repository
    }

    func execute(period: LibraryTrendingPeriod) async -> Result<[LibraryWork]> {
        await repository.trending(period: period)
    }
}

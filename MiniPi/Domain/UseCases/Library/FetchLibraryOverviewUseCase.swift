//
//  FetchLibraryOverviewUseCase.swift
//  MiniPi
//
//  Business action: load the Home dataset (trending books + popular subjects).
//  Cache-backed. Mirrors FetchCryptoOverviewUseCase — a thin wrapper over the repository.
//

import Foundation

class FetchLibraryOverviewUseCase {
    private let repository: LibraryRepository

    init(repository: LibraryRepository) {
        self.repository = repository
    }

    func execute() async -> Result<LibraryHomeOverview> {
        await repository.homeOverview()
    }
}

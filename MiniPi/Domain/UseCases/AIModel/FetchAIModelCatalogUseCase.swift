//
//  FetchAIModelCatalogUseCase.swift
//  MiniPi
//
//  Business action: load the AI model catalog (full OpenRouter list + aggregates).
//  Cache-backed. Mirrors FetchCryptoOverviewUseCase — a thin wrapper over the repository.
//

import Foundation

class FetchAIModelCatalogUseCase {
    private let repository: AIModelRepository

    init(repository: AIModelRepository) {
        self.repository = repository
    }

    func execute() async -> Result<AIModelCatalog> {
        await repository.catalog()
    }
}

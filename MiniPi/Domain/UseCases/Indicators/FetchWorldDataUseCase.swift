//
//  FetchWorldDataUseCase.swift
//  MiniPi
//
//  Business action: load the World Bank dataset (countries + curated indicators + latest
//  observations + aggregates). Cache-backed. Mirrors FetchAIModelCatalogUseCase — a thin
//  wrapper over the repository.
//

import Foundation

class FetchWorldDataUseCase {
    private let repository: IndicatorRepository

    init(repository: IndicatorRepository) {
        self.repository = repository
    }

    func execute() async -> Result<WorldDataCatalog> {
        await repository.catalog()
    }
}

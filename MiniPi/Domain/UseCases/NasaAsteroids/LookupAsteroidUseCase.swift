//
//  LookupAsteroidUseCase.swift
//  MiniPi
//
//  Single-body NASA `neo/{id}` lookup — used by the Search tab when the query is a
//  numeric NeoWs id. Mirrors FetchAsteroidsUseCase.
//

import Foundation

class LookupAsteroidUseCase {
    private let repository: AsteroidRepository

    init(repository: AsteroidRepository) {
        self.repository = repository
    }

    func execute(id: String) async -> Result<Asteroid> {
        await repository.lookupAsteroid(id: id)
    }
}

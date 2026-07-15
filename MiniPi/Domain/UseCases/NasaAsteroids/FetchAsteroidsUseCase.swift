//
//  FetchAsteroidsUseCase.swift
//  MiniPi
//
//  Business action: load the current week's near-Earth asteroids.
//  (Module A §A.5 — position math use case comes later with the 3D screen.)
//

import Foundation

class FetchAsteroidsUseCase {
    private let repository: AsteroidRepository

    init(repository: AsteroidRepository) {
        self.repository = repository
    }

    func execute() async -> Result<[Asteroid]> {
        await repository.fetchAsteroids()
    }
}

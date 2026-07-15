//
//  FetchOrbitalAsteroidsUseCase.swift
//  MiniPi
//
//  Loads asteroids that carry orbital elements (from `neo/browse`), used to drive
//  the 3D scene. Mirrors FetchAsteroidsUseCase.
//

import Foundation

class FetchOrbitalAsteroidsUseCase {
    private let repository: AsteroidRepository

    init(repository: AsteroidRepository) {
        self.repository = repository
    }

    func execute() async -> Result<[Asteroid]> {
        await repository.fetchOrbitalAsteroids()
    }
}

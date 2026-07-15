//
//  AsteroidRepository.swift
//  MiniPi
//
//  Domain contract for the NASA Asteroids feature (Module A).
//

import Foundation

protocol AsteroidRepository {
    func fetchAsteroids() async -> Result<[Asteroid]>
    func fetchOrbitalAsteroids() async -> Result<[Asteroid]>
    func lookupAsteroid(id: String) async -> Result<Asteroid>
}

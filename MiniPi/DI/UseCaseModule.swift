//
//  UseCaseModule.swift
//  IosDevelopersGuide
//
//  Mirrors the Android use-case `@Provides` entries (unscoped by default):
//  a fresh use-case instance per resolve, each backed by the repository module.
//

import FactoryKit

extension Container {
    var fetchPostsUseCase: Factory<FetchPostsUseCase> {
        /// Unscoped — a new instance per injection, like Hilt's default `@Provides`.
        Factory(self) {
            FetchPostsUseCase(repository: self.postRepository())
        }
    }

    var fetchAsteroidsUseCase: Factory<FetchAsteroidsUseCase> {
        /// Unscoped — a new instance per injection, like Hilt's default `@Provides`.
        Factory(self) {
            FetchAsteroidsUseCase(repository: self.asteroidRepository())
        }
    }

    var fetchOrbitalAsteroidsUseCase: Factory<FetchOrbitalAsteroidsUseCase> {
        Factory(self) {
            FetchOrbitalAsteroidsUseCase(repository: self.asteroidRepository())
        }
    }

    var getAsteroidPositionsUseCase: Factory<GetAsteroidPositionsUseCase> {
        Factory(self) { GetAsteroidPositionsUseCase() }
    }

    var lookupAsteroidUseCase: Factory<LookupAsteroidUseCase> {
        Factory(self) { LookupAsteroidUseCase(repository: self.asteroidRepository()) }
    }

    var fetchEarthquakesUseCase: Factory<FetchEarthquakesUseCase> {
        Factory(self) { FetchEarthquakesUseCase(repository: self.earthquakeRepository()) }
    }

    var queryEarthquakesUseCase: Factory<QueryEarthquakesUseCase> {
        Factory(self) { QueryEarthquakesUseCase(repository: self.earthquakeRepository()) }
    }

    var lookupEarthquakeUseCase: Factory<LookupEarthquakeUseCase> {
        Factory(self) { LookupEarthquakeUseCase(repository: self.earthquakeRepository()) }
    }

    var fetchForecastUseCase: Factory<FetchForecastUseCase> {
        Factory(self) { FetchForecastUseCase(repository: self.weatherRepository()) }
    }

    var searchCitiesUseCase: Factory<SearchCitiesUseCase> {
        Factory(self) { SearchCitiesUseCase(repository: self.weatherRepository()) }
    }
}

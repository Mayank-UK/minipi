//
//  RepositoryModule.swift
//  IosDevelopersGuide
//
//  Mirrors the Android `RepositoryModule` Hilt module: binds repository
//  implementations to their domain protocols. Resolves its own dependencies
//  from the other modules at build time.
//

import FactoryKit

extension Container {
    var postRepository: Factory<PostRepository> {
        /// Scoped and singleton — only one single instance for all injections
        Factory(self) {
            PostRepositoryImplementation(
                remote: self.postRemoteDataSource(),
                local: self.postLocalDataSource(),
                logger: self.repositoryLogger()
            )
        }
        .scope(.singleton)
    }

    var asteroidRepository: Factory<AsteroidRepository> {
        /// Scoped and singleton — only one single instance for all injections
        Factory(self) {
            AsteroidRepositoryImplementation(
                remote: self.asteroidRemoteDataSource(),
                local: self.asteroidLocalDataSource(),
                logger: self.repositoryLogger()
            )
        }
        .scope(.singleton)
    }

    var earthquakeRepository: Factory<EarthquakeRepository> {
        Factory(self) {
            EarthquakeRepositoryImplementation(
                remote: self.earthquakeRemoteDataSource(),
                local: self.earthquakeLocalDataSource(),
                logger: self.repositoryLogger()
            )
        }
        .scope(.singleton)
    }

    var weatherRepository: Factory<WeatherRepository> {
        Factory(self) {
            WeatherRepositoryImplementation(
                remote: self.weatherRemoteDataSource(),
                local: self.weatherLocalDataSource(),
                logger: self.repositoryLogger()
            )
        }
        .scope(.singleton)
    }
}

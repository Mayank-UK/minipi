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

    var stocksRepository: Factory<StocksRepository> {
        Factory(self) {
            StocksRepositoryImplementation(
                remote: self.stocksRemoteDataSource(),
                local: self.stocksLocalDataSource(),
                logger: self.repositoryLogger()
            )
        }
        .scope(.singleton)
    }

    var forexRepository: Factory<ForexRepository> {
        Factory(self) {
            ForexRepositoryImplementation(
                remote: self.forexRemoteDataSource(),
                local: self.forexLocalDataSource(),
                logger: self.repositoryLogger()
            )
        }
        .scope(.singleton)
    }

    var cryptoRepository: Factory<CryptoRepository> {
        Factory(self) {
            CryptoRepositoryImplementation(
                remote: self.cryptoRemoteDataSource(),
                local: self.cryptoLocalDataSource(),
                logger: self.repositoryLogger()
            )
        }
        .scope(.singleton)
    }

    var aiModelRepository: Factory<AIModelRepository> {
        Factory(self) {
            AIModelRepositoryImplementation(
                remote: self.aiModelRemoteDataSource(),
                local: self.aiModelLocalDataSource(),
                logger: self.repositoryLogger()
            )
        }
        .scope(.singleton)
    }

    var indicatorRepository: Factory<IndicatorRepository> {
        Factory(self) {
            IndicatorRepositoryImplementation(
                remote: self.indicatorRemoteDataSource(),
                local: self.indicatorLocalDataSource(),
                logger: self.repositoryLogger()
            )
        }
        .scope(.singleton)
    }

    var libraryRepository: Factory<LibraryRepository> {
        Factory(self) {
            LibraryRepositoryImplementation(
                remote: self.libraryRemoteDataSource(),
                local: self.libraryLocalDataSource(),
                logger: self.repositoryLogger()
            )
        }
        .scope(.singleton)
    }
}

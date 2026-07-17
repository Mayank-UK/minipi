//
//  DatabaseModule.swift
//  MiniPi
//
//  Resolves the single shared local store (real or fake), then hands out narrow
//  per-feature local-data-source views of it. `USE_FAKE_DATABASE` (config files)
//  toggles the whole layer. One store instance backs every feature — a database
//  is one engine, not one per feature.
//

import FactoryKit

extension Container {

    /// The single shared store (real `AppDatabase` or `FakeAppDatabase`).
    /// Resolved once; the narrow factories below return views of this same instance.
    var localStore: Factory<any LocalDataStore> {
        Factory(self) {
            let config = AppConfiguration.shared
            if config.useFakeDatabase {
                return FakeAppDatabase(
                    scenario: config.dbScenario,
                    logger: self.databaseLogger()
                ) as any LocalDataStore
            } else {
                return AppDatabase.shared as any LocalDataStore
            }
        }
        .scope(.singleton)
    }

    /// Feature-narrow views over the shared store — repositories depend on these.
    var postLocalDataSource: Factory<any PostLocalDataSource> {
        Factory(self) { self.localStore() as any PostLocalDataSource }
            .scope(.singleton)
    }

    var asteroidLocalDataSource: Factory<any AsteroidLocalDataSource> {
        Factory(self) { self.localStore() as any AsteroidLocalDataSource }
            .scope(.singleton)
    }

    var earthquakeLocalDataSource: Factory<any EarthquakeLocalDataSource> {
        Factory(self) { self.localStore() as any EarthquakeLocalDataSource }
            .scope(.singleton)
    }

    var weatherLocalDataSource: Factory<any WeatherLocalDataSource> {
        Factory(self) { self.localStore() as any WeatherLocalDataSource }
            .scope(.singleton)
    }

    var stocksLocalDataSource: Factory<any StocksLocalDataSource> {
        Factory(self) { self.localStore() as any StocksLocalDataSource }
            .scope(.singleton)
    }

    var forexLocalDataSource: Factory<any ForexLocalDataSource> {
        Factory(self) { self.localStore() as any ForexLocalDataSource }
            .scope(.singleton)
    }

    var cryptoLocalDataSource: Factory<any CryptoLocalDataSource> {
        Factory(self) { self.localStore() as any CryptoLocalDataSource }
            .scope(.singleton)
    }

    var aiModelLocalDataSource: Factory<any AIModelLocalDataSource> {
        Factory(self) { self.localStore() as any AIModelLocalDataSource }
            .scope(.singleton)
    }

    var indicatorLocalDataSource: Factory<any IndicatorLocalDataSource> {
        Factory(self) { self.localStore() as any IndicatorLocalDataSource }
            .scope(.singleton)
    }
}

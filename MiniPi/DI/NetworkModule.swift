import FactoryKit

extension Container {
    var failureInjection: Factory<FailureInjectionInterceptor> {
        Factory(self) {
            FailureInjectionInterceptor(scenario: AppConfiguration.shared.apiScenario)
        }
        .scope(.singleton)
    }

    var httpClient: Factory<HTTPClient> {
        Factory(self) {
            var interceptors: [Interceptor] = [
                AuthTokenInterceptor(provider: StubAuthTokenProvider()),
                RetryInterceptor(maxRetries: 2, baseDelay: .milliseconds(300)),
            ]

            if AppConfiguration.shared.environment == .development {
                interceptors.insert(self.failureInjection(), at: 1)
            }

            return HTTPClient(interceptors: interceptors)
        }
        .scope(.singleton)
    }

    var connectivity: Factory<ConnectivityService> {
        Factory(self) {
            ConnectivityService()
        }
        .scope(.singleton)
    }

    /// CoreLocation resolver for the Weather Home tab (device GPS, with auto:ip
    /// fallback handled by the view model).
    var locationService: Factory<LocationService> {
        Factory(self) { LocationService() }
            .scope(.singleton)
    }
    
    // USE_FAKE_API (in the config files) toggles the whole network layer between
    // the real per-feature data sources and the single `FakeApiService`. Each
    // feature's data source is resolved separately below — features never share a
    // fat API service protocol.

    var postRemoteDataSource: Factory<any PostRemoteDataSource> {
        Factory(self) {
            let config = AppConfiguration.shared
            if config.useFakeAPI {
                return FakeApiService(scenario: config.apiScenario) as any PostRemoteDataSource
            } else {
                return PostRemoteDataSourceImpl(client: self.httpClient()) as any PostRemoteDataSource
            }
        }
        .scope(.singleton)
    }

    var asteroidRemoteDataSource: Factory<any AsteroidRemoteDataSource> {
        Factory(self) {
            let config = AppConfiguration.shared
            if config.useFakeAPI {
                return FakeApiService(scenario: config.apiScenario) as any AsteroidRemoteDataSource
            } else {
                return AsteroidRemoteDataSourceImpl(client: self.httpClient()) as any AsteroidRemoteDataSource
            }
        }
        .scope(.singleton)
    }

    // USGS needs no key and there is no fake-earthquake data source, so this is
    // always the real implementation.
    var earthquakeRemoteDataSource: Factory<any EarthquakeRemoteDataSource> {
        Factory(self) {
            EarthquakeRemoteDataSourceImpl(client: self.httpClient()) as any EarthquakeRemoteDataSource
        }
        .scope(.singleton)
    }

    // WeatherAPI.com needs a key (AppConfiguration.shared.weatherApiKey). No fake
    // weather data source (house rule), so this is always the real implementation.
    var weatherRemoteDataSource: Factory<any WeatherRemoteDataSource> {
        Factory(self) {
            WeatherRemoteDataSourceImpl(client: self.httpClient()) as any WeatherRemoteDataSource
        }
        .scope(.singleton)
    }

    // Finnhub needs a token (AppConfiguration.shared.stocksApiKey). No fake stocks
    // data source (house rule), so this is always the real implementation.
    var stocksRemoteDataSource: Factory<any StocksRemoteDataSource> {
        Factory(self) {
            StocksRemoteDataSourceImpl(client: self.httpClient()) as any StocksRemoteDataSource
        }
        .scope(.singleton)
    }

    // Yahoo Finance forex pairs (`=X` suffix, no key). No fake forex data source
    // (house rule), so this is always the real implementation.
    var forexRemoteDataSource: Factory<any ForexRemoteDataSource> {
        Factory(self) {
            ForexRemoteDataSourceImpl(client: self.httpClient()) as any ForexRemoteDataSource
        }
        .scope(.singleton)
    }

    // Yahoo Finance cryptocurrencies (dash form e.g. BTC-USD, no key). No fake crypto
    // data source (house rule), so this is always the real implementation.
    var cryptoRemoteDataSource: Factory<any CryptoRemoteDataSource> {
        Factory(self) {
            CryptoRemoteDataSourceImpl(client: self.httpClient()) as any CryptoRemoteDataSource
        }
        .scope(.singleton)
    }

    // OpenRouter public model catalog (no key). No fake AI data source (house rule), so
    // this is always the real implementation.
    var aiModelRemoteDataSource: Factory<any AIModelRemoteDataSource> {
        Factory(self) {
            AIModelRemoteDataSourceImpl(client: self.httpClient()) as any AIModelRemoteDataSource
        }
        .scope(.singleton)
    }

    // World Bank Open Data API (no key). No fake data source (house rule), so this is
    // always the real implementation.
    var indicatorRemoteDataSource: Factory<any IndicatorRemoteDataSource> {
        Factory(self) {
            IndicatorRemoteDataSourceImpl(client: self.httpClient()) as any IndicatorRemoteDataSource
        }
        .scope(.singleton)
    }

    // Open Library public API (no key, no browser User-Agent). No fake data source
    // (house rule), so this is always the real implementation.
    var libraryRemoteDataSource: Factory<any LibraryRemoteDataSource> {
        Factory(self) {
            LibraryRemoteDataSourceImpl(client: self.httpClient()) as any LibraryRemoteDataSource
        }
        .scope(.singleton)
    }
}

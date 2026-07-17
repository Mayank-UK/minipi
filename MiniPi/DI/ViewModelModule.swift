//
//  ViewModelModule.swift
//  MiniPi
//
//  Register view models here. Each is resolved through Factory and receives
//  its dependencies (use cases, loggers, etc.) from the other DI modules.
//

import FactoryKit

extension Container {

    @MainActor
    var homeViewModel: Factory<HomeViewModel> {
        /// Singleton — a single instance shared across injections.
        Factory(self) { HomeViewModel(logger: self.viewModelLogger()) }
            .scope(.singleton)
    }
    
    @MainActor
    var pageNotFoundViewModel: Factory<PageNotFoundViewModel> {
        Factory(self) { PageNotFoundViewModel() }
            .scope(.singleton)
    }
    
    
    @MainActor
    var asteroidViewModel: Factory<AsteroidViewModel> {
        Factory(self) {
            AsteroidViewModel(
                logger: self.viewModelLogger(),
                fetchAsteroids: self.fetchAsteroidsUseCase(),
                fetchOrbitalAsteroids: self.fetchOrbitalAsteroidsUseCase(),
                getPositions: self.getAsteroidPositionsUseCase(),
                lookupAsteroid: self.lookupAsteroidUseCase(),
                favorites: self.favoritesStore()
            )
        }
            .scope(.singleton)
    }

    /// Persistent favorites for the asteroid "Saved" tab (UserDefaults-backed).
    var favoritesStore: Factory<FavoritesStore> {
        Factory(self) { FavoritesStore() }
            .scope(.singleton)
    }
    
    /// Persistent watchlist for the earthquake "Watchlist" tab (UserDefaults-backed).
    var earthquakeWatchlistStore: Factory<EarthquakeWatchlistStore> {
        Factory(self) { EarthquakeWatchlistStore() }
            .scope(.singleton)
    }

    @MainActor
    var earthquakeViewModel: Factory<EarthquakeViewModel> {
        Factory(self) {
            EarthquakeViewModel(
                logger: self.viewModelLogger(),
                fetchEarthquakes: self.fetchEarthquakesUseCase(),
                queryEarthquakes: self.queryEarthquakesUseCase(),
                lookupEarthquake: self.lookupEarthquakeUseCase(),
                watchlist: self.earthquakeWatchlistStore()
            )
        }
            .scope(.singleton)
    }
    
    /// Persistent "last selected city" for the Weather Home tab (UserDefaults-backed).
    var weatherCityStore: Factory<WeatherCityStore> {
        Factory(self) { WeatherCityStore() }
            .scope(.singleton)
    }

    @MainActor
    var weatherViewModel: Factory<WeatherViewModel> {
        Factory(self) {
            WeatherViewModel(
                logger: self.viewModelLogger(),
                fetchForecast: self.fetchForecastUseCase(),
                searchCities: self.searchCitiesUseCase(),
                cityStore: self.weatherCityStore(),
                locationService: self.locationService()
            )
        }
            .scope(.singleton)
    }
    
    
    /// Persistent watchlist for the Stocks "Watchlist" tab (UserDefaults-backed).
    var stocksWatchlistStore: Factory<StocksWatchlistStore> {
        Factory(self) { StocksWatchlistStore() }
            .scope(.singleton)
    }

    /// Persistent "last selected country" for the Stocks Home tab (UserDefaults-backed).
    var stocksCountryStore: Factory<StocksCountryStore> {
        Factory(self) { StocksCountryStore() }
            .scope(.singleton)
    }

    @MainActor
    var stocksViewModel: Factory<StocksViewModel> {
        Factory(self) {
            StocksViewModel(
                logger: self.viewModelLogger(),
                fetchMarketOverview: self.fetchMarketOverviewUseCase(),
                quote: self.quoteUseCase(),
                quotes: self.quotesUseCase(),
                candles: self.candlesUseCase(),
                searchStocks: self.searchStocksUseCase(),
                profile: self.stockProfileUseCase(),
                watchlist: self.stocksWatchlistStore(),
                countryStore: self.stocksCountryStore()
            )
        }
            .scope(.singleton)
    }
    
    @MainActor
    var cryptoViewModel: Factory<CryptoViewModel> {
        Factory(self) { CryptoViewModel(logger: self.viewModelLogger()) }
            .scope(.singleton)
    }

    /// Persistent watchlist for the Forex "Watchlist" tab (UserDefaults-backed).
    var forexWatchlistStore: Factory<ForexWatchlistStore> {
        Factory(self) { ForexWatchlistStore() }
            .scope(.singleton)
    }

    @MainActor
    var forexViewModel: Factory<ForexViewModel> {
        Factory(self) {
            ForexViewModel(
                logger: self.viewModelLogger(),
                fetchOverview: self.fetchForexOverviewUseCase(),
                rate: self.forexRateUseCase(),
                rates: self.forexRatesUseCase(),
                candles: self.forexCandlesUseCase(),
                searchForex: self.searchForexUseCase(),
                watchlist: self.forexWatchlistStore()
            )
        }
            .scope(.singleton)
    }
    
    
    @MainActor
    var aiModelsViewModel: Factory<AIModelsViewModel> {
        Factory(self) { AIModelsViewModel(logger: self.viewModelLogger()) }
            .scope(.singleton)
    }
    
    
    @MainActor
    var indicatorsViewModel: Factory<IndicatorsViewModel> {
        Factory(self) { IndicatorsViewModel(logger: self.viewModelLogger()) }
            .scope(.singleton)
    }
    
    @MainActor
    var libraryViewModel: Factory<LibraryViewModel> {
        Factory(self) { LibraryViewModel(logger: self.viewModelLogger()) }
            .scope(.singleton)
    }

    @MainActor
    var explainViewModel: Factory<ExplainViewModel> {
        Factory(self) { ExplainViewModel(logger: self.viewModelLogger()) }
            .scope(.singleton)
    }

    @MainActor
    var aboutViewModel: Factory<AboutViewModel> {
        Factory(self) { AboutViewModel(logger: self.viewModelLogger()) }
            .scope(.singleton)
    }
    


}


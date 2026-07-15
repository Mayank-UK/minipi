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
    
    @MainActor
    var earthquakeViewModel: Factory<EarthquakeViewModel> {
        Factory(self) { EarthquakeViewModel(logger: self.viewModelLogger()) }
            .scope(.singleton)
    }
    
    @MainActor
    var weatherViewModel: Factory<WeatherViewModel> {
        Factory(self) { WeatherViewModel(logger: self.viewModelLogger()) }
            .scope(.singleton)
    }
    
    
    @MainActor
    var stocksViewModel: Factory<StocksViewModel> {
        Factory(self) { StocksViewModel(logger: self.viewModelLogger()) }
            .scope(.singleton)
    }
    
    @MainActor
    var cryptoViewModel: Factory<CryptoViewModel> {
        Factory(self) { CryptoViewModel(logger: self.viewModelLogger()) }
            .scope(.singleton)
    }
    
    @MainActor
    var forexViewModel: Factory<ForexViewModel> {
        Factory(self) { ForexViewModel(logger: self.viewModelLogger()) }
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
    


}


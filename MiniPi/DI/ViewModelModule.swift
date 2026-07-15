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
    var asteroidViewModel: Factory<AsteroidViewModel> {
        Factory(self) { AsteroidViewModel(logger: self.viewModelLogger()) }
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
    var pageNotFoundViewModel: Factory<PageNotFoundViewModel> {
        Factory(self) { PageNotFoundViewModel() }
            .scope(.singleton)
    }
}

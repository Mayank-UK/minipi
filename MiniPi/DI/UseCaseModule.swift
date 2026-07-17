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

    var fetchMarketOverviewUseCase: Factory<FetchMarketOverviewUseCase> {
        Factory(self) { FetchMarketOverviewUseCase(repository: self.stocksRepository()) }
    }

    var quoteUseCase: Factory<QuoteUseCase> {
        Factory(self) { QuoteUseCase(repository: self.stocksRepository()) }
    }

    var quotesUseCase: Factory<QuotesUseCase> {
        Factory(self) { QuotesUseCase(repository: self.stocksRepository()) }
    }

    var candlesUseCase: Factory<CandlesUseCase> {
        Factory(self) { CandlesUseCase(repository: self.stocksRepository()) }
    }

    var searchStocksUseCase: Factory<SearchStocksUseCase> {
        Factory(self) { SearchStocksUseCase(repository: self.stocksRepository()) }
    }

    var stockProfileUseCase: Factory<StockProfileUseCase> {
        Factory(self) { StockProfileUseCase(repository: self.stocksRepository()) }
    }

    var fetchForexOverviewUseCase: Factory<FetchForexOverviewUseCase> {
        Factory(self) { FetchForexOverviewUseCase(repository: self.forexRepository()) }
    }

    var forexRateUseCase: Factory<ForexRateUseCase> {
        Factory(self) { ForexRateUseCase(repository: self.forexRepository()) }
    }

    var forexRatesUseCase: Factory<ForexRatesUseCase> {
        Factory(self) { ForexRatesUseCase(repository: self.forexRepository()) }
    }

    var forexCandlesUseCase: Factory<ForexCandlesUseCase> {
        Factory(self) { ForexCandlesUseCase(repository: self.forexRepository()) }
    }

    var searchForexUseCase: Factory<SearchForexUseCase> {
        Factory(self) { SearchForexUseCase(repository: self.forexRepository()) }
    }
}

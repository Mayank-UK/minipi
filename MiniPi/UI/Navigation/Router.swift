//
//  Router.swift
//  MiniPi
//
//  Centralized navigation router. Add new `routePaths` cases here as the
//  app grows and resolve them in `view(for:)`.
//

import Foundation
import SwiftUI
import FactoryKit

class Router: ObservableObject {

    /// All navigable destinations in the app. Start with `home`; extend as
    /// new screens are added.
    enum routePaths: Hashable {
        case home
        
        case asteroidScreen
        case earthquakeScreen
        case weatherScreen
        
        case stocks
        case crypto
        case forex
        
        case aiModels
        
        case indicators
        case library

        case explain
        case about
    }

    @Published var navigationStack: NavigationPath = NavigationPath()

    @MainActor @ViewBuilder func view(for route: routePaths) -> some View {
        switch route {
        
        case .home:
            HomeView(viewModel: Container.shared.homeViewModel())
            
        case .asteroidScreen:
            AsteroidView(viewModel: Container.shared.asteroidViewModel())
            
        case .earthquakeScreen:
            EarthquakeView(viewModel: Container.shared.earthquakeViewModel())
            
        case .weatherScreen:
            WeatherView(viewModel: Container.shared.weatherViewModel())
            
            
        case .stocks:
            StocksView(viewModel: Container.shared.stocksViewModel())
        
        case .crypto:
            CryptoView(viewModel: Container.shared.cryptoViewModel())

        case .forex:
            ForexView(viewModel: Container.shared.forexViewModel())


        case .aiModels:
            AIModelsView(viewModel: Container.shared.aiModelsViewModel())


        case .indicators:
            IndicatorsView(viewModel: Container.shared.indicatorsViewModel())

        case .library:
            LibraryView(viewModel: Container.shared.libraryViewModel())

        case .explain:
            ExplainView(viewModel: Container.shared.explainViewModel())

        case .about:
            AboutView(viewModel: Container.shared.aboutViewModel())
        }
    }

    func navigateTo(routePath: routePaths) {
        navigationStack.append(routePath)
    }

    func navigateBack() {
        navigationStack.removeLast()
    }

    func popToRoot() {
        navigationStack.removeLast(navigationStack.count)
    }
}

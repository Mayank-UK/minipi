//
//  HomeViewModel.swift
//  MiniPi
//

import Foundation
import FactoryKit
import SwiftUI

@MainActor
class HomeViewModel: ObservableObject {

    private let logger: AppLoggerProtocol
    
    // inject the usecases, repositories, services through constructor pattern but use simple utilities, data variables from within
    init(
        logger: AppLoggerProtocol = Container.shared.viewModelLogger(),
    ) {
        self.logger = logger
    }
    
    let scienceLinks: [LinkData] = [
        LinkData(
            image: "nasa",
            title: "NASA NEOs",
            routePath: Router.routePaths.asteroidScreen,
        ),
        LinkData(
            image: "earthquakes",
            title: "USGS Earthquakes",
            routePath: Router.routePaths.earthquakeScreen,
        ),
        LinkData(
            image: "weather",
            title: "Weather",
            routePath: Router.routePaths.weatherScreen,
        ),
    ]
    
    let financeLinks: [LinkData] = [
        LinkData(
            image: "stocks",
            title: "Stocks",
            routePath: Router.routePaths.stocks,
        ),
        LinkData(
            image: "forex",
            title: "Forex",
            routePath: Router.routePaths.forex,
        ),
        LinkData(
            image: "crypto",
            title: "Crypto",
            routePath: Router.routePaths.crypto,
        ),
    ]
    
    let aiLinks: [LinkData] = [
        LinkData(
            image: "ai",
            title: "AI models",
            routePath: Router.routePaths.aiModels,
        ),
    ]
    
    let educationLinks: [LinkData] = [
        LinkData(
            image: "indicators",
            title: "World bank indicators",
            routePath: Router.routePaths.indicators,
        ),
        LinkData(
            image: "library",
            title: "Library",
            routePath: Router.routePaths.library,
        ),
    ]
}

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
    
    let links: [LinkData] = [
        LinkData(
            image: "TestImage",
            title: "NASA NEOs",
            routePath: Router.routePaths.asteroidScreen,
        ),
        LinkData(
            image: "TestImage",
            title: "USGS Earthquakes",
            routePath: Router.routePaths.earthquakeScreen,
        ),
        LinkData(
            image: "TestImage",
            title: "Weather",
            routePath: Router.routePaths.weatherScreen,
        ),
    ]
}

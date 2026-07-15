//
//  TempViewModel.swift
//  MiniPi
//
//  Created by Mayank Upadhyay on 15/07/26.
//

import Foundation
import FactoryKit

@MainActor
class AsteroidViewModel: ObservableObject {
    
    private let logger: AppLoggerProtocol
    
    /// Inject dependencies through the constructor; Factory resolves the logger.
    init(logger: AppLoggerProtocol = Container.shared.viewModelLogger()) {
        self.logger = logger
        logger.info("AsteroidViewModel initialized")
    }
}

//
//  TempViewModel.swift
//  MiniPi
//
//  Created by Mayank Upadhyay on 15/07/26.
//

import Foundation
import FactoryKit

@MainActor
class CryptoViewModel: ObservableObject {
    private let logger: AppLoggerProtocol
    
    // inject the usecases, repositories, services through constructor pattern but use simple utilities, data variables from within
    init(logger: AppLoggerProtocol = Container.shared.viewModelLogger()) {
        self.logger = logger
        logger.info("CryptoViewModel initialized")
    }
}

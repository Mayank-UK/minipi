//
//  ExplainViewModel.swift
//  MiniPi
//

import Foundation
import FactoryKit

@MainActor
class ExplainViewModel: ObservableObject {

    private let logger: AppLoggerProtocol

    init(logger: AppLoggerProtocol = Container.shared.viewModelLogger()) {
        self.logger = logger
    }
}

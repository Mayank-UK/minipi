//
//  AboutViewModel.swift
//  MiniPi
//

import Foundation
import FactoryKit

@MainActor
class AboutViewModel: ObservableObject {

    private let logger: AppLoggerProtocol

    init(logger: AppLoggerProtocol = Container.shared.viewModelLogger()) {
        self.logger = logger
    }
}

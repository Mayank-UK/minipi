//
//  LoggingModule.swift
//  IosDevelopersGuide
//
//  Provides logger instances for different categories via FactoryKit DI
//

import FactoryKit

extension Container {
    var databaseLogger: Factory<AppLoggerProtocol> {
        Factory(self) {
            OSLogLogger(category: .database)
        }
        .scope(.singleton)
    }
    
    var networkLogger: Factory<AppLoggerProtocol> {
        Factory(self) {
            OSLogLogger(category: .network)
        }
        .scope(.singleton)
    }
    
    var repositoryLogger: Factory<AppLoggerProtocol> {
        Factory(self) {
            OSLogLogger(category: .repository)
        }
        .scope(.singleton)
    }
    
    var uiLogger: Factory<AppLoggerProtocol> {
        Factory(self) {
            OSLogLogger(category: .ui)
        }
        .scope(.singleton)
    }
    
    var viewModelLogger: Factory<AppLoggerProtocol> {
        Factory(self) {
            OSLogLogger(category: .viewModel)
        }
        .scope(.singleton)
    }
    
    var analyticsLogger: Factory<AppLoggerProtocol> {
        Factory(self) {
            OSLogLogger(category: .analytics)
        }
        .scope(.singleton)
    }
    
    var generalLogger: Factory<AppLoggerProtocol> {
        Factory(self) {
            OSLogLogger(category: .general)
        }
        .scope(.singleton)
    }
}

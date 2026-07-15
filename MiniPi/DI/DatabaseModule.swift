//
//  DatabaseModule.swift
//  IosDevelopersGuide
//
//  Mirrors the Android DatabaseModule.
//  Provides either the real CoreData database or the fake database, selected by
//  the `USE_FAKE_DATABASE` build setting so it can be toggled per environment.
//

import FactoryKit

extension Container {
    // USE_FAKE_DATABASE variable inside config files to switch between FakeApiService and ApiService, keep the wiring here
    var database: Factory<any DatabaseServiceProtocol> {
        Factory(self) {
            let config = AppConfiguration.shared
            if config.useFakeDatabase {
                return FakeAppDatabase(
                    scenario: config.dbScenario,
                    logger: self.databaseLogger()
                ) as any DatabaseServiceProtocol
            } else {
                return AppDatabase.shared as any DatabaseServiceProtocol
            }
        }
        .scope(.singleton)
    }
}

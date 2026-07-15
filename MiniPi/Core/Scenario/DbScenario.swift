//
//  DbScenario.swift
//  IosDevelopersGuide
//
//  Selects which failure path the dev-only `FakeAppDatabase` simulates.
//  Mirrors Android's `core/scenario/Scenarios.kt` and Flutter's
//  `core/scenario/db_scenario.dart`.
//

import Foundation

enum DbScenario {
    case success
    case empty
    case readError
    case writeError
    case connectionFailed
}

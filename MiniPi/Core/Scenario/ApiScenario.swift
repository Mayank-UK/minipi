//
//  ApiScenario.swift
//  IosDevelopersGuide
//
//  Selects which failure path the dev-only `FailureInjectionInterceptor`
//  (and `FakeApiService`) simulates. Mirrors Android's `core/scenario/Scenarios.kt`
//  and the Flutter `core/scenario/api_scenario.dart`.
//

import Foundation

enum ApiScenario {
    case success
    case networkError
    case timeout
    case serverError
    case notFound
    case unauthorized
    case invalidJson
}



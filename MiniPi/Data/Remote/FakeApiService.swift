//
//  FakeApiService.swift
//  IosDevelopersGuide
//
//  Created by [Your Name]
//  Copyright © 2026. All rights reserved.
//

import Foundation

// Use fakeApiService when backend is not ready yet.
// Conforms to BOTH feature remote-data-source protocols so a single fake can stand
// in for the real per-feature data sources during offline / fake-API development.

class FakeApiService: PostRemoteDataSource, AsteroidRemoteDataSource {
    
    private var scenario: ApiScenario
    private var latency: TimeInterval = 0.6
    
    private let fakePosts: [PostDTO] = [
        PostDTO(id: 1, title: "Fake Post 1", body: "This is a fake post from FakeApiService"),
        PostDTO(id: 2, title: "Fake Post 2", body: "Another fake post for testing"),
        PostDTO(id: 3, title: "Fake Post 3", body: "Testing error handling scenarios"),
    ]
    
    // Scenario is supplied by the DI module from AppConfiguration (single source of truth) — no
    // default here so the value can't drift.
    init(scenario: ApiScenario, latency: TimeInterval = 0.6) {
         self.scenario = scenario
        self.latency = latency
    }
    
    func setScenario(_ scenario: ApiScenario) {
        self.scenario = scenario
    }
    
    func fetchPosts() async throws -> [PostDTO] {
        return try await simulateApiCall("fetchPosts") {
            return self.fakePosts
        }
    }

    func fetchFeed(startDate: String, endDate: String) async throws -> NeoFeedDTO {
        return try await simulateApiCall("fetchFeed") {
            return NeoFeedDTO(elementCount: self.fakeAsteroids.count, nearEarthObjects: ["\(startDate)": self.fakeAsteroids])
        }
    }

    func lookup(id: String) async throws -> AsteroidDTO {
        return try await simulateApiCall("lookup") {
            return self.fakeAsteroids.first { $0.id == id } ?? self.fakeAsteroids[0]
        }
    }

    func browse(page: Int, size: Int) async throws -> NeoBrowseDTO {
        return try await simulateApiCall("browse") {
            return NeoBrowseDTO(nearEarthObjects: self.fakeAsteroids)
        }
    }

    // A few representative NEOs for offline / fake-API development.
    private let fakeAsteroids: [AsteroidDTO] = [
        AsteroidDTO(
            id: "99942", neoReferenceId: "99942", name: "99942 Apophis", designation: "Apophis",
            absoluteMagnitudeH: 19.7,
            estimatedDiameter: EstimatedDiameterDTO(meters: DiameterRangeDTO(min: 240, max: 540)),
            isPotentiallyHazardousAsteroid: true, isSentryObject: true,
            closeApproachData: [
                CloseApproachDTO(
                    closeApproachDate: "2029-04-13", epochDateCloseApproach: 1879027200000,
                    relativeVelocity: RelativeVelocityDTO(kilometersPerSecond: "7.42", kilometersPerHour: "26712"),
                    missDistance: MissDistanceDTO(astronomical: "0.00028", lunar: "0.11", kilometers: "38100"),
                    orbitingBody: "Earth"
                )
            ],
            orbitalData: OrbitalDataDTO(
                semiMajorAxis: "0.922", eccentricity: "0.191", inclination: "3.34",
                ascendingNodeLongitude: "204.4", perihelionArgument: "126.4",
                meanAnomaly: "15.0", epochOsculation: "2459000.5",
                orbitalPeriod: "323.6", firstObservationDate: "2004-06-19"
            )
        ),
        AsteroidDTO(
            id: "25143", neoReferenceId: "25143", name: "25143 Itokawa", designation: "Itokawa",
            absoluteMagnitudeH: 20.6,
            estimatedDiameter: EstimatedDiameterDTO(meters: DiameterRangeDTO(min: 220, max: 510)),
            isPotentiallyHazardousAsteroid: false, isSentryObject: false,
            closeApproachData: [
                CloseApproachDTO(
                    closeApproachDate: "2071-06-23", epochDateCloseApproach: 3199000000000,
                    relativeVelocity: RelativeVelocityDTO(kilometersPerSecond: "9.8", kilometersPerHour: "35280"),
                    missDistance: MissDistanceDTO(astronomical: "0.014", lunar: "5.4", kilometers: "2090000"),
                    orbitingBody: "Earth"
                )
            ],
            orbitalData: OrbitalDataDTO(
                semiMajorAxis: "1.32", eccentricity: "0.36", inclination: "1.62",
                ascendingNodeLongitude: "69.0", perihelionArgument: "128.0",
                meanAnomaly: "200.0", epochOsculation: "2459000.5",
                orbitalPeriod: "582.0", firstObservationDate: "1998-09-26"
            )
        ),
    ]
    
    private func simulateApiCall<T>(_ operation: String, success: @escaping () -> T) async throws -> T {
        try await Task.sleep(nanoseconds: UInt64(latency * 1_000_000_000))

        switch scenario {
        case .success:
            return success()

        case .networkError:
            throw NetworkException.noConnection(
                cause: URLError(.notConnectedToInternet),
                context: "FakeApiService network error simulation"
            )

        case .timeout:
            throw NetworkException.timeout(
                cause: URLError(.timedOut),
                context: "FakeApiService timeout simulation"
            )

        case .serverError:
            throw ServerException.internalServerError(
                statusCode: 500,
                cause: nil,
                context: "FakeApiService server error simulation"
            )

        case .notFound:
            throw ServerException.notFound(
                statusCode: 404,
                cause: nil,
                context: "FakeApiService not found simulation"
            )

        case .unauthorized:
            throw ServerException.unauthorized(
                statusCode: 401,
                cause: nil,
                context: "FakeApiService unauthorized simulation"
            )

        case .invalidJson:
            throw DecodingException.jsonDecodingFailed(
                cause: nil,
                context: "FakeApiService invalid JSON simulation"
            )
        }
    }
}

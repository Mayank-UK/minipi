//
//  AsteroidViewModel.swift
//  MiniPi
//
//  Module A — NASA Asteroids. Mirrors PostViewModel: isLoading / currentFailure / data,
//  plus the tab selection for the asteroid screen set (Home, 3D, Search, Favorites, More).
//

import Foundation
import FactoryKit
import SwiftUI
import Combine

@MainActor
class AsteroidViewModel: ObservableObject {

    private let logger: AppLoggerProtocol
    private let fetchAsteroidsUseCase: FetchAsteroidsUseCase
    private let fetchOrbitalAsteroidsUseCase: FetchOrbitalAsteroidsUseCase
    let getPositionsUseCase: GetAsteroidPositionsUseCase
    private let lookupAsteroidUseCase: LookupAsteroidUseCase
    let favorites: FavoritesStore

    @Published var asteroids: [Asteroid] = []
    @Published var isLoading: Bool = false
    @Published var currentFailure: Failure?

    @Published var selectedTab: AsteroidTab = .home

    // Explore (3D) state
    @Published var orbitalAsteroids: [Asteroid] = []
    @Published var isLoadingOrbital: Bool = false
    @Published var orbitalFailure: Failure?
    @Published var selectedAsteroid: Asteroid?
    @Published var selectedPlanet: String?
    @Published var timeScale: AsteroidTimeScale = .live

    // Search tab state
    @Published var searchQuery: String = ""
    @Published var searchFilters = SearchFilters()
    @Published var lookupResult: Asteroid?
    @Published var isLookingUp = false

    // Saved-tab derived list (rebuilt from FavoritesStore snapshots).
    @Published var savedAsteroids: [Asteroid] = []

    private var hasLoaded = false
    private var hasLoadedOrbital = false
    private var favoritesCancellable: AnyCancellable?
    private var lookupTask: Task<Void, Never>?

    // Time-playback anchors: when the scale changes, we capture the currently-displayed
    // simulated date and the real instant, so motion stays continuous.
    private var anchorReal: Date = Date()
    private var anchorSim: Date = Date()

    init(
        logger: AppLoggerProtocol = Container.shared.viewModelLogger(),
        fetchAsteroids: FetchAsteroidsUseCase,
        fetchOrbitalAsteroids: FetchOrbitalAsteroidsUseCase,
        getPositions: GetAsteroidPositionsUseCase,
        lookupAsteroid: LookupAsteroidUseCase,
        favorites: FavoritesStore
    ) {
        self.logger = logger
        self.fetchAsteroidsUseCase = fetchAsteroids
        self.fetchOrbitalAsteroidsUseCase = fetchOrbitalAsteroids
        self.getPositionsUseCase = getPositions
        self.lookupAsteroidUseCase = lookupAsteroid
        self.favorites = favorites
        // Mirror the persisted favorites into a list of displayable asteroids.
        savedAsteroids = favorites.snapshots.map { Asteroid(snapshot: $0) }
        favoritesCancellable = favorites.$snapshots
            .sink { [weak self] snapshots in
                self?.savedAsteroids = snapshots.map { Asteroid(snapshot: $0) }
            }
        logger.info("AsteroidViewModel initialized")
    }

    // MARK: - Loading (Home)

    func loadAsteroids(force: Bool = false) async {
        if isLoading { return }
        if hasLoaded && !force { return }

        isLoading = true
        currentFailure = nil

        logger.info("Loading asteroids")

        let result = await fetchAsteroidsUseCase.execute()

        switch result {
        case .success(let asteroids):
            self.asteroids = asteroids
            self.hasLoaded = true
            logger.info("Loaded \(asteroids.count) asteroids")
        case .failure(let failure):
            self.currentFailure = failure
            logger.error("Failed to load asteroids: \(failure.localizedDescription)")
        }

        isLoading = false
    }

    // MARK: - Loading (Explore / orbital)

    func loadOrbitalAsteroids(force: Bool = false) async {
        if isLoadingOrbital { return }
        if hasLoadedOrbital && !force { return }

        isLoadingOrbital = true
        orbitalFailure = nil

        logger.info("Loading orbital asteroids")

        let result = await fetchOrbitalAsteroidsUseCase.execute()

        switch result {
        case .success(let asteroids):
            // Keep only asteroids that actually carry orbital elements (the scene needs them).
            self.orbitalAsteroids = asteroids.filter { $0.orbitalElements != nil }
            self.hasLoadedOrbital = true
            logger.info("Loaded \(orbitalAsteroids.count) orbital asteroids")
        case .failure(let failure):
            self.orbitalFailure = failure
            logger.error("Failed to load orbital asteroids: \(failure.localizedDescription)")
        }

        isLoadingOrbital = false
    }

    func selectAsteroid(_ asteroid: Asteroid?) {
        selectedAsteroid = asteroid
        if asteroid != nil { selectedPlanet = nil }
    }

    func selectPlanet(_ name: String?) {
        selectedPlanet = name
        if name != nil { selectedAsteroid = nil }
    }

    func setTimeScale(_ scale: AsteroidTimeScale) {
        // Re-anchor from the currently-displayed date so switching speed is seamless.
        anchorSim = displayedDate(at: Date())
        anchorReal = Date()
        timeScale = scale
    }

    /// The simulated date to render, given the real (wall-clock) instant.
    func displayedDate(at realDate: Date) -> Date {
        switch timeScale.simulatedSecondsPerRealSecond {
        case 0:
            return realDate // Live
        case let rate:
            return anchorSim.addingTimeInterval(realDate.timeIntervalSince(anchorReal) * rate)
        }
    }

    func clearError() {
        currentFailure = nil
    }

    // MARK: - Search & Favorites

    /// Is this body saved? (Reads the persisted store.)
    func isFavorite(_ asteroid: Asteroid) -> Bool {
        favorites.contains(id: asteroid.id)
    }

    /// Toggle save/unsave; the Saved list updates via the store subscription.
    func toggleFavorite(_ asteroid: Asteroid) {
        favorites.toggle(asteroid)
    }

    func removeFavorite(id: String) {
        favorites.remove(id: id)
    }

    /// Deduped union of the home feed + orbital catalog — the Search dataset.
    var allAsteroids: [Asteroid] {
        var seen = Set<String>()
        return (asteroids + orbitalAsteroids)
            .filter { seen.insert($0.id).inserted }
    }

    /// Instant, local filter over `allAsteroids` by query + chips, then sorted.
    var searchResults: [Asteroid] {
        let query = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        let isNumericID = !query.isEmpty && query.allSatisfy(\.isNumber)

        var results = allAsteroids.filter { asteroid in
            // Text match (skip when the query is a pure id — handled by lookup).
            if !isNumericID && !query.isEmpty {
                let name = asteroid.name.lowercased()
                let desig = (asteroid.designation ?? "").lowercased()
                let matches = name.contains(query) || desig.contains(query) || asteroid.id == query
                if !matches { return false }
            }
            // Chips.
            if searchFilters.hazardousOnly && !asteroid.isPotentiallyHazardous { return false }
            if let minDiameter = searchFilters.minDiameter {
                let diameter = asteroid.diameterMaxMeters ?? 0
                if diameter < minDiameter { return false }
            }
            return true
        }

        switch searchFilters.sortBy {
        case .name:
            results.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .closest:
            results.sort { ($0.nextCloseApproach?.missDistanceLunar ?? .infinity) < ($1.nextCloseApproach?.missDistanceLunar ?? .infinity) }
        case .largest:
            results.sort { ($0.diameterMaxMeters ?? 0) > ($1.diameterMaxMeters ?? 0) }
        }

        // A successful id lookup sits at the top so the user sees it immediately.
        if let lookup = lookupResult, !results.contains(where: { $0.id == lookup.id }) {
            results.insert(lookup, at: 0)
        }
        return results
    }

    /// When the query is a numeric NASA id, look that body up via `neo/{id}`.
    /// Called reactively from the view as the query changes.
    func runLookupIfNeeded() {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        lookupTask?.cancel()
        guard !query.isEmpty, query.allSatisfy(\.isNumber) else {
            lookupResult = nil
            isLookingUp = false
            return
        }
        let id = query
        let useCase = lookupAsteroidUseCase
        isLookingUp = true
        lookupTask = Task { [weak self] in
            let result = await useCase.execute(id: id)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.isLookingUp = false
                switch result {
                case .success(let asteroid): self?.lookupResult = asteroid
                case .failure: self?.lookupResult = nil
                }
            }
        }
    }

    func clearOrbitalError() {
        orbitalFailure = nil
    }

    // MARK: - Derived stats for the Home tab

    /// Asteroids whose closest listed approach is today.
    var todaysApproaches: [Asteroid] {
        let calendar = Calendar.current
        return asteroids
            .compactMap { asteroid -> (Asteroid, CloseApproach)? in
                guard let approach = asteroid.nextCloseApproach,
                      let date = approach.date,
                      calendar.isDateInToday(date) else { return nil }
                return (asteroid, approach)
            }
            .sorted { ($0.1.date ?? .distantFuture) < ($1.1.date ?? .distantFuture) }
            .map { $0.0 }
    }

    var hazardousCount: Int {
        asteroids.filter { $0.isPotentiallyHazardous }.count
    }

    /// Closest approach in the window, by lunar distance (for the stat tile).
    var closestApproach: (asteroid: Asteroid, lunar: Double)? {
        asteroids
            .compactMap { asteroid -> (Asteroid, Double)? in
                guard let lunar = asteroid.nextCloseApproach?.missDistanceLunar else { return nil }
                return (asteroid, lunar)
            }
            .min(by: { $0.1 < $1.1 })
    }
}

// MARK: - Tab model

enum AsteroidTab: Hashable, CaseIterable {
    case home, explore, search, favorites

    var title: String {
        switch self {
        case .home: return "Home"
        case .explore: return "Explore"
        case .search: return "Search"
        case .favorites: return "Saved"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .explore: return "safari.fill"
        case .search: return "magnifyingglass"
        case .favorites: return "star.fill"
        }
    }
}

// MARK: - Time scale (Module A §A.2: Live · 1m/s · 1h/s · 1d/s · 3d/s · 7d/s)

enum AsteroidTimeScale: Hashable, CaseIterable {
    case live
    case minute
    case hour
    case day
    case threeDays
    case week

    var label: String {
        switch self {
        case .live: return "Live"
        case .minute: return "1m/s"
        case .hour: return "1h/s"
        case .day: return "1d/s"
        case .threeDays: return "3d/s"
        case .week: return "7d/s"
        }
    }

    /// Simulated seconds advanced per real second. 0 = run on real wall-clock time (Live).
    var simulatedSecondsPerRealSecond: TimeInterval {
        switch self {
        case .live: return 0
        case .minute: return 60
        case .hour: return 3_600
        case .day: return 86_400
        case .threeDays: return 3 * 86_400
        case .week: return 7 * 86_400
        }
    }
}

// MARK: - Search filters (Module A §A.10, screen 4)

/// Minimum-diameter chip buckets (meters). `nil` = "Any".
enum AsteroidMinDiameter: Hashable, CaseIterable, Identifiable {
    case any, m50, m140, m500

    var id: Self { self }
    var label: String {
        switch self {
        case .any: return "Any size"
        case .m50: return "> 50m"
        case .m140: return "> 140m"
        case .m500: return "> 500m"
        }
    }
    var value: Double? {
        switch self {
        case .any: return nil
        case .m50: return 50
        case .m140: return 140
        case .m500: return 500
        }
    }
}

enum AsteroidSort: Hashable, CaseIterable, Identifiable {
    case name, closest, largest
    var id: Self { self }
    var label: String {
        switch self {
        case .name: return "Name"
        case .closest: return "Closest"
        case .largest: return "Largest"
        }
    }
    var icon: String {
        switch self {
        case .name: return "textformat"
        case .closest: return "ruler"
        case .largest: return "circle.fill"
        }
    }
}

struct SearchFilters: Equatable {
    var hazardousOnly: Bool = false
    var minDiameterBucket: AsteroidMinDiameter = .any
    var sortBy: AsteroidSort = .closest

    var minDiameter: Double? { minDiameterBucket.value }
}

//
//  EarthquakeViewModel.swift
//  MiniPi
//
//  USGS Earthquakes. Mirrors AsteroidViewModel: isLoading / currentFailure / data,
//  plus the tab selection for the earthquake screen set (Home · Map · Search ·
//  Stats · Watchlist). Owns the feed dataset (Home/Map/Stats), the server-backed
//  Search query, the id lookup, and the persisted Watchlist.
//

import Foundation
import FactoryKit
import SwiftUI
import Combine

@MainActor
class EarthquakeViewModel: ObservableObject {

    private let logger: AppLoggerProtocol
    private let fetchEarthquakesUseCase: FetchEarthquakesUseCase
    private let queryEarthquakesUseCase: QueryEarthquakesUseCase
    private let lookupEarthquakeUseCase: LookupEarthquakeUseCase
    let watchlist: EarthquakeWatchlistStore

    // MARK: - Feed (Home / Map / Stats)
    @Published var earthquakes: [Earthquake] = []
    @Published var isLoading: Bool = false
    @Published var currentFailure: Failure?
    @Published var selectedFeed: EarthquakeFeed = .week

    // MARK: - Tab + selection
    @Published var selectedTab: EarthquakeTab = .home
    @Published var selectedEarthquake: Earthquake?

    // MARK: - Search
    @Published var searchResults: [Earthquake] = []
    @Published var isSearching: Bool = false
    @Published var searchFailure: Failure?
    @Published var searchFilters = EarthquakeSearchFilters()
    @Published var placeFilter: String = ""           // client-side text filter over results
    @Published var lookupResult: Earthquake?
    @Published var isLookingUp = false

    // MARK: - Watchlist (rebuilt from store snapshots)
    @Published var watchlistQuakes: [Earthquake] = []

    private var hasLoadedFeed = false
    private(set) var hasSearched = false
    private var watchlistCancellable: AnyCancellable?
    private var lookupTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?

    init(
        logger: AppLoggerProtocol = Container.shared.viewModelLogger(),
        fetchEarthquakes: FetchEarthquakesUseCase,
        queryEarthquakes: QueryEarthquakesUseCase,
        lookupEarthquake: LookupEarthquakeUseCase,
        watchlist: EarthquakeWatchlistStore
    ) {
        self.logger = logger
        self.fetchEarthquakesUseCase = fetchEarthquakes
        self.queryEarthquakesUseCase = queryEarthquakes
        self.lookupEarthquakeUseCase = lookupEarthquake
        self.watchlist = watchlist

        watchlistQuakes = watchlist.snapshots.map { Earthquake(snapshot: $0) }
        watchlistCancellable = watchlist.$snapshots
            .sink { [weak self] snapshots in
                self?.watchlistQuakes = snapshots.map { Earthquake(snapshot: $0) }
            }
        logger.info("EarthquakeViewModel initialized")
    }

    // MARK: - Feed loading (Home / Map / Stats)

    func loadFeed(force: Bool = false) async {
        if isLoading { return }
        if hasLoadedFeed && !force { return }

        isLoading = true
        currentFailure = nil

        logger.info("Loading earthquake feed (\(selectedFeed.rawValue))")
        let result = await fetchEarthquakesUseCase.execute(feed: selectedFeed)

        switch result {
        case .success(let quakes):
            self.earthquakes = Self.sortedByNewest(quakes)
            self.hasLoadedFeed = true
            logger.info("Loaded \(quakes.count) earthquakes")
        case .failure(let failure):
            self.currentFailure = failure
            logger.error("Failed to load earthquakes: \(failure.localizedDescription)")
        }

        isLoading = false
    }

    /// Switch the Map window (feed) and reload.
    func setFeed(_ feed: EarthquakeFeed) {
        guard feed != selectedFeed else { return }
        selectedFeed = feed
        hasLoadedFeed = false
        Task { await loadFeed(force: true) }
    }

    func clearError() {
        currentFailure = nil
    }

    // MARK: - Search (server query + client-side place filter + id lookup)

    /// Schedule a debounced search. Cancels any pending/in-flight search so only
    /// the latest filter selection wins. `immediate` skips the debounce delay
    /// (first load + explicit drill-downs from Home stat tiles).
    func scheduleSearch(immediate: Bool = false) {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            guard let self else { return }
            if !immediate {
                try? await Task.sleep(nanoseconds: 350_000_000)
                if Task.isCancelled { return }
            }
            await self.performSearch()
        }
    }

    private func performSearch() async {
        if isSearching { return }
        isSearching = true
        searchFailure = nil

        logger.info("Running earthquake search")
        let result = await queryEarthquakesUseCase.execute(searchFilters.toQuery())

        // A newer scheduled search may have cancelled this one mid-flight.
        if Task.isCancelled {
            isSearching = false
            return
        }

        switch result {
        case .success(let quakes):
            // A successful id lookup sits at the top if not already present.
            var results = Self.sortedByNewest(quakes)
            if let lookup = lookupResult, !results.contains(where: { $0.id == lookup.id }) {
                results.insert(lookup, at: 0)
            }
            self.searchResults = results
            self.hasSearched = true
            logger.info("Search returned \(results.count) earthquakes")
        case .failure(let failure):
            self.searchFailure = failure
            logger.error("Search failed: \(failure.localizedDescription)")
        }

        isSearching = false
    }

    /// Search results after the client-side place text filter is applied.
    var filteredSearchResults: [Earthquake] {
        let query = placeFilter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return searchResults }
        return searchResults.filter {
            ($0.place ?? "").lowercased().contains(query) ||
            ($0.title ?? "").lowercased().contains(query)
        }
    }

    /// When the place filter reads as a USGS event id, look that event up.
    func runLookupIfNeeded() {
        let query = placeFilter.trimmingCharacters(in: .whitespaces)
        lookupTask?.cancel()
        guard !query.isEmpty, Self.looksLikeEventID(query) else {
            lookupResult = nil
            isLookingUp = false
            return
        }
        let id = query
        let useCase = lookupEarthquakeUseCase
        isLookingUp = true
        lookupTask = Task { [weak self] in
            let result = await useCase.execute(id: id)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.isLookingUp = false
                switch result {
                case .success(let quake):
                    self?.lookupResult = quake
                    // Surface it at the top of the current results too.
                    if let self {
                        self.searchResults.removeAll { $0.id == quake.id }
                        self.searchResults.insert(quake, at: 0)
                    }
                case .failure:
                    self?.lookupResult = nil
                }
            }
        }
    }

    func clearSearchError() {
        searchFailure = nil
    }

    // MARK: - Drill-downs (Home stat tiles)

    /// Open the Search tab with the time window matching the current feed
    /// (the tile is labelled with the feed, e.g. "This Week"), then run it.
    func openSearch() {
        searchFilters.timeWindow = EarthquakeViewModel.timeWindow(for: selectedFeed)
        selectedTab = .search
        scheduleSearch(immediate: true)
    }

    private static func timeWindow(for feed: EarthquakeFeed) -> EarthquakeTimeWindow {
        switch feed {
        case .hour: return .hour
        case .day: return .day
        case .week: return .week
        case .month: return .month
        }
    }

    /// Open the Search tab pre-filtered to notable events (magnitude >= 4).
    func openNotableInSearch() {
        searchFilters.minMagnitude = .m4
        selectedTab = .search
        scheduleSearch(immediate: true)
    }

    // MARK: - Watchlist

    func isSaved(_ earthquake: Earthquake) -> Bool {
        watchlist.contains(id: earthquake.id)
    }

    func toggleSaved(_ earthquake: Earthquake) {
        watchlist.toggle(earthquake)
    }

    func removeSaved(id: String) {
        watchlist.remove(id: id)
    }

    // MARK: - Derived stats (Home + Stats tabs)

    /// Events whose origin time is today.
    var todaysEarthquakes: [Earthquake] {
        let calendar = Calendar.current
        return earthquakes
            .filter { $0.time.map { calendar.isDateInToday($0) } ?? false }
    }

    /// Newest-first slice for the Home "Recent Earthquakes" list.
    var recentEarthquakes: [Earthquake] {
        Array(Self.sortedByNewest(earthquakes).prefix(8))
    }

    /// Largest by magnitude (ignores unknown magnitudes).
    var largestEarthquake: Earthquake? {
        earthquakes.compactMap { q in q.magnitude.map { (q, $0) } }
            .max(by: { $0.1 < $1.1 })?.0
    }

    /// Count of notable events (magnitude >= 4.5).
    var significantCount: Int {
        earthquakes.filter { ($0.magnitude ?? 0) >= 4.5 }.count
    }

    /// Count of events per magnitude band — feeds the Home mini-bar and Stats.
    var magnitudeDistribution: [(band: MagnitudeBand, range: String, count: Int)] {
        MagnitudeBand.orderedBuckets.map { entry in
            let count = earthquakes.filter { $0.magnitudeBand == entry.band }.count
            return (entry.band, entry.range, count)
        }
    }

    /// Count per day over the loaded window — feeds the Stats "over time" line.
    var perDayCounts: [(day: Date, count: Int)] {
        let calendar = Calendar.current
        let buckets = Dictionary(grouping: earthquakes) { quake -> Date in
            guard let time = quake.time else { return Date.distantPast }
            return calendar.startOfDay(for: time)
        }
        return buckets
            .map { (day: $0.key, count: $0.value.count) }
            .sorted { $0.day < $1.day }
    }

    /// Count per depth band (shallow / intermediate / deep).
    var depthDistribution: [(label: String, count: Int)] {
        let shallow = earthquakes.filter { ($0.depthKm ?? 0) < 70 }.count
        let intermediate = earthquakes.filter { d in let depth = d.depthKm ?? 0; return depth >= 70 && depth < 300 }.count
        let deep = earthquakes.filter { ($0.depthKm ?? 0) >= 300 }.count
        return [("0 – 70 km", shallow), ("70 – 300 km", intermediate), ("300+ km", deep)]
    }

    /// Top regions by event count, derived from the `place` string's country tail.
    var topRegions: [(region: String, count: Int)] {
        var counts: [String: Int] = [:]
        for quake in earthquakes {
            let region = Self.region(from: quake.place) ?? "Unknown"
            counts[region, default: 0] += 1
        }
        return counts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { ($0.key, $0.value) }
    }

    // MARK: - Helpers

    static func sortedByNewest(_ quakes: [Earthquake]) -> [Earthquake] {
        quakes.sorted { ($0.time ?? .distantPast) > ($1.time ?? .distantPast) }
    }

    /// USGS ids look like "us7000me69" / "nc73739210" — a leading network code
    /// then digits. Plain numbers also work as `code` lookups.
    private static func looksLikeEventID(_ query: String) -> Bool {
        query.allSatisfy { $0.isNumber } ||
        (query.count >= 5 && query.first?.isLetter == true && query.dropFirst().allSatisfy { $0.isNumber })
    }

    /// Crude region extraction: take the text after " of " when present, else the
    /// whole place string. Good enough for a "top regions" bar.
    private static func region(from place: String?) -> String? {
        guard let place, !place.isEmpty else { return nil }
        if let range = place.range(of: " of ", options: .backwards) {
            return String(place[range.upperBound...])
        }
        return place
    }
}

// MARK: - Tab model

enum EarthquakeTab: Hashable, CaseIterable {
    case home, map, search, stats, watchlist

    var title: String {
        switch self {
        case .home: return "Home"
        case .map: return "Map"
        case .search: return "Search"
        case .stats: return "Stats"
        case .watchlist: return "Watchlist"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .map: return "globe.americas.fill"
        case .search: return "magnifyingglass"
        case .stats: return "chart.bar.fill"
        case .watchlist: return "star.fill"
        }
    }
}

// MARK: - Search filters (Search tab)

/// Min-magnitude chip buckets (FDSNWS `minmagnitude`). `nil` = "Any".
enum EarthquakeMinMagnitude: Hashable, CaseIterable, Identifiable {
    case any, m2, m4, m5, m6, m7
    var id: Self { self }
    var label: String {
        switch self {
        case .any: return "Any"
        case .m2: return "2+"
        case .m4: return "4+"
        case .m5: return "5+"
        case .m6: return "6+"
        case .m7: return "7+"
        }
    }
    var value: Double? {
        switch self {
        case .any: return nil
        case .m2: return 2
        case .m4: return 4
        case .m5: return 5
        case .m6: return 6
        case .m7: return 7
        }
    }
}

/// Depth filter buckets (FDSNWS min/maxdepth, km).
enum EarthquakeDepthBucket: Hashable, CaseIterable, Identifiable {
    case any, shallow, intermediate, deep
    var id: Self { self }
    var label: String {
        switch self {
        case .any: return "Any depth"
        case .shallow: return "0 – 70 km"
        case .intermediate: return "70 – 300 km"
        case .deep: return "300+ km"
        }
    }
    var minDepth: Double? {
        switch self {
        case .any, .shallow: return nil
        case .intermediate: return 70
        case .deep: return 300
        }
    }
    var maxDepth: Double? {
        switch self {
        case .any, .deep: return nil
        case .shallow: return 70
        case .intermediate: return 300
        }
    }
}

/// Time window for the FDSNWS query (lookback from now).
enum EarthquakeTimeWindow: Hashable, CaseIterable, Identifiable {
    case hour, day, week, month
    var id: Self { self }
    var label: String {
        switch self {
        case .hour: return "Last hour"
        case .day: return "24 hours"
        case .week: return "7 days"
        case .month: return "30 days"
        }
    }
    /// `startTime` (lookback) — `nil` = no start filter.
    var startLookback: Date? {
        let now = Date()
        switch self {
        case .hour: return now.addingTimeInterval(-3600)
        case .day: return now.addingTimeInterval(-86_400)
        case .week: return now.addingTimeInterval(-7 * 86_400)
        case .month: return now.addingTimeInterval(-30 * 86_400)
        }
    }
}

struct EarthquakeSearchFilters: Equatable {
    var minMagnitude: EarthquakeMinMagnitude = .any
    var depth: EarthquakeDepthBucket = .any
    var timeWindow: EarthquakeTimeWindow = .week
    var orderBy: EarthquakeOrder = .time

    /// Translate the UI filters into the repository query.
    func toQuery() -> EarthquakeQuery {
        EarthquakeQuery(
            startTime: timeWindow.startLookback,
            endTime: nil,
            minMagnitude: minMagnitude.value,
            maxMagnitude: nil,
            minDepthKm: depth.minDepth,
            maxDepthKm: depth.maxDepth,
            orderBy: orderBy
        )
    }
}

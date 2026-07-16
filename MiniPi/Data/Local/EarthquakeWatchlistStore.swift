//
//  EarthquakeWatchlistStore.swift
//  MiniPi
//
//  Persisted watchlist for the earthquake "Watchlist" tab. Backed by UserDefaults
//  so saved events survive an app restart — mirrors FavoritesStore exactly. The
//  app's main DB is intentionally in-memory (see AppDatabase header), so a small
//  dedicated store is the lightest genuinely-persistent option for a saved list.
//

import Foundation
import Combine

/// A Codable slice of an `Earthquake`: enough to render a Watchlist row and a
/// detail sheet after relaunch, when the live feed may not be loaded yet.
struct EarthquakeSnapshot: Codable, Identifiable, Equatable {
    let id: String
    let magnitude: Double?
    let magType: String?
    let place: String?
    let title: String?
    let savedEpoch: Double
    let originTime: Double?      // epoch ms
    let depthKm: Double?
    let latitude: Double?
    let longitude: Double?
    let isTsunami: Bool
    let alertLevel: String?
    let significance: Int?
    let type: String?
    let url: String?
}

final class EarthquakeWatchlistStore: ObservableObject {

    @Published private(set) var snapshots: [EarthquakeSnapshot] = []

    private let defaults: UserDefaults
    private let key = "minipi.earthquake.watchlist"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.snapshots = load()
    }

    // MARK: - Access

    func contains(id: String) -> Bool {
        snapshots.contains { $0.id == id }
    }

    /// Adds the earthquake if not already saved, else removes it.
    func toggle(_ earthquake: Earthquake) {
        if let index = snapshots.firstIndex(where: { $0.id == earthquake.id }) {
            snapshots.remove(at: index)
        } else {
            snapshots.append(Self.snapshot(from: earthquake))
        }
        persist()
    }

    func remove(id: String) {
        snapshots.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Earthquake → snapshot

    private static func snapshot(from earthquake: Earthquake) -> EarthquakeSnapshot {
        EarthquakeSnapshot(
            id: earthquake.id,
            magnitude: earthquake.magnitude,
            magType: earthquake.magType,
            place: earthquake.place,
            title: earthquake.title,
            savedEpoch: Date().timeIntervalSince1970,
            originTime: earthquake.time.map { $0.timeIntervalSince1970 * 1000 },
            depthKm: earthquake.depthKm,
            latitude: earthquake.coordinate?.latitude,
            longitude: earthquake.coordinate?.longitude,
            isTsunami: earthquake.isTsunami,
            alertLevel: earthquake.alertLevel,
            significance: earthquake.significance,
            type: earthquake.type,
            url: earthquake.url
        )
    }

    // MARK: - Persistence

    private func load() -> [EarthquakeSnapshot] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([EarthquakeSnapshot].self, from: data)) ?? []
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(snapshots) {
            defaults.set(data, forKey: key)
        }
    }
}

// MARK: - Snapshot → Earthquake (for rendering Watchlist rows + detail without the live feed)

extension Earthquake {
    init(snapshot: EarthquakeSnapshot) {
        let coordinate: GeoCoordinate? = {
            if let lat = snapshot.latitude, let lon = snapshot.longitude {
                return GeoCoordinate(latitude: lat, longitude: lon)
            }
            return nil
        }()
        self.init(
            id: snapshot.id,
            magnitude: snapshot.magnitude,
            magType: snapshot.magType,
            place: snapshot.place,
            title: snapshot.title,
            time: snapshot.originTime.map { Date(timeIntervalSince1970: $0 / 1000.0) },
            updated: nil,
            depthKm: snapshot.depthKm,
            coordinate: coordinate,
            isTsunami: snapshot.isTsunami,
            alertLevel: snapshot.alertLevel,
            significance: snapshot.significance,
            feltReports: nil,
            type: snapshot.type,
            url: snapshot.url,
            detailUrl: nil
        )
    }
}

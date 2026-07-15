//
//  FavoritesStore.swift
//  MiniPi
//
//  Persisted favorites for the asteroid "Saved" tab (Module A §A.10, screen 5).
//  Backed by UserDefaults so saved bodies survive an app restart — the app's main
//  DB is intentionally in-memory (see AppDatabase header), so a small dedicated
//  store is the lightest genuinely-persistent option for a favorites list.
//

import Foundation
import Combine

/// A Codable slice of an `Asteroid`: enough to render a Saved row and a detail
/// sheet after relaunch, when the live feed may not be loaded yet.
struct FavoriteSnapshot: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let designation: String?
    let absoluteMagnitudeH: Double?
    let diameterMinMeters: Double?
    let diameterMaxMeters: Double?
    let isPotentiallyHazardous: Bool
    let isSentryObject: Bool
    let savedEpoch: Double
}

final class FavoritesStore: ObservableObject {

    @Published private(set) var snapshots: [FavoriteSnapshot] = []

    private let defaults: UserDefaults
    private let key = "minipi.asteroid.favorites"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.snapshots = load()
    }

    // MARK: - Access

    func contains(id: String) -> Bool {
        snapshots.contains { $0.id == id }
    }

    /// Adds the asteroid if not already saved, else removes it.
    func toggle(_ asteroid: Asteroid) {
        if let index = snapshots.firstIndex(where: { $0.id == asteroid.id }) {
            snapshots.remove(at: index)
        } else {
            snapshots.append(Self.snapshot(from: asteroid))
        }
        persist()
    }

    func remove(id: String) {
        snapshots.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Asteroid → snapshot

    private static func snapshot(from asteroid: Asteroid) -> FavoriteSnapshot {
        FavoriteSnapshot(
            id: asteroid.id,
            name: asteroid.name,
            designation: asteroid.designation,
            absoluteMagnitudeH: asteroid.absoluteMagnitudeH,
            diameterMinMeters: asteroid.diameterMinMeters,
            diameterMaxMeters: asteroid.diameterMaxMeters,
            isPotentiallyHazardous: asteroid.isPotentiallyHazardous,
            isSentryObject: asteroid.isSentryObject,
            savedEpoch: Date().timeIntervalSince1970
        )
    }

    // MARK: - Persistence

    private func load() -> [FavoriteSnapshot] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([FavoriteSnapshot].self, from: data)) ?? []
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(snapshots) {
            defaults.set(data, forKey: key)
        }
    }
}

// MARK: - Snapshot → Asteroid (for rendering Saved rows + detail without the live feed)

extension Asteroid {
    init(snapshot: FavoriteSnapshot) {
        self.init(
            id: snapshot.id,
            name: snapshot.name,
            designation: snapshot.designation,
            absoluteMagnitudeH: snapshot.absoluteMagnitudeH,
            diameterMinMeters: snapshot.diameterMinMeters,
            diameterMaxMeters: snapshot.diameterMaxMeters,
            isPotentiallyHazardous: snapshot.isPotentiallyHazardous,
            isSentryObject: snapshot.isSentryObject,
            closeApproaches: [],
            orbitalElements: nil
        )
    }
}

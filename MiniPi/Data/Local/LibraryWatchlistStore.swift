//
//  LibraryWatchlistStore.swift
//  MiniPi
//
//  Persisted watchlist for the Library "Watchlist" tab. Backed by UserDefaults so saved
//  books survive an app restart — mirrors CryptoWatchlistStore exactly. Stores a Codable
//  slice (enough to render a row + detail header after relaunch).
//

import Foundation
import Combine

/// A Codable slice of a `LibraryWork`: enough to render a Watchlist row and a detail header
/// after relaunch.
struct LibrarySnapshot: Codable, Identifiable, Equatable {
    let id: String                 // bare OLID, e.g. "OL45804W"
    let key: String                // "/works/OL45804W"
    let title: String
    let primaryAuthor: String
    let coverId: Int?
    let coverEditionKey: String?
    let firstPublishYear: Int?
    let savedEpoch: Double
}

final class LibraryWatchlistStore: ObservableObject {

    @Published private(set) var snapshots: [LibrarySnapshot] = []

    private let defaults: UserDefaults
    private let key = "minipi.library.watchlist"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.snapshots = load()
    }

    // MARK: - Access

    func contains(id: String) -> Bool {
        snapshots.contains { $0.id == id }
    }

    /// Adds the work if not already saved, else removes it.
    func toggle(work: LibraryWork) {
        if let index = snapshots.firstIndex(where: { $0.id == work.id }) {
            snapshots.remove(at: index)
        } else {
            snapshots.append(Self.snapshot(from: work))
        }
        persist()
    }

    func remove(id: String) {
        snapshots.removeAll { $0.id == id }
        persist()
    }

    /// The saved works to render in the Watchlist tab (before any detail refresh).
    var savedWorks: [LibraryWork] {
        snapshots.map { $0.toWork() }
    }

    // MARK: - Snapshot → from live work

    private static func snapshot(from work: LibraryWork) -> LibrarySnapshot {
        LibrarySnapshot(
            id: work.id,
            key: work.key,
            title: work.title,
            primaryAuthor: work.primaryAuthor,
            coverId: work.coverId,
            coverEditionKey: work.coverEditionKey,
            firstPublishYear: work.firstPublishYear,
            savedEpoch: Date().timeIntervalSince1970
        )
    }

    // MARK: - Persistence

    private func load() -> [LibrarySnapshot] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([LibrarySnapshot].self, from: data)) ?? []
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(snapshots) {
            defaults.set(data, forKey: key)
        }
    }
}

private extension LibrarySnapshot {
    /// Rebuild a renderable `LibraryWork` from the persisted slice.
    func toWork() -> LibraryWork {
        LibraryWork(
            id: id,
            key: key,
            title: title,
            authors: [primaryAuthor],
            authorIds: [],
            coverId: coverId,
            coverEditionKey: coverEditionKey,
            firstPublishYear: firstPublishYear,
            editionCount: nil,
            subjects: nil,
            language: nil,
            ebookAccess: nil
        )
    }
}

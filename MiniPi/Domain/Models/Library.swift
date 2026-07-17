//
//  Library.swift
//  MiniPi
//
//  Domain models for the Library feature (Open Library). Mirrors the plain-value-type
//  + derived-text-helper shape used across features (Crypto/Forex/Indicators). Used by
//  Home (trending books + popular subjects), Search (server autocomplete by books/authors/
//  subjects), Ranking (trending books by period), Watchlist (persisted snapshots) and the
//  book detail sheet.
//
//  Provider = Open Library public API, no key. Book covers come from the separate covers
//  host (`covers.openlibrary.org`); both a numeric cover id and an edition OLID can resolve
//  a cover URL, so the model surfaces both and derives the best available URL.
//

import Foundation

// MARK: - Work

/// A book "work" — the abstract title (one per logical book, spanning many editions). `id`
/// is the bare OLID (e.g. "OL45804W"); `key` is the full API path ("/works/OL45804W").
struct LibraryWork: Identifiable, Equatable {
    let id: String                  // bare OLID, e.g. "OL45804W"
    let key: String                 // "/works/OL45804W"
    let title: String
    let authors: [String]           // display names, e.g. ["J. K. Rowling"]
    let authorIds: [String]         // bare author OLIDs, e.g. ["OL23919A"]
    let coverId: Int?               // numeric cover id (cover_i)
    let coverEditionKey: String?    // edition OLID used as a cover fallback
    let firstPublishYear: Int?
    let editionCount: Int?
    let subjects: [String]?
    let language: [String]?         // e.g. ["eng"]
    let ebookAccess: String?        // "borrowable" / "readable" / "no_ebook" / …

    /// Best available medium-size cover URL (nil when neither id nor edition key exists).
    var coverURL: URL? {
        if let coverId {
            return URL(string: "https://covers.openlibrary.org/b/id/\(coverId)-M.jpg")
        }
        if let coverEditionKey {
            return URL(string: "https://covers.openlibrary.org/b/olid/\(coverEditionKey)-M.jpg")
        }
        return nil
    }

    /// First author name, or "Unknown author" — used as the row subtitle / detail header.
    var primaryAuthor: String {
        authors.first?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? authors.first! : "Unknown author"
    }

    /// A one-line label: author + first-publish year, e.g. "J. K. Rowling · 1997".
    var subtitle: String {
        var parts = [primaryAuthor]
        if let year = firstPublishYear { parts.append(String(year)) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Subject

/// A browseable subject (Fiction, Science, …). `slug` is the URL-safe key; `workCount` is
/// Open Library's catalog size for that subject (used by Home's aggregate book count).
struct LibrarySubject: Identifiable, Equatable {
    let slug: String                // e.g. "science"
    let displayName: String         // e.g. "Science"
    let workCount: Int

    var id: String { slug }

    /// Compact "1.2M" / "940K" / "320" for the subjects grid + Home stats.
    var workCountText: String {
        Self.compactCount(workCount)
    }

    /// Compact count formatter shared with the Home book count aggregate.
    static func compactCount(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.0fK", Double(value) / 1_000)
        }
        return "\(value)"
    }
}

// MARK: - Author summary (Search discover)

/// A lightweight author entry for the Search tab's default "Popular authors" content —
/// derived from the trending works (no dedicated trending-authors endpoint exists). `count`
/// is how many trending works cite the author. Identifiable by name.
struct LibraryAuthorSummary: Identifiable, Equatable {
    let name: String
    let count: Int

    var id: String { name }

    /// Two-letter initials for the avatar circle (e.g. "J. K. Rowling" → "JK").
    var initials: String {
        let parts = name.split(separator: " ").map(String.init)
        let letters = parts.compactMap { $0.first }.map { String($0).uppercased() }
        return String(letters.prefix(2).joined())
    }
}

// MARK: - Book detail

/// Full detail for a single work, fetched on demand for the detail sheet. The Open Library
/// work endpoint's `description` is polymorphic (a String OR {type, value}); the DTO
/// flattens that to a plain String, so this model only ever sees text.
struct LibraryBookDetail: Equatable {
    let id: String
    let title: String
    let description: String?
    let subjects: [String]
    let authors: [String]
    let coverURL: URL?
    let firstPublishYear: Int?
}

// MARK: - Home overview (cache-backed)

/// The Home tab dataset: trending books + the curated popular subjects. Cache-backed like
/// `CryptoMarketOverview` / `WorldDataCatalog` — remote-first, persists on success, falls
/// back to the cache on network/server error.
struct LibraryHomeOverview: Equatable {
    let trendingBooks: [LibraryWork]
    let popularSubjects: [LibrarySubject]

    static let empty = LibraryHomeOverview(trendingBooks: [], popularSubjects: [])

    /// Aggregate catalog size across the popular subjects (a Home StatTile). Approximate —
    /// Open Library's `stats.json` is flaky, so we derive this from fetched subject counts.
    var bookCount: Int {
        popularSubjects.map(\.workCount).reduce(0, +)
    }
}

// MARK: - Ranking period

/// The Ranking tab chip bar — Open Library trending windows. `now/daily/weekly/monthly/
/// yearly` return 200; `forever`/`today` 500, so they are deliberately excluded.
enum LibraryTrendingPeriod: String, CaseIterable, Identifiable {
    case now
    case daily
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .now: return "Now"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }

    var icon: String {
        switch self {
        case .now: return "sparkles"
        case .daily: return "calendar.day.timeline.left"
        case .weekly: return "calendar"
        case .monthly: return "calendar.badge.clock"
        case .yearly: return "calendar.circle"
        }
    }
}

// MARK: - Search scope

/// The Search tab filter chips. All three scopes query `/search.json`; the scope picks the
/// query param (`q=` / `author=` / `subject=`), so results are always `LibraryWork` and one
/// row type renders every scope.
enum LibrarySearchScope: String, CaseIterable, Identifiable {
    case books
    case authors
    case subjects

    var id: String { rawValue }

    var title: String {
        switch self {
        case .books: return "Books"
        case .authors: return "Authors"
        case .subjects: return "Subjects"
        }
    }

    var icon: String {
        switch self {
        case .books: return "books.vertical.fill"
        case .authors: return "person.fill"
        case .subjects: return "tag.fill"
        }
    }
}

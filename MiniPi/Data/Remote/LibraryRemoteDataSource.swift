//
//  LibraryRemoteDataSource.swift
//  MiniPi
//
//  Feature-scoped remote data source for Open Library. Owns only the library endpoints
//  behind a narrow protocol; the shared networking engine (HTTPClient + interceptors) is
//  injected — exactly like the other features.
//
//  Open Library needs NO API key and NO browser User-Agent (unlike Yahoo), so every request
//  uses the plain `HTTPClient.get(_:as:)` overload. No BOM strip is needed either (Open
//  Library returns clean JSON, unlike World Bank).
//

import Foundation

protocol LibraryRemoteDataSource {
    /// `/search.json` — works by free-text query, optionally constrained to an author or a
    /// subject. Pass exactly one of query/author/subject; the others are nil.
    func searchWorks(query: String?, author: String?, subject: String?, limit: Int) async throws -> LibrarySearchResponseDTO

    /// `/subjects/{slug}.json` — a subject's catalog size + sample works.
    func subject(_ slug: String, limit: Int) async throws -> LibrarySubjectResponseDTO

    /// `/trending/{period}.json` — trending works for a window.
    func trending(_ period: LibraryTrendingPeriod, limit: Int) async throws -> LibraryTrendingResponseDTO

    /// `/works/{OLID}.json` — full detail for one work.
    func work(_ id: String) async throws -> LibraryWorkDetailDTO
}

final class LibraryRemoteDataSourceImpl: LibraryRemoteDataSource {

    private let openLibraryBaseURL = "https://openlibrary.org"
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func searchWorks(query: String?, author: String?, subject: String?, limit: Int) async throws -> LibrarySearchResponseDTO {
        var items: [String] = []
        if let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append("q=\(encode(query))")
        }
        if let author, !author.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append("author=\(encode(author))")
        }
        if let subject, !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append("subject=\(encode(subject))")
        }
        items.append("limit=\(limit)")
        items.append("fields=key,title,author_name,author_key,cover_i,cover_edition_key,first_publish_year,edition_count,subject,language,ebook_access")

        let url = "\(openLibraryBaseURL)/search.json?\(items.joined(separator: "&"))"
        return try await client.get(url, as: LibrarySearchResponseDTO.self)
    }

    func subject(_ slug: String, limit: Int) async throws -> LibrarySubjectResponseDTO {
        let encoded = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        let url = "\(openLibraryBaseURL)/subjects/\(encoded).json?limit=\(limit)"
        return try await client.get(url, as: LibrarySubjectResponseDTO.self)
    }

    func trending(_ period: LibraryTrendingPeriod, limit: Int) async throws -> LibraryTrendingResponseDTO {
        let url = "\(openLibraryBaseURL)/trending/\(period.rawValue).json?limit=\(limit)"
        return try await client.get(url, as: LibraryTrendingResponseDTO.self)
    }

    func work(_ id: String) async throws -> LibraryWorkDetailDTO {
        let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        let url = "\(openLibraryBaseURL)/works/\(encoded).json"
        return try await client.get(url, as: LibraryWorkDetailDTO.self)
    }

    private func encode(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }
}

// MARK: - Curated popular subjects

/// The Home "Popular subjects" grid (also drives the aggregate book count + the subject
/// tap-to-search shortcuts). Adding a subject = one line. Mirrors `CuratedIndicators` /
/// `CryptoUniverse`.
enum LibrarySubjects {
    struct Entry {
        let slug: String
        let displayName: String
        let icon: String            // SF Symbol for the grid tile
    }

    static let popular: [Entry] = [
        Entry(slug: "fiction", displayName: "Fiction", icon: "book.fill"),
        Entry(slug: "science", displayName: "Science", icon: "flask.fill"),
        Entry(slug: "history", displayName: "History", icon: "scroll.fill"),
        Entry(slug: "fantasy", displayName: "Fantasy", icon: "wand.and.stars"),
        Entry(slug: "romance", displayName: "Romance", icon: "heart.fill"),
        Entry(slug: "mystery_and_detective_stories", displayName: "Mystery", icon: "magnifyingglass"),
        Entry(slug: "biography", displayName: "Biography", icon: "person.fill"),
        Entry(slug: "philosophy", displayName: "Philosophy", icon: "brain.head.profile")
    ]
}

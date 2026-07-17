//
//  LibraryDto.swift
//  MiniPi
//
//  Open Library Codable DTOs + `toLibrary*` mappers. Mappers are named `toLibrary*`
//  (not `toWork`/`toSubject`) to follow the same anti-collision convention the spec flags
//  for the Yahoo DTOs — and to keep this self-contained.
//
//  Endpoints (all GET, no key, plain `HTTPClient.get`):
//    • /search.json?q=|author=|subject=  → LibrarySearchResponseDTO { docs:[LibraryWorkDTO] }
//    • /trending/{period}.json           → LibraryTrendingResponseDTO { works:[LibraryWorkDTO] }
//    • /subjects/{slug}.json             → LibrarySubjectResponseDTO { work_count, works }
//    • /works/{OLID}.json                → LibraryWorkDetailDTO (description is polymorphic)
//
//  GOTCHA: the work-detail `description` is EITHER a plain String OR an object
//  `{ "type": "/type/text", "value": "…" }`. `DescriptionDTO` decodes from a single-value
//  container and returns the `value` when an object — the same defensive shape used for the
//  World Bank heterogeneous envelope. The domain model only ever sees a String.
//

import Foundation

// MARK: - Search / trending work

/// A work document. Used verbatim by `/search.json` (field `docs`) and `/trending/{period}`
/// (field `works`) — the item shape is identical. Field names match Open Library's snake_case
/// JSON; nil-tolerant because not every work carries every field.
struct LibraryWorkDTO: Decodable {
    let key: String                 // "/works/OL45804W"
    let title: String?
    let author_name: [String]?
    let author_key: [String]?
    let cover_i: Int?
    let cover_edition_key: String?
    let first_publish_year: Int?
    let edition_count: Int?
    let subject: [String]?
    let language: [String]?
    let ebook_access: String?

    /// Map to the domain work. Drops rows with no title / no parseable OLID. Authors are
    /// zipped by index (Open Library guarantees author_name[i] ↔ author_key[i]); a missing
    /// partner just truncates.
    func toLibraryWork() -> LibraryWork? {
        let title = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else { return nil }
        let id = Self.bareOlid(from: key)
        guard !id.isEmpty else { return nil }

        let names = author_name ?? []
        let keys = author_key ?? []
        var authors: [String] = []
        var authorIds: [String] = []
        for index in names.indices {
            authors.append(names[index])
            if index < keys.count { authorIds.append(keys[index]) }
        }

        return LibraryWork(
            id: id,
            key: key,
            title: title,
            authors: authors,
            authorIds: authorIds,
            coverId: cover_i,
            coverEditionKey: cover_edition_key,
            firstPublishYear: first_publish_year,
            editionCount: edition_count,
            subjects: subject?.prefix(20).map { $0 },
            language: language?.prefix(5).map { $0 },
            ebookAccess: ebook_access
        )
    }

    /// "/works/OL45804W" → "OL45804W" (last path component).
    static func bareOlid(from key: String) -> String {
        key.split(separator: "/").last.map(String.init) ?? ""
    }
}

/// `/search.json` envelope.
struct LibrarySearchResponseDTO: Decodable {
    let numFound: Int?
    let docs: [LibraryWorkDTO]?

    func toWorks() -> [LibraryWork] {
        (docs ?? []).compactMap { $0.toLibraryWork() }
    }
}

/// `/trending/{period}.json` envelope (note `works`, not `docs`).
struct LibraryTrendingResponseDTO: Decodable {
    let works: [LibraryWorkDTO]?

    func toWorks() -> [LibraryWork] {
        (works ?? []).compactMap { $0.toLibraryWork() }
    }
}

// MARK: - Subject

/// `/subjects/{slug}.json`. The work item shape differs from search (cover_id not cover_i;
/// authors are objects with name+key), so it has its own DTO + mapper.
struct LibrarySubjectResponseDTO: Decodable {
    let name: String?
    let work_count: Int?
    let works: [LibrarySubjectWorkDTO]?

    func toSubject(slug: String) -> LibrarySubject {
        LibrarySubject(
            slug: slug,
            displayName: (name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? slug.capitalized,
            workCount: work_count ?? 0
        )
    }
}

struct LibrarySubjectWorkDTO: Decodable {
    let key: String?
    let title: String?
    let cover_id: Int?
    let cover_edition_key: String?
    let first_publish_year: Int?
    let edition_count: Int?
    let subject: [String]?
    let language: [String]?
    let authors: [LibrarySubjectAuthorDTO]?
    let ebook_access: String?

    func toLibraryWork() -> LibraryWork? {
        let title = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty, let key else { return nil }
        let id = LibraryWorkDTO.bareOlid(from: key)
        guard !id.isEmpty else { return nil }

        let authorDTOs = authors ?? []
        return LibraryWork(
            id: id,
            key: key,
            title: title,
            authors: authorDTOs.compactMap { $0.name?.trimmingCharacters(in: .whitespacesAndNewlines) },
            authorIds: authorDTOs.compactMap { $0.key.map { LibraryWorkDTO.bareOlid(from: $0) } },
            coverId: cover_id,
            coverEditionKey: cover_edition_key,
            firstPublishYear: first_publish_year,
            editionCount: edition_count,
            subjects: subject?.prefix(20).map { $0 },
            language: language?.prefix(5).map { $0 },
            ebookAccess: ebook_access
        )
    }
}

struct LibrarySubjectAuthorDTO: Decodable {
    let name: String?
    let key: String?
}

// MARK: - Work detail

/// `/works/{OLID}.json`. `description` is polymorphic (String or {type,value}); `DescriptionDTO`
/// flattens it to a String. Subjects on the detail endpoint are a flat `[String]`.
struct LibraryWorkDetailDTO: Decodable {
    let title: String?
    let description: DescriptionDTO?
    let subjects: [String]?
    let authors: [LibraryWorkDetailAuthorDTO]?
    let covers: [Int]?

    func toLibraryBookDetail(id: String, fallbackTitle: String) -> LibraryBookDetail {
        let coverURL: URL? = {
            if let coverId = covers?.last {
                return URL(string: "https://covers.openlibrary.org/b/id/\(coverId)-L.jpg")
            }
            return nil
        }()
        return LibraryBookDetail(
            id: id,
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? fallbackTitle,
            description: description?.text,
            subjects: subjects ?? [],
            authors: [],
            coverURL: coverURL,
            firstPublishYear: nil
        )
    }
}

struct LibraryWorkDetailAuthorDTO: Decodable {
    let author: LibraryAuthorRefDTO?
}

struct LibraryAuthorRefDTO: Decodable {
    let key: String?
}

/// Decodes a polymorphic description: a plain String, or `{ "type": …, "value": "…" }`.
/// Either way yields `.text` as the human description (nil when absent / unparseable).
struct DescriptionDTO: Decodable {
    let text: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self.text = stringValue
        } else if let object = try? container.decode(DescriptionValueDTO.self) {
            self.text = object.value
        } else {
            self.text = nil
        }
    }
}

private struct DescriptionValueDTO: Decodable {
    let value: String?
}

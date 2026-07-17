//
//  SearchLibraryUseCase.swift
//  MiniPi
//
//  Business action: server-backed work search over Open Library `/search.json`, scoped to
//  books / authors / subjects. Powers the Search tab (one-shot per debounced query).
//  Mirrors SearchCryptoUseCase.
//

import Foundation

class SearchLibraryUseCase {
    private let repository: LibraryRepository

    init(repository: LibraryRepository) {
        self.repository = repository
    }

    func execute(query: String, scope: LibrarySearchScope) async -> Result<[LibraryWork]> {
        await repository.search(query, scope: scope)
    }
}

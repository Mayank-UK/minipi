//
//  FetchLibraryWorkUseCase.swift
//  MiniPi
//
//  Business action: load full detail for one work (Open Library `/works/{OLID}`).
//  Powers the book detail sheet (one-shot).
//

import Foundation

class FetchLibraryWorkUseCase {
    private let repository: LibraryRepository

    init(repository: LibraryRepository) {
        self.repository = repository
    }

    func execute(id: String) async -> Result<LibraryBookDetail> {
        await repository.workDetail(id)
    }
}

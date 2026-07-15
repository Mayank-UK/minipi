//
//  FetchPostsUseCase.swift
//  IosDevelopersGuide
//
//  Created by Mayank Upadhyay on 22/08/24.
//

import Foundation

class FetchPostsUseCase {
    private let repository: PostRepository
    
    init(repository: PostRepository) {
        self.repository = repository
    }
    
    func execute() async -> Result<[Post]> {
        return await repository.fetchPosts()
    }
}

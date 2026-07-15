//
//  PostRepository.swift
//  IosDevelopersGuide
//
//  Created by Mayank Upadhyay on 22/08/24.
//

import Foundation

protocol PostRepository {
    func fetchPosts() async -> Result<[Post]>
}

//
//  PostDto.swift
//  IosDevelopersGuide
//
//  Created by Mayank Upadhyay on 22/08/24.
//

import Foundation

struct PostDTO: Codable {
    let id: Int
    let title: String
    let body: String
}

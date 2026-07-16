//
//  PostRemoteDataSource.swift
//  MiniPi
//
//  Feature-scoped remote data source for Posts. A feature owns its own narrow
//  protocol so its repository depends only on the endpoints it needs (Interface
//  Segregation) and never sees unrelated features' calls. The shared networking
//  engine (HTTPClient + interceptors) is injected — endpoints are all this type
//  adds.
//

import Foundation

protocol PostRemoteDataSource {
    func fetchPosts() async throws -> [PostDTO]
}

final class PostRemoteDataSourceImpl: PostRemoteDataSource {

    private let baseURL = AppConfiguration.shared.apiBaseURL
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func fetchPosts() async throws -> [PostDTO] {
        try await client.get("\(baseURL)/posts", as: [PostDTO].self)
    }
}

//
//  AIModelRemoteDataSource.swift
//  MiniPi
//
//  Feature-scoped remote data source for the OpenRouter model catalog. Owns only the one
//  catalog endpoint behind a narrow protocol; the shared networking engine (HTTPClient +
//  interceptors) is injected — exactly like the other feature data sources.
//
//  OpenRouter's public catalog needs no API key and no special User-Agent (unlike Yahoo),
//  so the base URL is a hardcoded constant here (like `usgsBaseURL`), with no
//  xcconfig/AppConfiguration entry.
//

import Foundation

protocol AIModelRemoteDataSource {
    /// `/api/v1/models` — the full model catalog (one call). Powers Home / Ranking /
    /// Search / Compare.
    func catalog() async throws -> [AIModel]
}

final class AIModelRemoteDataSourceImpl: AIModelRemoteDataSource {

    private let openRouterBaseURL = "https://openrouter.ai"
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    func catalog() async throws -> [AIModel] {
        let url = "\(openRouterBaseURL)/api/v1/models"
        let envelope = try await client.get(url, as: OpenRouterModelsDTO.self)
        // Drop tombstone rows with no id; preserve endpoint order.
        return envelope.data.compactMap { $0.toAIModel() }
    }
}

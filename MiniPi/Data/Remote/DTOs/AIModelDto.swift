//
//  AIModelDto.swift
//  MiniPi
//
//  Codable DTOs for OpenRouter's `/api/v1/models` catalog, plus the `toAIModel()`
//  mapper into the domain model. The endpoint needs no API key and returns every model
//  in one payload (`{ data, total_count }`), so a single GET maps straight to the
//  `AIModelCatalog`.
//
//  All optional — OpenRouter's schema is sparse (many fields are null per model), so the
//  mapper tolerates missing values and falls back sensibly (e.g. provider from the id
//  prefix, free/priced from the pricing legs, open-weight from a non-null hugging_face id).
//
//  Pricing legs are USD-per-token strings ("0.000003"); the domain model carries them as
//  Doubles and the UI formats per-million. Null/blank pricing legs default to 0 (= free).
//

import Foundation

// MARK: - Envelope

struct OpenRouterModelsDTO: Decodable {
    let data: [OpenRouterModelDTO]
}

// MARK: - Model

struct OpenRouterModelDTO: Decodable {

    let id: String?
    let name: String?
    let description: String?
    let contextLength: Int?
    let architecture: ArchitectureDTO?
    let pricing: PricingDTO?
    let huggingFaceId: String?
    let supportedParameters: [String]?
    let benchmarks: BenchmarksDTO?
    let created: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case contextLength = "context_length"
        case architecture, pricing
        case huggingFaceId = "hugging_face_id"
        case supportedParameters = "supported_parameters"
        case benchmarks, created
    }

    /// Map into the domain model. Returns nil when there is no usable id (the endpoint
    /// occasionally returns tombstone rows).
    func toAIModel() -> AIModel? {
        guard let id = id?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
            return nil
        }

        let provider = id.split(separator: "/").first.map(String.init)?.lowercased() ?? "unknown"
        let name = (name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? id
        let description = description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let context = contextLength ?? 0

        let inputs = architecture?.inputModalities ?? []
        let outputs = architecture?.outputModalities ?? []
        let modality = architecture?.modality ?? ""

        let prompt = pricing?.prompt ?? 0
        let completion = pricing?.completion ?? 0

        let params = supportedParameters ?? []
        let supportsTools = params.contains { $0.lowercased() == "tools" }
        let supportsReasoning = params.contains { $0.lowercased() == "reasoning" }
            || params.contains { $0.lowercased() == "include_reasoning" }

        let aa = benchmarks?.artificialAnalysis

        return AIModel(
            id: id,
            name: name,
            provider: provider,
            description: description,
            contextLength: context,
            inputModalities: inputs,
            outputModalities: outputs,
            modality: modality,
            promptPrice: prompt,
            completionPrice: completion,
            isOpenWeight: (huggingFaceId?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } != nil,
            supportedParameters: params,
            supportsTools: supportsTools,
            supportsReasoning: supportsReasoning,
            intelligenceIndex: aa?.intelligenceIndex,
            codingIndex: aa?.codingIndex,
            agenticIndex: aa?.agenticIndex,
            created: created.map { Date(timeIntervalSince1970: $0) }
        )
    }
}

// MARK: - Nested DTOs

struct ArchitectureDTO: Decodable {
    let modality: String?
    let inputModalities: [String]?
    let outputModalities: [String]?
    let tokenizer: String?

    enum CodingKeys: String, CodingKey {
        case modality
        case inputModalities = "input_modalities"
        case outputModalities = "output_modalities"
        case tokenizer
    }
}

struct PricingDTO: Decodable {
    /// USD per token, as a string. Null/blank → 0 (free).
    let prompt: Double?
    let completion: Double?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        prompt = PricingDTO.parseDouble(try? c.decodeIfPresent(String.self, forKey: .prompt))
        completion = PricingDTO.parseDouble(try? c.decodeIfPresent(String.self, forKey: .completion))
    }

    private enum Keys: String, CodingKey { case prompt, completion }

    /// OpenRouter prices are string-encoded decimals; tolerate a stray number too.
    private static func parseDouble(_ s: String?) -> Double {
        guard let s, let v = Double(s) else { return 0 }
        return v
    }
}

struct BenchmarksDTO: Decodable {
    let artificialAnalysis: ArtificialAnalysisDTO?

    enum CodingKeys: String, CodingKey {
        case artificialAnalysis = "artificial_analysis"
    }
}

struct ArtificialAnalysisDTO: Decodable {
    let intelligenceIndex: Double?
    let codingIndex: Double?
    let agenticIndex: Double?

    enum CodingKeys: String, CodingKey {
        case intelligenceIndex = "intelligence_index"
        case codingIndex = "coding_index"
        case agenticIndex = "agentic_index"
    }
}

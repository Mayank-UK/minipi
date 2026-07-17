//
//  AIModel.swift
//  MiniPi
//
//  Domain models for the AI Models feature. Mirrors the Crypto/Forex/Stocks layer:
//  plain value types with the derived text helpers the UI needs. Powers Home (catalog
//  aggregates), Ranking (sorted by context / price / benchmark), Search (client-side
//  filter) and Compare (side-by-side parameter table).
//
//  Source = OpenRouter's public `/api/v1/models` catalog (no API key). One endpoint
//  returns the whole catalog, so the cache-backed "overview" holds every model plus a
//  summary of counts, and Ranking / Search / Compare are pure client-side operations
//  over it (no per-item network calls). There is no Watchlist tab — saving is not a
//  concept here, so list rows always render a detail chevron.
//
//  Pricing comes from OpenRouter as USD-per-token strings (e.g. "0.000003"). The UI
//  surfaces it as USD-per-million-tokens — the standard readable form for model pricing
//  ("$3.00 /M") — never confused with the stocks/forex/crypto money rules.
//

import Foundation

// MARK: - Model

/// A single AI model from the OpenRouter catalog. `provider` is derived from the `id`
/// prefix before the first `/` (e.g. "openai/gpt-4o" → "openai").
struct AIModel: Identifiable, Equatable {
    let id: String              // OpenRouter id, e.g. "openai/gpt-4o"
    let name: String            // "GPT-4o"
    let provider: String        // "openai" (from id prefix)
    let description: String
    let contextLength: Int      // max context tokens
    let inputModalities: [String]
    let outputModalities: [String]
    let modality: String        // raw "text+image->text"
    let promptPrice: Double     // USD per token
    let completionPrice: Double // USD per token
    let isOpenWeight: Bool      // hugging_face_id present
    let supportedParameters: [String]
    let supportsTools: Bool
    let supportsReasoning: Bool
    let intelligenceIndex: Double?
    let codingIndex: Double?
    let agenticIndex: Double?
    let created: Date?

    /// Free to use (both legs priced at zero).
    var isFree: Bool { promptPrice == 0 && completionPrice == 0 }

    /// Accepts image input.
    var hasVision: Bool {
        inputModalities.contains(where: { $0.lowercased().contains("image") })
    }

    /// Multimodal = more than one input modality, or any non-text modality.
    var isMultimodal: Bool {
        let textOnly = inputModalities.count == 1 && inputModalities.first?.lowercased() == "text"
        return !textOnly
    }

    /// A one-line label under the name: provider + context, e.g. "openai · 128K".
    var subtitle: String {
        "\(provider) · \(contextText)"
    }

    /// Context length as a compact token count: "1.0M", "200K", "32K", "8K".
    var contextText: String {
        Self.formatContext(contextLength)
    }

    /// Prompt price as USD-per-million-tokens, or "Free".
    var promptPriceText: String {
        Self.formatPricePerMillion(promptPrice)
    }

    /// Completion price as USD-per-million-tokens, or "Free".
    var completionPriceText: String {
        Self.formatPricePerMillion(completionPrice)
    }

    /// Short human-readable modality summary, e.g. "Text+Image → Text".
    var modalityLabel: String {
        let i = inputModalities.isEmpty ? "?" : inputModalities.joined(separator: "+")
        let o = outputModalities.isEmpty ? "?" : outputModalities.joined(separator: "+")
        return "\(i) → \(o)"
    }

    // MARK: - Formatting helpers

    /// Compact token-count formatting: 1_048_576 → "1.0M", 200_000 → "200K", 32_000 → "32K".
    static func formatContext(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            return String(format: "%.1fM", Double(tokens) / 1_000_000)
        } else if tokens >= 1_000 {
            return "\(Int((Double(tokens) / 1_000).rounded()))K"
        }
        return "\(tokens)"
    }

    /// USD-per-million-tokens from a per-token price. 0 → "Free".
    static func formatPricePerMillion(_ perToken: Double) -> String {
        if perToken <= 0 { return "Free" }
        let perMillion = perToken * 1_000_000
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = perMillion < 1 ? 2 : 2
        f.minimumFractionDigits = 2
        let value = f.string(from: NSNumber(value: perMillion)) ?? String(format: "%.2f", perMillion)
        return "\(value) /M"
    }
}

// MARK: - Summary (Home aggregates)

/// Aggregate counts over the catalog, shown as StatTiles on Home.
struct AIModelSummary: Equatable {
    let totalModels: Int
    let providerCount: Int
    let openSourceCount: Int
    let freeCount: Int
    let multimodalCount: Int
    let toolCount: Int
    let avgContext: Int

    static let empty = AIModelSummary(
        totalModels: 0, providerCount: 0, openSourceCount: 0,
        freeCount: 0, multimodalCount: 0, toolCount: 0, avgContext: 0
    )

    static func build(from models: [AIModel]) -> AIModelSummary {
        let providers = Set(models.map { $0.provider })
        let totalContext = models.reduce(0) { $0 + $1.contextLength }
        let avg = models.isEmpty ? 0 : totalContext / models.count
        return AIModelSummary(
            totalModels: models.count,
            providerCount: providers.count,
            openSourceCount: models.filter(\.isOpenWeight).count,
            freeCount: models.filter(\.isFree).count,
            multimodalCount: models.filter(\.isMultimodal).count,
            toolCount: models.filter(\.supportsTools).count,
            avgContext: avg
        )
    }
}

// MARK: - Catalog (cache-backed overview)

/// The full OpenRouter catalog + aggregate summary. The cache type for this feature
/// (≈ `CryptoMarketOverview`). Cache-backed fetch; Ranking / Search / Compare derive
/// from `models` client-side.
struct AIModelCatalog: Equatable {
    let summary: AIModelSummary
    let models: [AIModel]

    static let empty = AIModelCatalog(summary: .empty, models: [])
}

// MARK: - Ranking dimension

/// The Ranking tab sort dimension. Models missing the relevant benchmark sort to the
/// bottom so the ranked list always has the scored models first.
enum AIModelRank: String, CaseIterable, Identifiable {
    case overall
    case context
    case cheapest
    case coding
    case agentic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overall: return "Overall"
        case .context: return "Context"
        case .cheapest: return "Cheapest"
        case .coding: return "Coding"
        case .agentic: return "Agentic"
        }
    }

    var icon: String {
        switch self {
        case .overall: return "brain.head.profile.fill"
        case .context: return "text.alignleft"
        case .cheapest: return "dollarsign.circle.fill"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .agentic: return "bolt.fill"
        }
    }

    /// Sort the models for this dimension. Cheapest excludes free models? No — free is
    /// cheapest, so free sorts first (price ascending). Benchmark dims sink nils last.
    func sort(_ models: [AIModel]) -> [AIModel] {
        switch self {
        case .overall:
            return models.sorted { compare($0.intelligenceIndex, $1.intelligenceIndex) }
        case .coding:
            return models.sorted { compare($0.codingIndex, $1.codingIndex) }
        case .agentic:
            return models.sorted { compare($0.agenticIndex, $1.agenticIndex) }
        case .context:
            return models.sorted { $0.contextLength > $1.contextLength }
        case .cheapest:
            // Cheapest by blended price (prompt + completion). Free first.
            return models.sorted { blended($0) < blended($1) }
        }
    }

    /// Descending with nils last.
    private func compare(_ a: Double?, _ b: Double?) -> Bool {
        switch (a, b) {
        case let (a?, b?): return a > b
        case (nil, _?): return false
        case (_?, nil): return true
        case (nil, nil): return false
        }
    }

    private func blended(_ m: AIModel) -> Double { m.promptPrice + m.completionPrice }
}

// MARK: - Search filter

/// Toggleable filters on the Search tab. Client-side over the cached catalog.
enum AIModelFilter: String, CaseIterable, Identifiable {
    case openSource
    case free
    case multimodal
    case vision
    case tools

    var id: String { rawValue }

    var title: String {
        switch self {
        case .openSource: return "Open Source"
        case .free: return "Free"
        case .multimodal: return "Multimodal"
        case .vision: return "Vision"
        case .tools: return "Tools"
        }
    }

    var icon: String {
        switch self {
        case .openSource: return "doc.text.fill"
        case .free: return "gift.fill"
        case .multimodal: return "square.stack.3d.up.fill"
        case .vision: return "eye.fill"
        case .tools: return "wrench.and.screwdriver.fill"
        }
    }

    func matches(_ model: AIModel) -> Bool {
        switch self {
        case .openSource: return model.isOpenWeight
        case .free: return model.isFree
        case .multimodal: return model.isMultimodal
        case .vision: return model.hasVision
        case .tools: return model.supportsTools
        }
    }
}

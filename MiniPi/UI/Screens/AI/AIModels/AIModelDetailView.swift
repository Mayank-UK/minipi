//
//  AIModelDetailView.swift
//
//  Detail sheet for a single AI model: provider header, pricing + context StatTiles,
//  modality + supported-feature badges, and benchmark indices. The catalog already
//  carries every model's full data, so this view is instant (no sub-fetch). Presented as
//  a `.sheet` from AIModelsView. Feature-local (single consumer), like CryptoDetailView.
//

import SwiftUI

struct AIModelDetailView: View {
    let model: AIModel
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) private var dismiss

    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        NavigationStack {
            ZStack {
                cs.space.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Sizes.md) {
                        header
                        statsGrid
                        featuresCard
                        if hasBenchmarks { benchmarksCard }
                        if !model.description.isEmpty { descriptionCard }
                    }
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.bottom, DesignSystem.Sizes.xxl)
                }
            }
            .navigationTitle("Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(cs.space, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(cs.orbitPrimary)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.xs) {
            HStack(alignment: .top, spacing: DesignSystem.Sizes.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Sizes.sm)
                        .fill(cs.orbitPrimary.opacity(0.16))
                    Image(systemName: "cpu")
                        .font(.system(size: DesignSystem.Sizes.iconMd, weight: .bold))
                        .foregroundStyle(cs.orbitPrimary)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(designSystem.types.titleLarge)
                        .foregroundStyle(cs.onSpace)
                    Text(model.id)
                        .font(designSystem.types.bodyMedium)
                        .foregroundStyle(cs.onSpace.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer()
            }

            HStack(spacing: DesignSystem.Sizes.xs) {
                badge(model.contextText, icon: "text.alignleft", color: cs.orbitPrimary)
                if model.isOpenWeight { badge("Open Source", icon: "doc.text.fill", color: cs.distanceSafe) }
                if model.isFree { badge("Free", icon: "gift.fill", color: cs.orbitAccent) }
                if model.hasVision { badge("Vision", icon: "eye.fill", color: cs.orbitPrimary) }
                if model.supportsTools { badge("Tools", icon: "wrench.and.screwdriver.fill", color: cs.orbitPrimary) }
            }
            .padding(.top, DesignSystem.Sizes.xs)
        }
        .padding(DesignSystem.Sizes.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cs.spaceSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
        .modifier(designSystem.shadow(for: .neoCard))
    }

    // MARK: - Stat tiles

    private var statsGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Sizes.md), count: 2)
        return LazyVGrid(columns: cols, spacing: DesignSystem.Sizes.md) {
            StatTile(title: "Context", value: model.contextText, icon: "text.alignleft", accent: cs.orbitPrimary)
            StatTile(title: "Prompt", value: model.promptPriceText, icon: "arrow.down.circle", accent: cs.orbitAccent)
            StatTile(title: "Completion", value: model.completionPriceText, icon: "arrow.up.circle", accent: cs.orbitPrimary)
            StatTile(title: "Provider", value: model.provider, icon: "building.2", accent: cs.orbitAccent)
        }
    }

    // MARK: - Features

    private var featuresCard: some View {
        card(title: "Capabilities") {
            VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
                capabilityRow("Modalities", model.modalityLabel)
                capabilityRow("Tool Use", model.supportsTools ? "Supported" : "Not supported")
                capabilityRow("Reasoning", model.supportsReasoning ? "Supported" : "Not supported")
                capabilityRow("Input", model.inputModalities.joined(separator: ", "))
                capabilityRow("Output", model.outputModalities.joined(separator: ", "))
            }
        }
    }

    private var hasBenchmarks: Bool {
        [model.intelligenceIndex, model.codingIndex, model.agenticIndex].contains { $0 != nil }
    }

    private var benchmarksCard: some View {
        card(title: "Benchmarks (Artificial Analysis)") {
            VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
                if let v = model.intelligenceIndex { benchmarkRow("Intelligence", v, color: cs.orbitPrimary) }
                if let v = model.codingIndex { benchmarkRow("Coding", v, color: cs.distanceSafe) }
                if let v = model.agenticIndex { benchmarkRow("Agentic", v, color: cs.orbitAccent) }
            }
        }
    }

    private var descriptionCard: some View {
        card(title: "About") {
            Text(model.description)
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.8))
        }
    }

    // MARK: - Row helpers

    private func capabilityRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(designSystem.types.labelMedium)
                .foregroundStyle(cs.onSpace.opacity(0.6))
                .frame(width: 96, alignment: .leading)
            Text(value)
                .font(designSystem.types.labelLarge)
                .foregroundStyle(cs.onSpace)
            Spacer()
        }
    }

    private func benchmarkRow(_ label: String, _ value: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .font(designSystem.types.labelMedium)
                .foregroundStyle(cs.onSpace.opacity(0.6))
            Spacer()
            Text(String(format: "%.1f", value))
                .font(designSystem.types.titleSmall)
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }

    private func badge(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(designSystem.types.labelSmall)
        }
        .foregroundStyle(color)
        .padding(.horizontal, DesignSystem.Sizes.xs + 2)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text(title)
                .font(designSystem.types.titleSmall)
                .foregroundStyle(cs.onSpace)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Sizes.md)
        .background(cs.spaceSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
        .modifier(designSystem.shadow(for: .neoCard))
    }
}

//
//  AIModelsCompareTab.swift
//
//  The Compare tab: pick 2–4 models and compare them side by side on the parameters that
//  matter — context, pricing, open-source, modalities, tools/reasoning support and the
//  benchmark indices. Built as a horizontal scroll of per-model cards (each card shows
//  the same rows, so the eye scans across columns) plus an "+ Add model" card when there
//  is room. The picker is a sheet listing the cached catalog (client-side search).
//
//  Everything is client-side over the cached catalog — no per-item network calls.
//

import SwiftUI

struct AIModelsCompareTab: View {
    @ObservedObject var viewModel: AIModelsViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            if viewModel.catalog == nil && viewModel.isLoading {
                ProgressView().tint(cs.orbitPrimary)
            } else if viewModel.compareSelection.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .sheet(isPresented: $viewModel.showComparePicker) {
            ComparePickerSheet(viewModel: viewModel)
        }
        .task {
            if viewModel.catalog == nil && viewModel.currentFailure == nil {
                await viewModel.bootstrap()
            }
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Sizes.md) {
                Text("Comparing \(viewModel.compareSelection.count) of \(viewModel.compareLimit)")
                    .font(designSystem.types.bodyMedium)
                    .foregroundStyle(cs.onSpace.opacity(0.6))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: DesignSystem.Sizes.sm) {
                        ForEach(viewModel.compareSelection) { model in
                            CompareCard(model: model,
                                        cs: cs,
                                        types: designSystem.types) {
                                viewModel.removeFromCompare(model)
                            }
                        }
                        if viewModel.canAddToCompare {
                            addCard
                        }
                    }
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.bottom, DesignSystem.Sizes.xxl)
                }
            }
            .padding(.top, DesignSystem.Sizes.md)
        }
    }

    private var addCard: some View {
        Button {
            viewModel.showComparePicker = true
        } label: {
            VStack(spacing: DesignSystem.Sizes.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: DesignSystem.Sizes.iconLg))
                    .foregroundStyle(cs.orbitPrimary)
                Text("Add model")
                    .font(designSystem.types.labelLarge)
                    .foregroundStyle(cs.orbitPrimary)
            }
            .frame(width: 220, height: 360)
            .background(cs.spaceSurface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius)
                    .stroke(cs.orbitPrimary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6]))
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "rectangle.split.3x1")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text("Compare models side by side")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            Text("Pick up to \(viewModel.compareLimit) models to compare their specs.")
                .font(designSystem.types.labelSmall)
                .foregroundStyle(cs.onSpace.opacity(0.4))
                .multilineTextAlignment(.center)
            Button {
                viewModel.showComparePicker = true
            } label: {
                Label("Add a model", systemImage: "plus")
                    .font(designSystem.types.labelLarge)
                    .foregroundStyle(cs.orbitPrimary)
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.vertical, DesignSystem.Sizes.sm)
                    .background(cs.orbitPrimary.opacity(0.12))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, DesignSystem.Sizes.sm)
        }
        .padding(.horizontal, DesignSystem.Sizes.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Compare card (one column)

/// A single model's comparison column: name + remove, then the same set of rows so values
/// line up across cards. Feature-local to Compare (single consumer).
private struct CompareCard: View {
    let model: AIModel
    let cs: ColorScheme
    let types: FontScheme
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.name)
                        .font(types.titleSmall)
                        .foregroundStyle(cs.onSpace)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(model.provider)
                        .font(types.labelMedium)
                        .foregroundStyle(cs.onSpace.opacity(0.6))
                }
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: DesignSystem.Sizes.iconMd))
                        .foregroundStyle(cs.onSpace.opacity(0.4))
                }
                .buttonStyle(.plain)
            }

            Divider().background(cs.onSpace.opacity(0.1))

            row("Context", model.contextText)
            row("Prompt", model.promptPriceText)
            row("Completion", model.completionPriceText)
            row("Open Source", model.isOpenWeight ? "Yes" : "No")
            row("Modalities", model.modalityLabel)
            row("Tools", model.supportsTools ? "Yes" : "No")
            row("Reasoning", model.supportsReasoning ? "Yes" : "No")
            row("Intelligence", optional(model.intelligenceIndex))
            row("Coding", optional(model.codingIndex))
            row("Agentic", optional(model.agenticIndex))
        }
        .frame(width: 220, alignment: .leading)
        .padding(DesignSystem.Sizes.md)
        .background(cs.spaceSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
        .modifier(ShadowProxy(cs: cs))
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(types.labelSmall)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            Text(value)
                .font(types.labelLarge)
                .foregroundStyle(cs.onSpace)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func optional(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f", value)
    }
}

// MARK: - Picker sheet

/// Lists catalog models (client-side search), toggling them into the compare selection.
private struct ComparePickerSheet: View {
    @ObservedObject var viewModel: AIModelsViewModel
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) private var dismiss
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        NavigationStack {
            ZStack {
                cs.space.ignoresSafeArea()
                VStack(spacing: DesignSystem.Sizes.md) {
                    searchBar
                        .padding(.horizontal, DesignSystem.Sizes.md)
                        .padding(.top, DesignSystem.Sizes.md)

                    if viewModel.compareCandidates.isEmpty {
                        Spacer()
                        Text("No models match")
                            .font(designSystem.types.bodyMedium)
                            .foregroundStyle(cs.onSpace.opacity(0.5))
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: DesignSystem.Sizes.sm) {
                                ForEach(viewModel.compareCandidates) { model in
                                    AIModelRow(model: model,
                                               compareState: viewModel.canAddToCompare ? .available : nil) {
                                        viewModel.toggleCompare(model)
                                    }
                                }
                            }
                            .padding(.horizontal, DesignSystem.Sizes.md)
                            .padding(.bottom, DesignSystem.Sizes.xxl)
                        }
                    }
                }
            }
            .navigationTitle("Add to Compare")
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

    private var searchBar: some View {
        HStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(cs.onSpace.opacity(0.5))
            TextField("Search models…", text: $viewModel.compareQuery)
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !viewModel.compareQuery.isEmpty {
                Button {
                    viewModel.compareQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(cs.onSpace.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Sizes.md)
        .padding(.vertical, DesignSystem.Sizes.sm)
        .background(cs.spaceSurface)
        .clipShape(Capsule())
    }
}

/// Bridges the card shadow without re-reading the `DesignSystem` env off a throwaway
/// instance — same rule as the stocks/forex/crypto `ShadowProxy`.
private struct ShadowProxy: ViewModifier {
    let cs: ColorScheme
    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(0.45), radius: 10, x: 0, y: 6)
    }
}

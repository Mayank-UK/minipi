//
//  AIModelsHomeTab.swift
//  MiniPi
//
//  The Home tab of the AI Models screen set. Shows aggregate StatTiles over the cached
//  catalog (total models, providers, open-source, free, multimodal, average context) plus
//  a "Top by intelligence" highlight list. Loading / error / refresh states follow the
//  same severity rules as the crypto/forex home tab (critical + no cache → full ErrorView;
//  warning with cached data → non-blocking snackbar). Live data source badge = OpenRouter.
//

import SwiftUI

struct AIModelsHomeTab: View {
    @ObservedObject var viewModel: AIModelsViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            if isLoadingCritical {
                ErrorView(failure: viewModel.currentFailure!,
                          onRetry: { Task { await viewModel.loadCatalog(force: true) } })
            } else if viewModel.isLoading && viewModel.catalog == nil {
                ProgressView().tint(cs.orbitPrimary)
            } else if let catalog = viewModel.catalog {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Sizes.md) {
                        header
                        LiveDataBadge(source: "OpenRouter")
                            .frame(maxWidth: .infinity, alignment: .leading)

                        statsGrid(catalog.summary)

                        if catalog.models.isEmpty {
                            emptyNote("No models available right now")
                        } else {
                            highlights(catalog.models)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.bottom, DesignSystem.Sizes.xxl)
                }
                .refreshable { await viewModel.loadCatalog(force: true) }
            } else {
                emptyState
            }

            if showsSnackbar, let failure = viewModel.currentFailure {
                ErrorSnackbar(failure: failure, onDismiss: { viewModel.clearError() })
                    .padding(.bottom, 56)
            }
        }
        .task {
            if viewModel.catalog == nil && viewModel.currentFailure == nil {
                await viewModel.bootstrap()
            }
        }
    }

    // MARK: - State helpers

    private var isLoadingCritical: Bool {
        guard let failure = viewModel.currentFailure else { return false }
        return failure.severity == .critical && viewModel.catalog == nil
    }

    private var showsSnackbar: Bool {
        guard let failure = viewModel.currentFailure else { return false }
        return failure.severity != .critical || viewModel.catalog != nil
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("AI Models")
                .font(designSystem.types.headlineSmall)
                .foregroundStyle(cs.onSpace)
            Text("Browse \(viewModel.catalog?.summary.totalModels ?? 0) models across providers")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.6))
        }
    }

    // MARK: - Stats grid

    private func statsGrid(_ summary: AIModelSummary) -> some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Sizes.sm), count: 3)
        return LazyVGrid(columns: cols, spacing: DesignSystem.Sizes.sm) {
            StatTile(title: "Models", value: "\(summary.totalModels)", icon: "cpu",
                     onTap: { viewModel.selectedTab = .ranking })
            StatTile(title: "Providers", value: "\(summary.providerCount)", icon: "building.2",
                     onTap: { viewModel.selectedTab = .search })
            StatTile(title: "Open Source", value: "\(summary.openSourceCount)", icon: "doc.text.fill", accent: cs.distanceSafe,
                     onTap: { viewModel.openFilterFromHome(.openSource) })
            StatTile(title: "Free", value: "\(summary.freeCount)", icon: "gift.fill", accent: cs.orbitAccent,
                     onTap: { viewModel.openFilterFromHome(.free) })
            StatTile(title: "Multimodal", value: "\(summary.multimodalCount)", icon: "square.stack.3d.up.fill",
                     onTap: { viewModel.openFilterFromHome(.multimodal) })
            StatTile(title: "Avg Context", value: AIModel.formatContext(summary.avgContext), icon: "text.alignleft",
                     onTap: { viewModel.selectedTab = .ranking })
        }
    }

    // MARK: - Highlights

    private func highlights(_ models: [AIModel]) -> some View {
        let top = Array(AIModelRank.overall.sort(models).prefix(5).filter { $0.intelligenceIndex != nil })
        return VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text("Top by Intelligence")
                .font(designSystem.types.titleMedium)
                .foregroundStyle(cs.onSpace)

            if top.isEmpty {
                emptyNote("Benchmark data unavailable")
            } else {
                VStack(spacing: DesignSystem.Sizes.sm) {
                    ForEach(top) { model in
                        AIModelRow(model: model) {
                            viewModel.openDetail(model)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func emptyNote(_ text: String) -> some View {
        Text(text)
            .font(designSystem.types.bodyMedium)
            .foregroundStyle(cs.onSpace.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Sizes.sm)
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "cpu")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text("No model data")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            Button("Retry") { Task { await viewModel.loadCatalog(force: true) } }
                .font(designSystem.types.labelLarge)
                .foregroundStyle(cs.orbitPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

//
//  AIModelsRankingTab.swift
//  MiniPi
//
//  The Ranking tab: a chip bar of sort dimensions (Overall / Context / Cheapest / Coding
//  / Agentic) over the cached catalog, then the ranked model rows. Sort is client-side
//  (AIModelRank.sort); the list is capped for scroll performance over a 300+ catalog.
//  Tap a row to open the detail sheet. Rows show the chevron (no save star).
//

import SwiftUI

struct AIModelsRankingTab: View {
    @ObservedObject var viewModel: AIModelsViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            if viewModel.isLoading && viewModel.catalog == nil {
                ProgressView().tint(cs.orbitPrimary)
            } else if let catalog = viewModel.catalog {
                VStack(spacing: DesignSystem.Sizes.md) {
                    rankBar
                    if viewModel.rankedModels.isEmpty {
                        emptyNote("No models to rank")
                    } else {
                        list(catalog: catalog)
                    }
                }
                .padding(.horizontal, DesignSystem.Sizes.md)
                .padding(.top, DesignSystem.Sizes.md)
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

    private var showsSnackbar: Bool {
        guard let failure = viewModel.currentFailure else { return false }
        return failure.severity != .critical || viewModel.catalog != nil
    }

    // MARK: - Rank chip bar

    private var rankBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Sizes.sm) {
                ForEach(AIModelRank.allCases) { rank in
                    Chip(
                        label: rank.title,
                        icon: rank.icon,
                        isSelected: viewModel.selectedRank == rank,
                        action: { viewModel.selectedRank = rank }
                    )
                }
            }
        }
    }

    // MARK: - List

    private func list(catalog: AIModelCatalog) -> some View {
        let ranked = viewModel.rankedModels
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
                Text("\(catalog.summary.totalModels) models · showing top \(ranked.count)")
                    .font(designSystem.types.labelMedium)
                    .foregroundStyle(cs.onSpace.opacity(0.5))

                ForEach(Array(ranked.enumerated()), id: \.element.id) { index, model in
                    AIModelRow(model: model) {
                        viewModel.openDetail(model)
                    }
                }
            }
            .padding(.bottom, DesignSystem.Sizes.xxl)
        }
    }

    // MARK: - Helpers

    private func emptyNote(_ text: String) -> some View {
        Text(text)
            .font(designSystem.types.bodyMedium)
            .foregroundStyle(cs.onSpace.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, DesignSystem.Sizes.xl)
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "list.number")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text("No rankings yet")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

//
//  AIModelsSearchTab.swift
//
//  The Search tab: client-side text search over the cached catalog, with toggleable
//  filter chips (Open Source / Free / Multimodal / Vision / Tools). Filters and text
//  apply automatically on change — no "Apply" button (matches the app's search pattern).
//  Since the catalog is in-memory, the filter is synchronous (no debounce needed). Tap a
//  result to open the detail sheet. Mirrors the crypto search tab structure.
//

import SwiftUI

struct AIModelsSearchTab: View {
    @ObservedObject var viewModel: AIModelsViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            VStack(spacing: DesignSystem.Sizes.md) {
                searchBar
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.top, DesignSystem.Sizes.md)

                filterBar
                    .padding(.horizontal, DesignSystem.Sizes.md)

                if viewModel.catalog == nil && viewModel.isLoading {
                    Spacer()
                    ProgressView().tint(cs.orbitPrimary)
                    Spacer()
                } else if viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
                            && viewModel.searchFilters.isEmpty {
                    prompt
                } else if viewModel.searchResults.isEmpty {
                    emptyResults
                } else {
                    resultsList
                }
            }

            if let failure = viewModel.currentFailure, viewModel.catalog == nil {
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

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(cs.onSpace.opacity(0.5))
            TextField("Search models, e.g. gpt-4o…", text: $viewModel.searchQuery)
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
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

    // MARK: - Filter chips

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Sizes.sm) {
                ForEach(AIModelFilter.allCases) { filter in
                    Chip(
                        label: filter.title,
                        icon: filter.icon,
                        isSelected: viewModel.searchFilters.contains(filter),
                        action: { viewModel.toggleFilter(filter) }
                    )
                }
            }
        }
    }

    // MARK: - Results

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Sizes.sm) {
                Text("\(viewModel.searchResults.count) matches")
                    .font(designSystem.types.labelMedium)
                    .foregroundStyle(cs.onSpace.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(viewModel.searchResults) { model in
                    AIModelRow(model: model) {
                        viewModel.openDetail(model)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Sizes.md)
            .padding(.bottom, DesignSystem.Sizes.xxl)
        }
    }

    private var prompt: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text("Search across \(viewModel.catalog?.summary.totalModels ?? 0) models")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            Text("Type a name or tap a filter")
                .font(designSystem.types.labelSmall)
                .foregroundStyle(cs.onSpace.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyResults: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.onSpace.opacity(0.4))
            Text("No models match")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

//
//  IndicatorsSearchTab.swift
//  MiniPi
//
//  The Search tab: client-side text search over the curated indicators, with toggleable
//  category filter chips (Learning Outcomes / Access / Resources). Filters and text apply
//  automatically on change — no "Apply" button (matches the app's search pattern). Since
//  the catalog is in-memory, the filter is synchronous (no debounce needed). Tap a result
//  to focus that indicator on the Ranking tab. Mirrors the ai-models search tab structure.
//
//  The indicator row is single-file (only this consumer), so it lives here as a private
//  view rather than as a global component — per the convention.
//

import SwiftUI

struct IndicatorsSearchTab: View {
    @ObservedObject var viewModel: IndicatorsViewModel
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
            TextField("Search indicators, e.g. literacy…", text: $viewModel.searchQuery)
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
                ForEach(IndicatorFilter.allCases) { filter in
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
                Text("\(viewModel.searchResults.count) indicators")
                    .font(designSystem.types.labelMedium)
                    .foregroundStyle(cs.onSpace.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(viewModel.searchResults) { indicator in
                    IndicatorRow(indicator: indicator) {
                        viewModel.focusIndicator(indicator)
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
            Text("Search across \(viewModel.catalog?.indicators.count ?? 0) indicators")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            Text("Type a name or tap a category")
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
            Text("No indicators match")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Indicator row (single-file, private)

/// A list row for a curated indicator — single consumer, so private to this file. Shows
/// the name, category subtitle, code, and a chevron; tap to focus on the Ranking tab.
private struct IndicatorRow: View {
    let indicator: Indicator
    var onTap: () -> Void

    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Sizes.md) {
                ZStack {
                    Circle()
                        .fill(cs.orbitPrimary.opacity(0.16))
                    Image(systemName: indicator.category.icon)
                        .font(.system(size: DesignSystem.Sizes.iconSm, weight: .bold))
                        .foregroundStyle(cs.orbitPrimary)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(indicator.name)
                        .font(designSystem.types.titleSmall)
                        .foregroundStyle(cs.onSpace)
                        .lineLimit(1)
                    Text(indicator.subtitle)
                        .font(designSystem.types.labelMedium)
                        .foregroundStyle(cs.onSpace.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                Text(indicator.id)
                    .font(designSystem.types.labelSmall)
                    .foregroundStyle(cs.onSpace.opacity(0.4))
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: DesignSystem.Sizes.iconSm, weight: .semibold))
                    .foregroundStyle(cs.onSpace.opacity(0.3))
                    .padding(.leading, DesignSystem.Sizes.sm)
            }
            .padding(DesignSystem.Sizes.md)
            .background(cs.spaceSurface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
            .modifier(designSystem.shadow(for: .neoCard))
        }
        .buttonStyle(.plain)
    }
}

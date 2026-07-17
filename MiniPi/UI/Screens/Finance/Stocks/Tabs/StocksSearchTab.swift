//
//  StocksSearchTab.swift
//  MiniPi
//
//  The Search tab: server-backed instrument autocomplete (Finnhub `/search`), quoted
//  so each result shows a live price. Filters apply automatically on change — no
//  "Apply" button — debounced in the VM (350 ms) via `scheduleSearch`. Tap a result
//  to open the detail sheet. Mirrors the Weather home city-search pattern.
//

import SwiftUI

struct StocksSearchTab: View {
    @ObservedObject var viewModel: StocksViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            VStack(spacing: DesignSystem.Sizes.md) {
                searchBar
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.top, DesignSystem.Sizes.md)

                if viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                    prompt
                } else if viewModel.isSearching && viewModel.searchResults.isEmpty {
                    Spacer()
                    ProgressView().tint(cs.orbitPrimary)
                    Spacer()
                } else if viewModel.searchResults.isEmpty {
                    emptyResults
                } else {
                    resultsList
                }
            }

            if let failure = viewModel.searchFailure {
                ErrorSnackbar(failure: failure, onDismiss: { viewModel.clearSearchError() })
                    .padding(.bottom, 56)
            }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(cs.onSpace.opacity(0.5))
            TextField("Search stocks, ETFs, indices…", text: $viewModel.searchQuery)
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .onChange(of: viewModel.searchQuery) { _ in
                    viewModel.scheduleSearch()
                }
                .submitLabel(.search)
                .onSubmit { viewModel.scheduleSearch(immediate: true) }
            if viewModel.isSearching {
                ProgressView().tint(cs.orbitPrimary).scaleEffect(0.8)
            } else if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                    viewModel.searchResults = []
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

    // MARK: - Results

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Sizes.sm) {
                ForEach(viewModel.searchResults) { item in
                    StocksRow(
                        item: item,
                        currency: item.symbol.currency,
                        onTap: { viewModel.openDetail(item.symbol) }
                    )
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
            Text("Search for any instrument")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyResults: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.onSpace.opacity(0.4))
            Text("No results for “\(viewModel.searchQuery)”")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            if let failure = viewModel.searchFailure {
                Text(failure.message)
                    .font(designSystem.types.labelSmall)
                    .foregroundStyle(cs.distanceDanger)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

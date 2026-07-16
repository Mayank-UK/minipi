//
//  AsteroidSearchTab.swift
//  MiniPi
//
//  The Search tab (Module A §A.10, screen 4): a name/designation field, filter
//  chips (hazardous, min diameter, sort), and an instant results list over the
//  loaded dataset. A numeric id also hits NASA `neo/{id}` for that specific body.
//

import SwiftUI

struct AsteroidSearchTab: View {
    @ObservedObject var viewModel: AsteroidViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    @State private var detailAsteroid: Asteroid?

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            VStack(spacing: DesignSystem.Sizes.md) {
                searchBar
                filterChipBar
                if viewModel.isLookingUp {
                    HStack(spacing: DesignSystem.Sizes.xs) {
                        ProgressView().tint(cs.orbitPrimary).scaleEffect(0.8)
                        Text("Looking up id \(viewModel.searchQuery)…")
                            .font(designSystem.types.labelMedium)
                            .foregroundStyle(cs.onSpace.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.Sizes.md)
                }
                content
            }
            .padding(.top, DesignSystem.Sizes.sm)
            .padding(.bottom, DesignSystem.Sizes.md)
        }
        .task {
            if viewModel.allAsteroids.isEmpty {
                await viewModel.loadAsteroids()
                await viewModel.loadOrbitalAsteroids()
            }
        }
        .sheet(item: $detailAsteroid) { asteroid in
            AsteroidDetailSheet(
                asteroid: asteroid,
                isFavorite: viewModel.isFavorite(asteroid),
                onToggleFavorite: { viewModel.toggleFavorite(asteroid) }
            )
        }
    }

    // MARK: - Subviews

    /// Filter chips: hazardous toggle, min-diameter picker, sort picker. Built on
    /// the shared `Chip`/`ChipLabel` primitives; the composition is asteroid-specific.
    private var filterChipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Sizes.sm) {
                Chip(
                    label: "Hazardous",
                    icon: "exclamationmark.triangle.fill",
                    isSelected: viewModel.searchFilters.hazardousOnly
                ) { viewModel.searchFilters.hazardousOnly.toggle() }

                Menu {
                    Picker("Minimum size", selection: $viewModel.searchFilters.minDiameterBucket) {
                        ForEach(AsteroidMinDiameter.allCases) { bucket in
                            Text(bucket.label).tag(bucket)
                        }
                    }
                } label: {
                    ChipLabel(
                        label: viewModel.searchFilters.minDiameterBucket.label,
                        icon: "circle.dashed",
                        isSelected: viewModel.searchFilters.minDiameterBucket != .any
                    )
                }
                .menuStyle(.borderlessButton)

                Menu {
                    Picker("Sort by", selection: $viewModel.searchFilters.sortBy) {
                        ForEach(AsteroidSort.allCases) { sort in
                            Label(sort.label, systemImage: sort.icon).tag(sort)
                        }
                    }
                } label: {
                    ChipLabel(
                        label: viewModel.searchFilters.sortBy.label,
                        icon: "arrow.up.arrow.down",
                        isSelected: false
                    )
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal, DesignSystem.Sizes.md)
        }
    }

    private var searchBar: some View {
        HStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(cs.onSpace.opacity(0.5))
            TextField("Name, designation or NASA id", text: $viewModel.searchQuery)
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onChange(of: viewModel.searchQuery) { _, _ in
                    viewModel.runLookupIfNeeded()
                }
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                    viewModel.runLookupIfNeeded()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(cs.onSpace.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Sizes.md)
        .padding(.vertical, DesignSystem.Sizes.sm + DesignSystem.Sizes.xs)
        .background(cs.spaceSurface)
        .clipShape(Capsule())
        .padding(.horizontal, DesignSystem.Sizes.md)
    }

    @ViewBuilder
    private var content: some View {
        let results = viewModel.searchResults
        if viewModel.isLoading || viewModel.isLoadingOrbital, viewModel.allAsteroids.isEmpty {
            Spacer()
            ProgressView().tint(cs.orbitPrimary)
            Spacer()
        } else if results.isEmpty {
            Spacer()
            emptyState
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: DesignSystem.Sizes.sm) {
                    Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                        .font(designSystem.types.labelMedium)
                        .foregroundStyle(cs.onSpace.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(results) { asteroid in
                        AsteroidSearchRow(
                            asteroid: asteroid,
                            isFavorite: viewModel.isFavorite(asteroid),
                            onToggleFavorite: { viewModel.toggleFavorite(asteroid) },
                            onTap: { detailAsteroid = asteroid }
                        )
                    }
                }
                .padding(.horizontal, DesignSystem.Sizes.md)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: viewModel.searchQuery.isEmpty ? "magnifyingglass" : "questionmark.circle")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text(viewModel.searchQuery.isEmpty ? "Search NASA asteroids" : "No matches")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            if !viewModel.searchQuery.isEmpty {
                Text("Try a name like “Apophis” or a NASA id like 99942.")
                    .font(designSystem.types.bodySmall)
                    .foregroundStyle(cs.onSpace.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, DesignSystem.Sizes.lg)
    }
}

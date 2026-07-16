//
//  EarthquakeSearchTab.swift
//  MiniPi
//
//  The Search tab: a place / id field, filter chips (min magnitude, depth, time
//  window, sort) backed by the USGS FDSNWS query endpoint, and a results list.
//  A USGS event id also hits `detail/{id}` for that specific event. Mirrors the
//  structure of AsteroidSearchTab (chips built on the shared Chip/ChipLabel).
//

import SwiftUI

struct EarthquakeSearchTab: View {
    @ObservedObject var viewModel: EarthquakeViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    @State private var detailEarthquake: Earthquake?

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            VStack(spacing: DesignSystem.Sizes.md) {
                searchBar
                filterChipBar
                if viewModel.isLookingUp {
                    HStack(spacing: DesignSystem.Sizes.xs) {
                        ProgressView().tint(cs.orbitPrimary).scaleEffect(0.8)
                        Text("Looking up event \(viewModel.placeFilter)…")
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
            if !viewModel.hasSearched {
                viewModel.scheduleSearch(immediate: true)
            }
        }
        .onChange(of: viewModel.searchFilters) { _, _ in
            viewModel.scheduleSearch()
        }
        .sheet(item: $detailEarthquake) { quake in
            EarthquakeDetailSheet(
                earthquake: quake,
                isSaved: viewModel.isSaved(quake),
                onToggleSaved: { viewModel.toggleSaved(quake) }
            )
        }
    }

    // MARK: - Subviews

    private var searchBar: some View {
        HStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(cs.onSpace.opacity(0.5))
            TextField("Place or USGS event id", text: $viewModel.placeFilter)
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onChange(of: viewModel.placeFilter) { _, _ in
                    viewModel.runLookupIfNeeded()
                }
            if !viewModel.placeFilter.isEmpty {
                Button {
                    viewModel.placeFilter = ""
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

    /// Filter chips: min magnitude, depth, time window, sort — built on the shared
    /// Chip primitives; the composition is earthquake-specific.
    private var filterChipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Sizes.sm) {
                Menu {
                    Picker("Min magnitude", selection: $viewModel.searchFilters.minMagnitude) {
                        ForEach(EarthquakeMinMagnitude.allCases) { bucket in
                            Text(bucket.label).tag(bucket)
                        }
                    }
                } label: {
                    ChipLabel(label: "Mag: \(viewModel.searchFilters.minMagnitude.label)",
                              icon: "waveform",
                              isSelected: viewModel.searchFilters.minMagnitude != .any)
                }
                .menuStyle(.borderlessButton)

                Menu {
                    Picker("Depth", selection: $viewModel.searchFilters.depth) {
                        ForEach(EarthquakeDepthBucket.allCases) { bucket in
                            Text(bucket.label).tag(bucket)
                        }
                    }
                } label: {
                    ChipLabel(label: viewModel.searchFilters.depth.label,
                              icon: "arrow.down.right",
                              isSelected: viewModel.searchFilters.depth != .any)
                }
                .menuStyle(.borderlessButton)

                Menu {
                    Picker("Time window", selection: $viewModel.searchFilters.timeWindow) {
                        ForEach(EarthquakeTimeWindow.allCases) { window in
                            Text(window.label).tag(window)
                        }
                    }
                } label: {
                    ChipLabel(label: viewModel.searchFilters.timeWindow.label,
                              icon: "clock",
                              isSelected: true)
                }
                .menuStyle(.borderlessButton)

                Menu {
                    Picker("Sort by", selection: $viewModel.searchFilters.orderBy) {
                        ForEach(EarthquakeOrder.allCases, id: \.self) { order in
                            Text(order.label).tag(order)
                        }
                    }
                } label: {
                    ChipLabel(label: viewModel.searchFilters.orderBy.label,
                              icon: "arrow.up.arrow.down",
                              isSelected: false)
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal, DesignSystem.Sizes.md)
        }
    }

    @ViewBuilder
    private var content: some View {
        let results = viewModel.filteredSearchResults
        if viewModel.isSearching, viewModel.searchResults.isEmpty {
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
                    ForEach(results) { quake in
                        EarthquakeRow(
                            earthquake: quake,
                            onTap: { detailEarthquake = quake }
                        )
                    }
                }
                .padding(.horizontal, DesignSystem.Sizes.md)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: viewModel.placeFilter.isEmpty ? "magnifyingglass" : "questionmark.circle")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text(viewModel.placeFilter.isEmpty ? "No earthquakes found" : "No matches")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            if !viewModel.placeFilter.isEmpty {
                Text("Try a place like “Japan” or a USGS id like us7000me69.")
                    .font(designSystem.types.bodySmall)
                    .foregroundStyle(cs.onSpace.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, DesignSystem.Sizes.lg)
    }
}

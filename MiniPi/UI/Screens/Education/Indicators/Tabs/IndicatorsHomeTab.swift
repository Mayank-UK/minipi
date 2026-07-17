//
//  IndicatorsHomeTab.swift
//  MiniPi
//
//  The Home tab of the Indicators screen set. Shows aggregate StatTiles over the cached
//  catalog (countries, indicators, latest year, data points), key-highlight StatTiles per
//  curated indicator (global average), and a "Top Performers" list ranked by the headline
//  indicator. Loading / error / refresh states follow the same severity rules as the
//  ai/crypto home tab (critical + no cache → full ErrorView; warning with cached data →
//  non-blocking snackbar). Live data source badge = World Bank.
//

import SwiftUI

struct IndicatorsHomeTab: View {
    @ObservedObject var viewModel: IndicatorsViewModel
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
                        LiveDataBadge(source: "World Bank")
                            .frame(maxWidth: .infinity, alignment: .leading)

                        statsGrid(catalog.summary)

                        if catalog.indicators.isEmpty {
                            emptyNote("No indicators available right now")
                        } else {
                            highlights(catalog.indicators)
                        }

                        if !topPerformers.isEmpty {
                            performers
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
            Text("Indicators")
                .font(designSystem.types.headlineSmall)
                .foregroundStyle(cs.onSpace)
            Text("Global development statistics at a glance")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.6))
        }
    }

    // MARK: - Stats grid

    private func statsGrid(_ summary: WorldSummary) -> some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Sizes.sm), count: 2)
        return LazyVGrid(columns: cols, spacing: DesignSystem.Sizes.sm) {
            StatTile(title: "Countries", value: "\(summary.countryCount)", icon: "globe",
                     onTap: { viewModel.selectedTab = .ranking })
            StatTile(title: "Indicators", value: "\(summary.indicatorCount)", icon: "chart.bar.fill",
                     onTap: { viewModel.selectedTab = .search })
            StatTile(title: "Latest Year", value: summary.latestYearText, icon: "calendar",
                     onTap: { viewModel.selectedTab = .stats })
            StatTile(title: "Data Points", value: "\(summary.dataPointCount)", icon: "database", accent: cs.orbitAccent,
                     onTap: { viewModel.selectedTab = .stats })
        }
    }

    // MARK: - Key highlights (global average per indicator)

    private func highlights(_ indicators: [Indicator]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text("Key Highlights")
                .font(designSystem.types.titleMedium)
                .foregroundStyle(cs.onSpace)

            let cols = Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Sizes.sm), count: 2)
            LazyVGrid(columns: cols, spacing: DesignSystem.Sizes.sm) {
                ForEach(indicators) { indicator in
                    let avg = viewModel.average(for: indicator.id)
                    StatTile(
                        title: indicator.name,
                        value: indicator.formatValue(avg),
                        icon: indicator.category.icon,
                        accent: cs.orbitPrimary,
                        onTap: { viewModel.focusIndicator(indicator) }
                    )
                }
            }
        }
    }

    // MARK: - Top performers

    private var topPerformers: [(Country, Double)] {
        viewModel.topValues(for: CuratedIndicators.headline, limit: 5)
    }

    private var performers: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text("Top Performers by \(CuratedIndicators.headline.name)")
                .font(designSystem.types.titleMedium)
                .foregroundStyle(cs.onSpace)

            VStack(spacing: DesignSystem.Sizes.sm) {
                ForEach(topPerformers, id: \.0.id) { country, value in
                    CountryRow(country: country, valueText: CuratedIndicators.headline.formatValue(value)) {
                        viewModel.openDetail(country)
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
            Image(systemName: "globe")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text("No indicator data")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            Button("Retry") { Task { await viewModel.loadCatalog(force: true) } }
                .font(designSystem.types.labelLarge)
                .foregroundStyle(cs.orbitPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

//
//  IndicatorsRankingTab.swift
//  MiniPi
//
//  The Ranking tab: a chip bar of indicators over the cached catalog, then the countries
//  ranked by the selected indicator (higherIsBetter aware). Sort is client-side; the list
//  is capped for scroll performance. Tap a country row to open its detail sheet. Rows show
//  the chevron (no save star).
//

import SwiftUI

struct IndicatorsRankingTab: View {
    @ObservedObject var viewModel: IndicatorsViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            if viewModel.isLoading && viewModel.catalog == nil {
                ProgressView().tint(cs.orbitPrimary)
            } else if let catalog = viewModel.catalog {
                VStack(spacing: DesignSystem.Sizes.md) {
                    indicatorBar
                    if viewModel.rankedCountries.isEmpty {
                        emptyNote("No countries have data for this indicator")
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

    // MARK: - Indicator chip bar

    private var indicatorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Sizes.sm) {
                ForEach(catalogIndicators) { indicator in
                    Chip(
                        label: indicator.name,
                        icon: indicator.category.icon,
                        isSelected: viewModel.selectedIndicator.id == indicator.id,
                        action: { viewModel.selectedIndicator = indicator }
                    )
                }
                YearPicker(viewModel: viewModel)
            }
        }
    }

    private var catalogIndicators: [Indicator] {
        viewModel.catalog?.indicators ?? CuratedIndicators.all
    }

    // MARK: - List

    private func list(catalog: WorldDataCatalog) -> some View {
        let ranked = viewModel.rankedCountries
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
                Text("\(ranked.count) countries · ranked by \(viewModel.selectedIndicator.name) · \(viewModel.selectedYear.map { "\($0)" } ?? "latest")")
                    .font(designSystem.types.labelMedium)
                    .foregroundStyle(cs.onSpace.opacity(0.5))

                ForEach(Array(ranked.enumerated()), id: \.element.id) { index, country in
                    let value = viewModel.value(for: country.id, indicatorId: viewModel.selectedIndicator.id)
                    CountryRow(country: country, valueText: viewModel.selectedIndicator.formatValue(value)) {
                        viewModel.openDetail(country)
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

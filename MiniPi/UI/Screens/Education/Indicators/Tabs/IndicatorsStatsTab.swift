//
//  IndicatorsStatsTab.swift
//  MiniPi
//
//  The Stats tab: a Swift Charts bar chart of the top countries for the selected
//  indicator, plus a summary card (countries covered, average, min/max). The indicator is
//  chosen via a chip bar. Everything is client-side over the cached catalog. Mirrors the
//  other features' Stats tabs (Swift Charts — no third-party chart lib).
//

import SwiftUI
import Charts

struct IndicatorsStatsTab: View {
    @ObservedObject var viewModel: IndicatorsViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    private let chartLimit = 10

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            if viewModel.isLoading && viewModel.catalog == nil {
                ProgressView().tint(cs.orbitPrimary)
            } else if let catalog = viewModel.catalog {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Sizes.md) {
                        indicatorBar

                        if chartData.isEmpty {
                            emptyNote("No data to chart for this indicator")
                        } else {
                            summaryCard
                            chartCard
                        }
                    }
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.top, DesignSystem.Sizes.md)
                    .padding(.bottom, DesignSystem.Sizes.xxl)
                }
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
                ForEach(viewModel.catalog?.indicators ?? CuratedIndicators.all) { indicator in
                    Chip(
                        label: indicator.name,
                        icon: indicator.category.icon,
                        isSelected: viewModel.statsIndicator.id == indicator.id,
                        action: { viewModel.statsIndicator = indicator }
                    )
                }
                YearPicker(viewModel: viewModel)
            }
        }
    }

    // MARK: - Data

    private var chartData: [(Country, Double)] {
        viewModel.topValues(for: viewModel.statsIndicator, limit: chartLimit, year: viewModel.selectedYear)
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        let indicator = viewModel.statsIndicator
        let avg = viewModel.average(for: indicator.id, year: viewModel.selectedYear)
        let values = chartData.map(\.1)
        let highest = values.max()
        let lowest = values.min()
        return card(title: indicator.name) {
            LazyVGrid(columns: grid, spacing: DesignSystem.Sizes.sm) {
                statTile("Countries", "\(chartData.count)")
                statTile("Average", indicator.formatValue(avg))
                statTile("Highest", indicator.formatValue(highest))
                statTile("Lowest", indicator.formatValue(lowest))
            }
        }
    }

    private var grid: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Sizes.sm), count: 2)
    }

    private func statTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(designSystem.types.labelSmall)
                .foregroundStyle(cs.onSpace.opacity(0.6))
            Text(value)
                .font(designSystem.types.titleSmall)
                .foregroundStyle(cs.onSpace)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Chart card

    private var chartCard: some View {
        let indicator = viewModel.statsIndicator
        return card(title: "Top \(chartData.count) — \(indicator.name)") {
            Chart {
                ForEach(chartData, id: \.0.id) { country, value in
                    BarMark(
                        x: .value(indicator.format.unitLabel, value),
                        y: .value("Country", country.name)
                    )
                    .foregroundStyle(cs.orbitPrimary)
                    .annotation(position: .trailing) {
                        Text(indicator.formatValue(value))
                            .font(designSystem.types.labelSmall)
                            .foregroundStyle(cs.onSpace.opacity(0.7))
                    }
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(preset: .aligned, position: .leading) { value in
                    AxisValueLabel()
                        .font(designSystem.types.labelSmall)
                        .foregroundStyle(cs.onSpace.opacity(0.7))
                }
            }
            .frame(height: CGFloat(chartData.count) * 44)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text(title)
                .font(designSystem.types.titleSmall)
                .foregroundStyle(cs.onSpace)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Sizes.md)
        .background(cs.spaceSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
        .modifier(designSystem.shadow(for: .neoCard))
    }

    private func emptyNote(_ text: String) -> some View {
        Text(text)
            .font(designSystem.types.bodyMedium)
            .foregroundStyle(cs.onSpace.opacity(0.5))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, DesignSystem.Sizes.xl)
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text("No stats yet")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

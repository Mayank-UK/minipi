//
//  EarthquakeStatsTab.swift
//  MiniPi
//
//  The Stats tab: charts over the loaded feed dataset. Built with Swift Charts
//  (iOS 16+) — magnitude-band distribution, events over time, depth distribution,
//  and top regions. Mirrors the asteroid screen-set's stat screens in spirit.
//  This is the first charting surface in the app; the period picker is niche to
//  this tab so it lives here as a private view.
//

import SwiftUI
import Charts

struct EarthquakeStatsTab: View {
    @ObservedObject var viewModel: EarthquakeViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            if viewModel.isLoading && viewModel.earthquakes.isEmpty {
                ProgressView().tint(cs.orbitPrimary)
            } else if viewModel.earthquakes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Sizes.md) {
                        Text("Statistics")
                            .font(designSystem.types.headlineSmall)
                            .foregroundStyle(cs.onSpace)

                        magnitudeDistributionChart
                        overTimeChart
                        depthChart
                        topRegionsChart
                    }
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.bottom, DesignSystem.Sizes.xxl)
                }
            }
        }
        .task {
            if viewModel.earthquakes.isEmpty {
                await viewModel.loadFeed()
            }
        }
    }

    // MARK: - Charts

    private var magnitudeDistributionChart: some View {
        let distribution = viewModel.magnitudeDistribution
        return card(title: "By Magnitude") {
            Chart(distribution, id: \.range) { entry in
                SectorMark(angle: .value("Count", entry.count),
                           innerRadius: .ratio(0.55))
                    .foregroundStyle(by: .value("Range", entry.range))
            }
            .frame(height: 220)
        }
    }

    private var overTimeChart: some View {
        let perDay = viewModel.perDayCounts
        return card(title: "Events Over Time") {
            Chart(perDay, id: \.day) { entry in
                LineMark(x: .value("Day", entry.day), y: .value("Count", entry.count))
                    .foregroundStyle(cs.orbitPrimary)
                    .interpolationMethod(.monotone)
                AreaMark(x: .value("Day", entry.day), y: .value("Count", entry.count))
                    .foregroundStyle(cs.orbitPrimary.opacity(0.18))
                    .interpolationMethod(.monotone)
            }
            .frame(height: 200)
        }
    }

    private var depthChart: some View {
        let depths = viewModel.depthDistribution
        return card(title: "Depth Distribution") {
            Chart(depths, id: \.label) { entry in
                BarMark(x: .value("Count", entry.count), y: .value("Depth", entry.label))
                    .foregroundStyle(cs.orbitAccent)
            }
            .frame(height: 160)
        }
    }

    private var topRegionsChart: some View {
        let regions = viewModel.topRegions
        return card(title: "Top Regions") {
            Chart(regions, id: \.region) { entry in
                BarMark(x: .value("Count", entry.count), y: .value("Region", entry.region))
                    .foregroundStyle(cs.hazard)
            }
            .frame(height: CGFloat(max(160, regions.count * 36)))
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

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "chart.bar")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text("No data to chart yet")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

//
//  CryptoStatsTab.swift
//  MiniPi
//
//  The Stats tab: charts over the loaded market dataset. Built with Swift Charts
//  (iOS 16+), mirroring the forex stats tab — top-movers comparison, market breadth,
//  and a watchlist % change snapshot. The card helper is copied from the forex stats
//  tab (niche to chart surfaces).
//

import SwiftUI
import Charts

struct CryptoStatsTab: View {
    @ObservedObject var viewModel: CryptoViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            if viewModel.isLoading && viewModel.marketOverview == nil {
                ProgressView().tint(cs.orbitPrimary)
            } else if let overview = viewModel.marketOverview {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Sizes.md) {
                        Text("Statistics")
                            .font(designSystem.types.headlineSmall)
                            .foregroundStyle(cs.onSpace)

                        moversChart(overview)
                        breadthChart(overview)
                        watchlistChart
                    }
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.bottom, DesignSystem.Sizes.xxl)
                }
            } else {
                emptyState
            }
        }
        .task {
            if viewModel.marketOverview == nil {
                await viewModel.bootstrap()
            }
        }
    }

    // MARK: - Charts

    /// Top movers (gainers up / losers down) as a horizontal % bar.
    private func moversChart(_ overview: CryptoMarketOverview) -> some View {
        let movers = (overview.topGainers + overview.topLosers).sorted { $0.quote.changePercent > $1.quote.changePercent }
        return card(title: "Top Movers (% change)") {
            Chart(movers) { item in
                BarMark(
                    x: .value("Change", item.quote.changePercent),
                    y: .value("Coin", item.coin.displaySymbol)
                )
                .foregroundStyle(item.quote.isUp ? cs.distanceSafe : cs.distanceDanger)
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(position: .bottom)
            }
            .frame(height: CGFloat(max(movers.count, 1)) * 36)
        }
    }

    /// Breadth: count of advancers vs decliners across the universe.
    private func breadthChart(_ overview: CryptoMarketOverview) -> some View {
        let gainers = overview.topGainers.count
        let losers = overview.topLosers.count
        let buckets: [(label: String, count: Int, color: Color)] = [
            ("Advancers", gainers, cs.distanceSafe),
            ("Decliners", losers, cs.distanceDanger),
        ]
        return card(title: "Market Breadth") {
            Chart(buckets, id: \.label) { bucket in
                BarMark(
                    x: .value("Count", bucket.count),
                    y: .value("Group", bucket.label)
                )
                .foregroundStyle(bucket.color)
                .cornerRadius(3)
                .annotation(position: .trailing) {
                    Text("\(bucket.count)")
                        .font(designSystem.types.labelSmall)
                        .foregroundStyle(cs.onSpace.opacity(0.7))
                }
            }
            .chartXAxis {
                AxisMarks(position: .bottom)
            }
            .frame(height: 120)
        }
    }

    /// Watchlist % change snapshot.
    private var watchlistChart: some View {
        let items = viewModel.watchlistQuotes
        return card(title: "Watchlist (% change)") {
            if items.isEmpty {
                Text("Saved coins will appear here")
                    .font(designSystem.types.bodyMedium)
                    .foregroundStyle(cs.onSpace.opacity(0.5))
            } else {
                Chart(items) { item in
                    BarMark(
                        x: .value("Change", item.quote.changePercent),
                        y: .value("Coin", item.coin.displaySymbol)
                    )
                    .foregroundStyle(item.quote.isUp ? cs.distanceSafe : cs.distanceDanger)
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
                .frame(height: CGFloat(max(items.count, 1)) * 36)
            }
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

//
//  CryptoHomeTab.swift
//  MiniPi
//
//  The Home tab of the crypto screen set. Absorbs the Markets role: a segment chip bar
//  (All / Top Gainers / Top Losers) over the loaded overview, plus sparkline cards for
//  the top coins and chevron rows for the movers (saving happens from the detail sheet
//  per the row convention). Crypto has no country, so there is no picker. Loading /
//  error / refresh states follow the same severity rules as the forex/stocks home tab
//  (critical + no cache → full ErrorView; warning with cached data → non-blocking
//  snackbar). Live data source badge = Yahoo Finance.
//

import SwiftUI
import Charts

struct CryptoHomeTab: View {
    @ObservedObject var viewModel: CryptoViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            if isLoadingCritical {
                ErrorView(failure: viewModel.currentFailure!,
                          onRetry: { Task { await viewModel.loadOverview(force: true) } })
            } else if viewModel.isLoading && viewModel.marketOverview == nil {
                ProgressView().tint(cs.orbitPrimary)
            } else if let overview = viewModel.marketOverview {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Sizes.md) {
                        header(overview)
                        LiveDataBadge(source: "Yahoo Finance")
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if overview.all.isEmpty && overview.topGainers.isEmpty && overview.topLosers.isEmpty {
                            emptyNote("No prices available right now")
                        } else {
                            segmentBar
                            segmentContent(overview)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.bottom, DesignSystem.Sizes.xxl)
                }
                .refreshable { await viewModel.loadOverview(force: true) }
            } else {
                emptyState
            }

            if showsSnackbar, let failure = viewModel.currentFailure {
                ErrorSnackbar(failure: failure, onDismiss: { viewModel.clearError() })
                    .padding(.bottom, 56)
            }
        }
        .task {
            if viewModel.marketOverview == nil && viewModel.currentFailure == nil {
                await viewModel.bootstrap()
            }
        }
    }

    // MARK: - State helpers

    private var isLoadingCritical: Bool {
        guard let failure = viewModel.currentFailure else { return false }
        return failure.severity == .critical && viewModel.marketOverview == nil
    }

    private var showsSnackbar: Bool {
        guard let failure = viewModel.currentFailure else { return false }
        return failure.severity != .critical || viewModel.marketOverview != nil
    }

    // MARK: - Header

    private func header(_ overview: CryptoMarketOverview) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Crypto")
                    .font(designSystem.types.headlineSmall)
                    .foregroundStyle(cs.onSpace)
                Text("Coins vs \(overview.quoteLabel)")
                    .font(designSystem.types.bodyMedium)
                    .foregroundStyle(cs.onSpace.opacity(0.6))
            }
            Spacer()
        }
    }

    // MARK: - Segment bar

    private var segmentBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Sizes.sm) {
                ForEach(CryptoSegment.allCases) { segment in
                    Chip(
                        label: segment.title,
                        icon: segment.icon,
                        isSelected: viewModel.selectedSegment == segment,
                        action: { viewModel.selectedSegment = segment }
                    )
                }
            }
        }
    }

    // MARK: - Segment content

    @ViewBuilder
    private func segmentContent(_ overview: CryptoMarketOverview) -> some View {
        switch viewModel.selectedSegment {
        case .all:
            // Sparkline cards for a visible top slice, then the full list as rows.
            cardsSection(items: Array(overview.all.prefix(6)))
            listSection(title: "All Coins", items: overview.all, emptyText: "Prices unavailable")
        case .topGainers:
            listSection(title: "Top Gainers", items: overview.topGainers, emptyText: "No gainers today")
        case .topLosers:
            listSection(title: "Top Losers", items: overview.topLosers, emptyText: "No losers today")
        }
    }

    // MARK: - Sparkline cards

    private func cardsSection(items: [CryptoQuoteItem]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text("Highlights")
                .font(designSystem.types.titleMedium)
                .foregroundStyle(cs.onSpace)
            if items.isEmpty {
                emptyNote("Prices unavailable")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Sizes.sm) {
                        ForEach(items) { item in
                            CoinCard(item: item, cs: cs, types: designSystem.types) {
                                viewModel.openDetail(item.coin)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Movers / all (chevron rows — no save star; saving happens in the detail sheet)

    private func listSection(title: String, items: [CryptoQuoteItem], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text(title)
                .font(designSystem.types.titleMedium)
                .foregroundStyle(cs.onSpace)
            if items.isEmpty {
                emptyNote(emptyText)
            } else {
                VStack(spacing: DesignSystem.Sizes.sm) {
                    ForEach(items) { item in
                        CryptoRow(item: item) {
                            viewModel.openDetail(item.coin)
                        }
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
            Image(systemName: "bitcoinsign.circle.fill")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text("No crypto data")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            Button("Retry") { Task { await viewModel.loadOverview(force: true) } }
                .font(designSystem.types.labelLarge)
                .foregroundStyle(cs.orbitPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Coin card with sparkline

/// A compact coin card: label, price (adaptive precision), % change pill, and a 3-month
/// sparkline. Feature-local to Home.
private struct CoinCard: View {
    let item: CryptoQuoteItem
    let cs: ColorScheme
    let types: FontScheme
    let onTap: () -> Void

    private var changeColor: Color { item.quote.isUp ? cs.distanceSafe : cs.distanceDanger }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
                Text(item.coin.displaySymbol)
                    .font(types.titleSmall)
                    .foregroundStyle(cs.onSpace)
                    .lineLimit(1)

                Text(item.quote.priceText)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(cs.onSpace)
                    .monospacedDigit()

                Text(item.quote.percentText)
                    .font(types.labelSmall)
                    .foregroundStyle(changeColor)
                    .padding(.horizontal, DesignSystem.Sizes.sm)
                    .padding(.vertical, DesignSystem.Sizes.xs)
                    .background(changeColor.opacity(0.15))
                    .clipShape(Capsule())

                sparkline
            }
            .frame(width: 160, alignment: .leading)
            .padding(DesignSystem.Sizes.md)
            .background(cs.spaceSurface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
            .modifier(ShadowProxy(cs: cs))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var sparkline: some View {
        let series = item.sparkline
        if series.count >= 2 {
            Chart(Array(series.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Day", index),
                    y: .value("Close", value)
                )
                .foregroundStyle(changeColor)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: 44)
        } else {
            Color.clear.frame(height: 44)
        }
    }
}

/// Bridges the card shadow without re-reading the `DesignSystem` env off a throwaway
/// instance — same rule as the stocks/forex `ShadowProxy`.
private struct ShadowProxy: ViewModifier {
    let cs: ColorScheme
    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(0.45), radius: 10, x: 0, y: 6)
    }
}

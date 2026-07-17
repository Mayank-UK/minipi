//
//  ForexHomeTab.swift
//  MiniPi
//
//  The Home tab of the forex screen set. Shows the USD-quoted majors (as sparkline
//  cards) + top gainers / losers (chevron rows — saving happens from the detail sheet
//  per the row convention). Forex has no country, so there is no picker (unlike Stocks).
//  Loading / error / refresh states follow the same severity rules as the stocks home
//  tab (critical + no cache → full ErrorView; warning with cached data → non-blocking
//  snackbar). Live data source badge = Yahoo Finance.
//

import SwiftUI
import Charts

struct ForexHomeTab: View {
    @ObservedObject var viewModel: ForexViewModel
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

                        if overview.pairs.isEmpty && overview.topGainers.isEmpty && overview.topLosers.isEmpty {
                            emptyNote("No rates available right now")
                        } else {
                            majorsSection(overview)
                            moversSection("Top Gainers", items: overview.topGainers, emptyText: "No gainers today")
                            moversSection("Top Losers", items: overview.topLosers, emptyText: "No losers today")
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

    private func header(_ overview: ForexMarketOverview) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Forex")
                    .font(designSystem.types.headlineSmall)
                    .foregroundStyle(cs.onSpace)
                Text("Currencies vs \(overview.baseLabel)")
                    .font(designSystem.types.bodyMedium)
                    .foregroundStyle(cs.onSpace.opacity(0.6))
            }
            Spacer()
        }
    }

    // MARK: - Majors (sparkline cards)

    private func majorsSection(_ overview: ForexMarketOverview) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text("Major Pairs")
                .font(designSystem.types.titleMedium)
                .foregroundStyle(cs.onSpace)

            if overview.pairs.isEmpty {
                emptyNote("Rates unavailable")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Sizes.sm) {
                        ForEach(overview.pairs) { item in
                            PairCard(item: item, cs: cs, types: designSystem.types) {
                                viewModel.openDetail(item.pair)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Movers (chevron rows — no save star; saving happens in the detail sheet)

    private func moversSection(_ title: String, items: [ForexQuoteItem], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text(title)
                .font(designSystem.types.titleMedium)
                .foregroundStyle(cs.onSpace)
            if items.isEmpty {
                emptyNote(emptyText)
            } else {
                VStack(spacing: DesignSystem.Sizes.sm) {
                    ForEach(items) { item in
                        ForexRow(item: item) {
                            viewModel.openDetail(item.pair)
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
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text("No forex data")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            Button("Retry") { Task { await viewModel.loadOverview(force: true) } }
                .font(designSystem.types.labelLarge)
                .foregroundStyle(cs.orbitPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Pair card with sparkline

/// A compact pair card: label, rate (plain number, quote-currency precision), % change
/// pill, and a 1-month sparkline. Rates are points, not money. Feature-local to Home.
private struct PairCard: View {
    let item: ForexQuoteItem
    let cs: ColorScheme
    let types: FontScheme
    let onTap: () -> Void

    private var changeColor: Color { item.quote.isUp ? cs.distanceSafe : cs.distanceDanger }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
                Text(item.pair.displaySymbol)
                    .font(types.titleSmall)
                    .foregroundStyle(cs.onSpace)
                    .lineLimit(1)

                Text(item.quote.rateText)
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
/// instance — same rule as the stocks `ShadowProxy`.
private struct ShadowProxy: ViewModifier {
    let cs: ColorScheme
    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(0.45), radius: 10, x: 0, y: 6)
    }
}

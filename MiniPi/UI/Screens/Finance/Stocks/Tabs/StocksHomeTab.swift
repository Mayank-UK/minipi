//
//  StocksHomeTab.swift
//  MiniPi
//
//  The Home tab of the stocks screen set. Shows the active market's indices (as
//  sparkline cards) + top gainers / losers (chevron rows — saving happens from the
//  detail sheet per the row convention), with a country picker. Loading / error /
//  refresh states follow the same severity rules as WeatherHomeTab (critical + no
//  cache → full ErrorView; warning with cached data → non-blocking snackbar). Live
//  data source badge = Yahoo Finance.
//

import SwiftUI
import Charts

struct StocksHomeTab: View {
    @ObservedObject var viewModel: StocksViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    @State private var showCountryPicker: Bool = false

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

                        if overview.indices.isEmpty && overview.topGainers.isEmpty && overview.topLosers.isEmpty {
                            emptyNote("No quotes for this market right now")
                        } else {
                            indicesSection(overview)
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
        .confirmationDialog("Select Market", isPresented: $showCountryPicker, titleVisibility: .visible) {
            ForEach(StockUniverse.pickerRegions, id: \.code) { region in
                Button(region.displayName) { viewModel.selectCountry(region.code) }
            }
            Button("Cancel", role: .cancel) {}
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

    // MARK: - Header + country picker

    private func header(_ overview: StockMarketOverview) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Markets")
                    .font(designSystem.types.headlineSmall)
                    .foregroundStyle(cs.onSpace)
                Text(overview.country)
                    .font(designSystem.types.bodyMedium)
                    .foregroundStyle(cs.onSpace.opacity(0.6))
            }
            Spacer()
            Button {
                showCountryPicker = true
            } label: {
                Label(viewModel.activeRegion.code, systemImage: "globe")
                    .font(designSystem.types.labelLarge)
                    .foregroundStyle(cs.orbitPrimary)
                    .padding(.horizontal, DesignSystem.Sizes.sm + DesignSystem.Sizes.xs)
                    .padding(.vertical, DesignSystem.Sizes.xs + 2)
                    .background(cs.orbitPrimary.opacity(0.15))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Indices (sparkline cards)

    private func indicesSection(_ overview: StockMarketOverview) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text("Indices")
                .font(designSystem.types.titleMedium)
                .foregroundStyle(cs.onSpace)

            if overview.indices.isEmpty {
                emptyNote("Index quotes unavailable")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Sizes.sm) {
                        ForEach(overview.indices) { item in
                            IndexCard(item: item, cs: cs, types: designSystem.types) {
                                viewModel.openDetail(item.symbol)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Movers (chevron rows — no save star; saving happens in the detail sheet)

    private func moversSection(_ title: String, items: [StockQuoteItem], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text(title)
                .font(designSystem.types.titleMedium)
                .foregroundStyle(cs.onSpace)
            if items.isEmpty {
                emptyNote(emptyText)
            } else {
                VStack(spacing: DesignSystem.Sizes.sm) {
                    ForEach(items) { item in
                        StocksRow(item: item, currency: viewModel.activeRegion.currency) {
                            viewModel.openDetail(item.symbol)
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
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text("No market data")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            Button("Retry") { Task { await viewModel.loadOverview(force: true) } }
                .font(designSystem.types.labelLarge)
                .foregroundStyle(cs.orbitPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Index card with sparkline

/// A compact index card: name, value (points, no currency symbol), % change pill,
/// and a 1-month sparkline. Indices quote in points (not money), so the value uses
/// `StockQuote.formattedPoints`. Feature-local to the Home tab.
private struct IndexCard: View {
    let item: StockQuoteItem
    let cs: ColorScheme
    let types: FontScheme
    let onTap: () -> Void

    private var changeColor: Color { item.quote.isUp ? cs.distanceSafe : cs.distanceDanger }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
                Text(item.symbol.displaySymbol)
                    .font(types.titleSmall)
                    .foregroundStyle(cs.onSpace)
                    .lineLimit(1)

                Text(StockQuote.formattedPoints(item.quote.current))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(cs.onSpace)

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

/// Bridges `DesignSystem.shadow(for:)` (which needs the `DesignSystem`
/// `@EnvironmentObject`) into the feature-local card without re-reading the env off
/// a throwaway instance — same rule as `MagnitudeBadge.color(for:in:)`.
private struct ShadowProxy: ViewModifier {
    let cs: ColorScheme
    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(0.45), radius: 10, x: 0, y: 6)
    }
}

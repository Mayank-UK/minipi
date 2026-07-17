//
//  StocksDetailView.swift
//  MiniPi
//
//  Detail sheet for a single instrument: live quote header, daily candle chart
//  (Swift Charts), key stats, and company profile (Finnhub `profile2`). Loads its
//  own quote + candles + profile concurrently from the VM on appear. The save/remove
//  star mirrors the row convention. Presented as a `.sheet` from StocksView.
//

import SwiftUI
import Charts

struct StocksDetailView: View {
    let symbol: StockSymbol
    @ObservedObject var viewModel: StocksViewModel
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) private var dismiss

    private var cs: ColorScheme { designSystem.colorScheme }
    private var currency: String? { symbol.currency ?? viewModel.activeRegion.currency }

    var body: some View {
        NavigationStack {
            ZStack {
                cs.space.ignoresSafeArea()

                if viewModel.isLoadingDetail && viewModel.detailQuote == nil && viewModel.detailCandle == nil {
                    ProgressView().tint(cs.orbitPrimary)
                } else if let failure = viewModel.detailFailure,
                          viewModel.detailQuote == nil && viewModel.detailCandle == nil {
                    ErrorView(failure: failure, onRetry: { Task { await viewModel.loadDetail(for: symbol) } })
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: DesignSystem.Sizes.md) {
                            header
                            if let candle = viewModel.detailCandle, !candle.isEmpty {
                                candleChart(candle)
                            }
                            if let q = viewModel.detailQuote {
                                statsGrid(q)
                            }
                            if let profile = viewModel.detailProfile {
                                profileSection(profile)
                            }
                        }
                        .padding(.horizontal, DesignSystem.Sizes.md)
                        .padding(.bottom, DesignSystem.Sizes.xxl)
                    }
                }
            }
            .navigationTitle(symbol.displaySymbol)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(cs.space, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.toggleWatchlist(symbol: symbol, quote: viewModel.detailQuote, currency: currency)
                    } label: {
                        Image(systemName: viewModel.isSaved(symbol) ? "star.fill" : "star")
                            .foregroundStyle(viewModel.isSaved(symbol) ? cs.hazard : cs.onSpace.opacity(0.6))
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { viewModel.closeDetail() }
                        .foregroundStyle(cs.orbitPrimary)
                }
            }
        }
        .task {
            if viewModel.detailQuote == nil && viewModel.detailCandle == nil {
                await viewModel.loadDetail(for: symbol)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.xs) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Sizes.sm) {
                if let logo = viewModel.detailProfile?.logo, let url = URL(string: logo) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            placeholderIcon
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.sm))
                } else {
                    placeholderIcon
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(symbol.displaySymbol)
                        .font(designSystem.types.titleLarge)
                        .foregroundStyle(cs.onSpace)
                    Text(viewModel.detailProfile?.name ?? symbol.subtitle)
                        .font(designSystem.types.bodyMedium)
                        .foregroundStyle(cs.onSpace.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer()
            }

            if let q = viewModel.detailQuote {
                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Sizes.sm) {
                    Text(q.priceText(currency: currency))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(cs.onSpace)
                    Text(q.changeText())
                        .font(designSystem.types.labelLarge)
                        .foregroundStyle(q.isUp ? cs.distanceSafe : cs.distanceDanger)
                        .padding(.horizontal, DesignSystem.Sizes.sm)
                        .padding(.vertical, DesignSystem.Sizes.xs)
                        .background((q.isUp ? cs.distanceSafe : cs.distanceDanger).opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(DesignSystem.Sizes.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cs.spaceSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
        .modifier(designSystem.shadow(for: .neoCard))
    }

    private var placeholderIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.Sizes.sm)
                .fill(cs.orbitPrimary.opacity(0.16))
            Image(systemName: symbol.type.icon)
                .foregroundStyle(cs.orbitPrimary)
        }
        .frame(width: 40, height: 40)
    }

    // MARK: - Candle chart

    private func candleChart(_ candle: StockCandle) -> some View {
        let series = Array(zip(candle.timestamps, candle.closes))
        return card(title: "3-Month Daily Close") {
            Chart(series, id: \.0) { point in
                LineMark(
                    x: .value("Date", point.0),
                    y: .value("Close", point.1)
                )
                .foregroundStyle(cs.orbitPrimary)
                .interpolationMethod(.monotone)

                AreaMark(
                    x: .value("Date", point.0),
                    y: .value("Close", point.1)
                )
                .foregroundStyle(cs.orbitPrimary.opacity(0.15))
                .interpolationMethod(.monotone)
            }
            .frame(height: 220)
        }
    }

    // MARK: - Stats

    private func statsGrid(_ q: StockQuote) -> some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Sizes.md), count: 2)
        return LazyVGrid(columns: cols, spacing: DesignSystem.Sizes.md) {
            StatTile(title: "Open", value: StockQuote.formattedPrice(q.open, currency: currency), icon: "sunrise", accent: cs.orbitAccent)
            StatTile(title: "Previous Close", value: StockQuote.formattedPrice(q.prevClose, currency: currency), icon: "arrow.uturn.backward.circle", accent: cs.orbitPrimary)
            StatTile(title: "Day High", value: StockQuote.formattedPrice(q.high, currency: currency), icon: "arrow.up.right", accent: cs.distanceSafe)
            StatTile(title: "Day Low", value: StockQuote.formattedPrice(q.low, currency: currency), icon: "arrow.down.right", accent: cs.distanceDanger)
        }
    }

    // MARK: - Profile

    private func profileSection(_ profile: StockProfile) -> some View {
        card(title: "Profile") {
            VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
                profileRow("Exchange", profile.exchange)
                profileRow("Industry", profile.industry)
                profileRow("Country", profile.country)
                profileRow("Currency", profile.currency)
                if let cap = profile.marketCap {
                    profileRow("Market Cap", formatMarketCap(cap))
                }
            }
        }
    }

    @ViewBuilder
    private func profileRow(_ label: String, _ value: String?) -> some View {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        HStack {
            Text(label)
                .font(designSystem.types.labelMedium)
                .foregroundStyle(cs.onSpace.opacity(0.6))
            Spacer()
            Text((text?.isEmpty == false ? text! : "—"))
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace)
        }
    }

    private func formatMarketCap(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        if value >= 1_000_000_000 {
            return String(format: "$%.2fT", value / 1_000_000_000)
        } else if value >= 1_000_000 {
            return String(format: "$%.2fB", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "$%.2fM", value / 1_000)
        }
        return String(format: "$%.0f", value)
    }

    // MARK: - Card helper

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
}

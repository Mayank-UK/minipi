//
//  ForexDetailView.swift
//  MiniPi
//
//  Detail sheet for a single currency pair: live rate header, daily candle chart
//  (Swift Charts) and key stats. Loads its own rate + candles concurrently from the VM
//  on appear. The save/remove star mirrors the row convention. Presented as a `.sheet`
//  from ForexView.
//

import SwiftUI
import Charts

struct ForexDetailView: View {
    let pair: ForexPair
    @ObservedObject var viewModel: ForexViewModel
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) private var dismiss

    private var cs: ColorScheme { designSystem.colorScheme }
    private var quoteCurrency: String { pair.quote }

    var body: some View {
        NavigationStack {
            ZStack {
                cs.space.ignoresSafeArea()

                if viewModel.isLoadingDetail && viewModel.detailQuote == nil && viewModel.detailCandle == nil {
                    ProgressView().tint(cs.orbitPrimary)
                } else if let failure = viewModel.detailFailure,
                          viewModel.detailQuote == nil && viewModel.detailCandle == nil {
                    ErrorView(failure: failure, onRetry: { Task { await viewModel.loadDetail(for: pair) } })
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
                        }
                        .padding(.horizontal, DesignSystem.Sizes.md)
                        .padding(.bottom, DesignSystem.Sizes.xxl)
                    }
                }
            }
            .navigationTitle(pair.displaySymbol)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(cs.space, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.toggleWatchlist(pair: pair, quote: viewModel.detailQuote)
                    } label: {
                        Image(systemName: viewModel.isSaved(pair) ? "star.fill" : "star")
                            .foregroundStyle(viewModel.isSaved(pair) ? cs.hazard : cs.onSpace.opacity(0.6))
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
                await viewModel.loadDetail(for: pair)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.xs) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Sizes.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Sizes.sm)
                        .fill(cs.orbitPrimary.opacity(0.16))
                    Text(pair.base.prefix(1))
                        .font(.system(size: DesignSystem.Sizes.iconMd, weight: .bold))
                        .foregroundStyle(cs.orbitPrimary)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(pair.displaySymbol)
                        .font(designSystem.types.titleLarge)
                        .foregroundStyle(cs.onSpace)
                    Text(pair.description)
                        .font(designSystem.types.bodyMedium)
                        .foregroundStyle(cs.onSpace.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer()
            }

            if let q = viewModel.detailQuote {
                HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Sizes.sm) {
                    Text(q.rateText)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(cs.onSpace)
                        .monospacedDigit()
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

    // MARK: - Candle chart

    private func candleChart(_ candle: ForexCandle) -> some View {
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

    private func statsGrid(_ q: ForexQuote) -> some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Sizes.md), count: 2)
        return LazyVGrid(columns: cols, spacing: DesignSystem.Sizes.md) {
            StatTile(title: "Open", value: ForexQuote.formattedRate(q.open, quoteCurrency: quoteCurrency), icon: "sunrise", accent: cs.orbitAccent)
            StatTile(title: "Previous Close", value: ForexQuote.formattedRate(q.prevClose, quoteCurrency: quoteCurrency), icon: "arrow.uturn.backward.circle", accent: cs.orbitPrimary)
            StatTile(title: "Day High", value: ForexQuote.formattedRate(q.high, quoteCurrency: quoteCurrency), icon: "arrow.up.right", accent: cs.distanceSafe)
            StatTile(title: "Day Low", value: ForexQuote.formattedRate(q.low, quoteCurrency: quoteCurrency), icon: "arrow.down.right", accent: cs.distanceDanger)
        }
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

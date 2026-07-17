//
//  ForexWatchlistTab.swift
//  MiniPi
//
//  The Watchlist tab: the user's saved pairs (persisted via ForexWatchlistStore). Rates
//  are refreshed on appear; tap a row to open the detail sheet. Mirrors the stocks
//  watchlist tab. The saved snapshot carries the last-seen rate so rows render before
//  the refresh completes.
//

import SwiftUI

struct ForexWatchlistTab: View {
    @ObservedObject var viewModel: ForexViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            if viewModel.watchlist.snapshots.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Sizes.sm) {
                        ForEach(viewModel.watchlistQuotes.isEmpty ? snapshotItems : viewModel.watchlistQuotes) { item in
                            ForexRow(item: item) {
                                viewModel.openDetail(item.pair)
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.bottom, DesignSystem.Sizes.xxl)
                }
                .refreshable { await viewModel.refreshWatchlist() }
            }
        }
        .task {
            await viewModel.refreshWatchlist()
        }
    }

    /// Renders from persisted snapshots (with last-seen rate) before the live quote
    /// refresh completes — so the watchlist is never blank after relaunch.
    private var snapshotItems: [ForexQuoteItem] {
        viewModel.watchlist.snapshots.map { snap in
            let pair = ForexPair(id: snap.id, symbol: snap.id, base: snap.base,
                                 quote: snap.quote, description: snap.description)
            let quote = ForexQuote(
                symbol: snap.id, rate: snap.lastRate ?? 0, change: 0,
                changePercent: snap.changePercent ?? 0, high: 0, low: 0, open: 0,
                prevClose: 0, time: nil, quoteCurrency: snap.quote
            )
            return ForexQuoteItem(pair: pair, quote: quote)
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "star")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text("Your watchlist is empty")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            Text("Tap the star on any pair to save it here.")
                .font(designSystem.types.labelMedium)
                .foregroundStyle(cs.onSpace.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Sizes.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

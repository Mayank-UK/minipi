//
//  StocksWatchlistTab.swift
//  MiniPi
//
//  The Watchlist tab: the user's saved instruments (persisted via
//  StocksWatchlistStore). Quotes are refreshed on appear; tap a row to open the
//  detail sheet. Mirrors the Earthquake Watchlist tab. The saved snapshot carries
//  the last-seen price so rows render before the refresh completes.
//

import SwiftUI

struct StocksWatchlistTab: View {
    @ObservedObject var viewModel: StocksViewModel
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
                            StocksRow(
                                item: item,
                                currency: item.symbol.currency,
                                onTap: { viewModel.openDetail(item.symbol) }
                            )
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

    /// Renders from persisted snapshots (with last-seen price) before the live
    /// quote refresh completes — so the watchlist is never blank after relaunch.
    private var snapshotItems: [StockQuoteItem] {
        viewModel.watchlist.snapshots.map { snap in
            let symbol = StockSymbol(
                id: snap.id, symbol: snap.symbol, displaySymbol: snap.displaySymbol,
                description: snap.description, type: StockType(rawValue: snap.type) ?? .other,
                exchange: nil, currency: snap.currency, country: nil
            )
            let quote = StockQuote(
                symbol: snap.symbol, current: snap.lastPrice ?? 0, change: 0,
                changePercent: snap.changePercent ?? 0, high: 0, low: 0, open: 0,
                prevClose: 0, time: nil
            )
            return StockQuoteItem(symbol: symbol, quote: quote)
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
            Text("Tap the star on any instrument to save it here.")
                .font(designSystem.types.labelMedium)
                .foregroundStyle(cs.onSpace.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Sizes.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

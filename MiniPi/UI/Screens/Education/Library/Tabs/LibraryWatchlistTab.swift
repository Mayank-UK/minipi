//
//  LibraryWatchlistTab.swift
//  MiniPi
//
//  The Watchlist tab: the user's saved books (persisted via LibraryWatchlistStore). Tap a
//  row to open the detail sheet. Mirrors the crypto watchlist tab. Saved snapshots carry
//  enough to render a row immediately after relaunch.
//

import SwiftUI

struct LibraryWatchlistTab: View {
    @ObservedObject var viewModel: LibraryViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            if viewModel.watchlist.savedWorks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Sizes.sm) {
                        ForEach(viewModel.watchlist.savedWorks) { work in
                            LibraryRow(work: work) {
                                viewModel.openDetail(work)
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.bottom, DesignSystem.Sizes.xxl)
                }
            }
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
            Text("Tap the star on any book to save it here.")
                .font(designSystem.types.labelMedium)
                .foregroundStyle(cs.onSpace.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Sizes.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

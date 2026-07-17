//
//  LibraryRankingTab.swift
//  MiniPi
//
//  The Ranking tab: Open Library's trending works across a period window (Now / Daily /
//  Weekly / Monthly / Yearly). A chip bar switches the period; the list reloads on change.
//  Tap a row to open the detail sheet. Rows show a leading rank number (chevron, no save
//  star — saving happens in the detail sheet).
//

import SwiftUI

struct LibraryRankingTab: View {
    @ObservedObject var viewModel: LibraryViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            VStack(spacing: DesignSystem.Sizes.md) {
                periodBar
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.top, DesignSystem.Sizes.md)

                if viewModel.isTrendingLoading && viewModel.trendingBooks.isEmpty {
                    Spacer()
                    ProgressView().tint(cs.orbitPrimary)
                    Spacer()
                } else if let failure = viewModel.trendingFailure, viewModel.trendingBooks.isEmpty {
                    Spacer()
                    ErrorView(failure: failure, onRetry: { Task { await viewModel.loadTrending(period: viewModel.trendingPeriod, force: true) } })
                    Spacer()
                } else if viewModel.trendingBooks.isEmpty {
                    emptyState
                } else {
                    list
                }
            }

            if let failure = viewModel.trendingFailure, !viewModel.trendingBooks.isEmpty {
                ErrorSnackbar(failure: failure, onDismiss: { viewModel.clearTrendingError() })
                    .padding(.bottom, 56)
            }
        }
        .task {
            if viewModel.trendingBooks.isEmpty && viewModel.trendingFailure == nil {
                await viewModel.loadTrending(period: viewModel.trendingPeriod)
            }
        }
    }

    // MARK: - Period chip bar

    private var periodBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Sizes.sm) {
                ForEach(LibraryTrendingPeriod.allCases) { period in
                    Chip(
                        label: period.title,
                        icon: period.icon,
                        isSelected: viewModel.trendingPeriod == period,
                        action: {
                            Task { await viewModel.loadTrending(period: period) }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Ranked list

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Sizes.sm) {
                ForEach(Array(viewModel.trendingBooks.enumerated()), id: \.element.id) { index, work in
                    LibraryRow(work: work, rank: index + 1) {
                        viewModel.openDetail(work)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Sizes.md)
            .padding(.bottom, DesignSystem.Sizes.xxl)
        }
        .refreshable { await viewModel.loadTrending(period: viewModel.trendingPeriod, force: true) }
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "list.number")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text("No trending books right now")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            Button("Retry") { Task { await viewModel.loadTrending(period: viewModel.trendingPeriod, force: true) } }
                .font(designSystem.types.labelLarge)
                .foregroundStyle(cs.orbitPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

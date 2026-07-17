//
//  LibraryHomeTab.swift
//  MiniPi
//
//  The Home tab of the library screen set: tappable StatTiles (Books / Subjects / Trending /
//  Watchlist — mirroring the Indicators/AIModels tappable-StatTile pattern), a Trending books
//  horizontal card rail, and a Popular subjects grid (tap → pre-fill a subject search).
//  Loading / error / refresh states follow the same severity rules as the crypto home tab
//  (critical + no cache → full ErrorView; warning with cached data → non-blocking snackbar).
//  Live data source badge = Open Library.
//

import SwiftUI

struct LibraryHomeTab: View {
    @ObservedObject var viewModel: LibraryViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            if isLoadingCritical {
                ErrorView(failure: viewModel.currentFailure!,
                          onRetry: { Task { await viewModel.loadOverview(force: true) } })
            } else if viewModel.isLoading && viewModel.homeOverview == nil {
                ProgressView().tint(cs.orbitPrimary)
            } else if let overview = viewModel.homeOverview {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Sizes.md) {
                        header
                        statsRow(overview)
                        LiveDataBadge(source: "Open Library")
                            .frame(maxWidth: .infinity, alignment: .leading)

                        trendingSection(overview)
                        subjectsSection(overview)
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
            if viewModel.homeOverview == nil && viewModel.currentFailure == nil {
                await viewModel.bootstrap()
            }
        }
    }

    // MARK: - State helpers

    private var isLoadingCritical: Bool {
        guard let failure = viewModel.currentFailure else { return false }
        return failure.severity == .critical && viewModel.homeOverview == nil
    }

    private var showsSnackbar: Bool {
        guard let failure = viewModel.currentFailure else { return false }
        return failure.severity != .critical || viewModel.homeOverview != nil
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Open Library")
                .font(designSystem.types.headlineSmall)
                .foregroundStyle(cs.onSpace)
            Text("Explore millions of books")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.6))
        }
    }

    // MARK: - Stat tiles (tappable → jump to a tab)

    private func statsRow(_ overview: LibraryHomeOverview) -> some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Sizes.sm), count: 2)
        return LazyVGrid(columns: cols, spacing: DesignSystem.Sizes.sm) {
            StatTile(title: "Books", value: LibrarySubject.compactCount(overview.bookCount), icon: "books.vertical.fill", accent: cs.orbitAccent) {
                viewModel.openTab(.search)
            }
            StatTile(title: "Subjects", value: "\(overview.popularSubjects.count)", icon: "tag.fill", accent: cs.orbitPrimary) {
                viewModel.openTab(.search)
            }
            StatTile(title: "Trending", value: "\(overview.trendingBooks.count)", icon: "sparkles", accent: cs.distanceSafe) {
                viewModel.openTab(.ranking)
            }
            StatTile(title: "Watchlist", value: "\(viewModel.watchlist.snapshots.count)", icon: "star.fill", accent: cs.hazard) {
                viewModel.openTab(.watchlist)
            }
        }
    }

    // MARK: - Trending rail

    private func trendingSection(_ overview: LibraryHomeOverview) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text("Trending Books")
                .font(designSystem.types.titleMedium)
                .foregroundStyle(cs.onSpace)

            if overview.trendingBooks.isEmpty {
                emptyNote("Trending unavailable right now")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Sizes.sm) {
                        ForEach(overview.trendingBooks) { work in
                            BookCard(work: work, cs: cs, types: designSystem.types) {
                                viewModel.openDetail(work)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Popular subjects grid

    private func subjectsSection(_ overview: LibraryHomeOverview) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text("Popular Subjects")
                .font(designSystem.types.titleMedium)
                .foregroundStyle(cs.onSpace)

            if overview.popularSubjects.isEmpty {
                emptyNote("Subjects unavailable right now")
            } else {
                let cols = Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Sizes.sm), count: 4)
                LazyVGrid(columns: cols, spacing: DesignSystem.Sizes.md) {
                    ForEach(overview.popularSubjects) { subject in
                        Button {
                            viewModel.searchSubject(subject)
                        } label: {
                            subjectTile(subject)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func subjectTile(_ subject: LibrarySubject) -> some View {
        let entry = LibrarySubjects.popular.first { $0.slug == subject.slug }
        return VStack(spacing: DesignSystem.Sizes.xs) {
            ZStack {
                Circle()
                    .fill(cs.orbitPrimary.opacity(0.16))
                Image(systemName: entry?.icon ?? "book.fill")
                    .font(.system(size: DesignSystem.Sizes.iconMd, weight: .semibold))
                    .foregroundStyle(cs.orbitPrimary)
            }
            .frame(width: 52, height: 52)

            Text(subject.displayName)
                .font(designSystem.types.labelMedium)
                .foregroundStyle(cs.onSpace)
                .lineLimit(1)
            Text("\(subject.workCountText) books")
                .font(designSystem.types.labelSmall)
                .foregroundStyle(cs.onSpace.opacity(0.5))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
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
            Image(systemName: "books.vertical.circle.fill")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text("No library data")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            Button("Retry") { Task { await viewModel.loadOverview(force: true) } }
                .font(designSystem.types.labelLarge)
                .foregroundStyle(cs.orbitPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Trending book card

/// A compact book card: cover, title, author · year. Feature-local to Home.
private struct BookCard: View {
    let work: LibraryWork
    let cs: ColorScheme
    let types: FontScheme
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
                cover
                Text(work.title)
                    .font(types.titleSmall)
                    .foregroundStyle(cs.onSpace)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(work.primaryAuthor)
                    .font(types.labelSmall)
                    .foregroundStyle(cs.onSpace.opacity(0.6))
                    .lineLimit(1)
            }
            .frame(width: 120, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var cover: some View {
        Group {
            if let url = work.coverURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: 120, height: 170)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.sm))
        .modifier(BookCardShadow(cs: cs))
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.Sizes.sm)
                .fill(cs.orbitPrimary.opacity(0.16))
            Image(systemName: "book.closed")
                .font(.system(size: DesignSystem.Sizes.iconMd, weight: .semibold))
                .foregroundStyle(cs.orbitPrimary)
        }
    }
}

/// Bridges the card shadow without re-reading the `DesignSystem` env off a throwaway
/// instance — same rule as the crypto/stocks `ShadowProxy`.
private struct BookCardShadow: ViewModifier {
    let cs: ColorScheme
    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(0.45), radius: 10, x: 0, y: 6)
    }
}

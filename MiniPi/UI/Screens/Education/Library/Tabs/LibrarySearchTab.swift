//
//  LibrarySearchTab.swift
//  MiniPi
//
//  The Search tab: server-backed Open Library search, scoped to Books / Authors / Subjects
//  (a chip filter — all three query `/search.json` with a different param, so results are
//  always works). Filters apply automatically on change — no "Apply" button — debounced in
//  the VM (350 ms) via `scheduleSearch`. Tap a result to open the detail sheet. Mirrors the
//  crypto search tab.
//

import SwiftUI

struct LibrarySearchTab: View {
    @ObservedObject var viewModel: LibraryViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            VStack(spacing: DesignSystem.Sizes.md) {
                searchBar
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.top, DesignSystem.Sizes.md)

                scopeBar
                    .padding(.horizontal, DesignSystem.Sizes.md)

                if viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                    discoverList
                } else if viewModel.isSearching && viewModel.searchResults.isEmpty {
                    Spacer()
                    ProgressView().tint(cs.orbitPrimary)
                    Spacer()
                } else if viewModel.searchResults.isEmpty {
                    emptyResults
                } else {
                    resultsList
                }
            }

            if let failure = viewModel.searchFailure {
                ErrorSnackbar(failure: failure, onDismiss: { viewModel.clearSearchError() })
                    .padding(.bottom, 56)
            }
        }
        .task {
            if viewModel.discoverBooks.isEmpty {
                await viewModel.loadDiscover()
            }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(cs.onSpace.opacity(0.5))
            TextField("Search books, authors, subjects…", text: $viewModel.searchQuery)
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace)
                .autocorrectionDisabled()
                .onChange(of: viewModel.searchQuery) { _ in
                    viewModel.scheduleSearch()
                }
                .submitLabel(.search)
                .onSubmit { viewModel.scheduleSearch(immediate: true) }
            if viewModel.isSearching {
                ProgressView().tint(cs.orbitPrimary).scaleEffect(0.8)
            } else if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                    viewModel.searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(cs.onSpace.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Sizes.md)
        .padding(.vertical, DesignSystem.Sizes.sm)
        .background(cs.spaceSurface)
        .clipShape(Capsule())
    }

    // MARK: - Scope chips

    private var scopeBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Sizes.sm) {
                ForEach(LibrarySearchScope.allCases) { scope in
                    Chip(
                        label: scope.title,
                        icon: scope.icon,
                        isSelected: viewModel.selectedScope == scope,
                        action: {
                            viewModel.selectedScope = scope
                            viewModel.searchCurrentScope()
                        }
                    )
                }
            }
        }
    }

    // MARK: - Results

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Sizes.sm) {
                ForEach(viewModel.searchResults) { work in
                    LibraryRow(work: work) {
                        viewModel.openDetail(work)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Sizes.md)
            .padding(.bottom, DesignSystem.Sizes.xxl)
        }
    }

    /// Default content when no query is typed — scope-aware so switching Books / Authors /
    /// Subjects with an empty box always shows something relevant. Books → trending works;
    /// Authors → popular authors derived from trending; Subjects → the popular subjects grid.
    private var discoverList: some View {
        Group {
            if viewModel.isDiscoverLoading && viewModel.discoverBooks.isEmpty {
                Spacer()
                ProgressView().tint(cs.orbitPrimary)
                Spacer()
            } else if viewModel.discoverBooks.isEmpty {
                Spacer()
                prompt
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
                        switch viewModel.selectedScope {
                        case .books: discoverBooksSection
                        case .authors: discoverAuthorsSection
                        case .subjects: discoverSubjectsSection
                        }
                    }
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.bottom, DesignSystem.Sizes.xxl)
                }
            }
        }
    }

    private var discoverBooksSection: some View {
        Section(
            header: sectionHeader("Popular right now")
        ) {
            ForEach(viewModel.discoverBooks) { work in
                LibraryRow(work: work) { viewModel.openDetail(work) }
            }
        }
    }

    private var discoverAuthorsSection: some View {
        Section(
            header: sectionHeader("Popular authors")
        ) {
            let authors = viewModel.discoverAuthors
            if authors.isEmpty {
                discoverEmpty("No author suggestions")
            } else {
                ForEach(authors) { author in
                    Button {
                        viewModel.prefillSearch(scope: .authors, query: author.name)
                    } label: {
                        authorRow(author)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var discoverSubjectsSection: some View {
        Section(
            header: sectionHeader("Popular subjects")
        ) {
            let subjects = viewModel.homeOverview?.popularSubjects ?? []
            if subjects.isEmpty {
                discoverEmpty("No subject suggestions")
            } else {
                let cols = Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Sizes.sm), count: 4)
                LazyVGrid(columns: cols, spacing: DesignSystem.Sizes.md) {
                    ForEach(subjects) { subject in
                        Button {
                            viewModel.prefillSearch(scope: .subjects, query: subject.displayName)
                        } label: {
                            subjectTile(subject)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(designSystem.types.titleMedium)
            .foregroundStyle(cs.onSpace)
            .padding(.top, DesignSystem.Sizes.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func discoverEmpty(_ text: String) -> some View {
        Text(text)
            .font(designSystem.types.bodyMedium)
            .foregroundStyle(cs.onSpace.opacity(0.5))
            .padding(DesignSystem.Sizes.sm)
    }

    private func authorRow(_ author: LibraryAuthorSummary) -> some View {
        HStack(spacing: DesignSystem.Sizes.md) {
            ZStack {
                Circle().fill(cs.orbitPrimary.opacity(0.16))
                Text(author.initials)
                    .font(designSystem.types.titleSmall)
                    .foregroundStyle(cs.orbitPrimary)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(author.name)
                    .font(designSystem.types.titleSmall)
                    .foregroundStyle(cs.onSpace)
                    .lineLimit(1)
                Text("\(author.count) trending work\(author.count == 1 ? "" : "s")")
                    .font(designSystem.types.labelMedium)
                    .foregroundStyle(cs.onSpace.opacity(0.6))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: DesignSystem.Sizes.iconSm, weight: .semibold))
                .foregroundStyle(cs.onSpace.opacity(0.3))
        }
        .padding(DesignSystem.Sizes.md)
        .background(cs.spaceSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
        .modifier(designSystem.shadow(for: .neoCard))
    }

    private func subjectTile(_ subject: LibrarySubject) -> some View {
        let entry = LibrarySubjects.popular.first { $0.slug == subject.slug }
        return VStack(spacing: DesignSystem.Sizes.xs) {
            ZStack {
                Circle().fill(cs.orbitPrimary.opacity(0.16))
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

    private var prompt: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text("Search across millions of books")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
        }
    }

    private var emptyResults: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.onSpace.opacity(0.4))
            Text("No results for “\(viewModel.searchQuery)”")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            if let failure = viewModel.searchFailure {
                Text(failure.message)
                    .font(designSystem.types.labelSmall)
                    .foregroundStyle(cs.distanceDanger)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

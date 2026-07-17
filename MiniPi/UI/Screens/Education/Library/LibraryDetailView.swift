//
//  LibraryDetailView.swift
//  MiniPi
//
//  Detail sheet for a single library work: cover + title + author header, key StatTiles
//  (first published / editions / language / access), an "About" description, and the work's
//  subjects. Loads its own full work detail from the VM on appear (description + subjects;
//  the header reads from the passed-in work). The save/remove star mirrors the row
//  convention. Presented as a `.sheet` from LibraryView.
//

import SwiftUI

struct LibraryDetailView: View {
    let work: LibraryWork
    @ObservedObject var viewModel: LibraryViewModel
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) private var dismiss

    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        NavigationStack {
            ZStack {
                cs.space.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Sizes.md) {
                        header
                        statsGrid
                        if let description = viewModel.detail?.description,
                           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            aboutSection(description)
                        }
                        if let subjects = viewModel.detail?.subjects, !subjects.isEmpty {
                            subjectsSection(subjects)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.bottom, DesignSystem.Sizes.xxl)
                }
            }
            .navigationTitle(work.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(cs.space, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.toggleWatchlist(work: work)
                    } label: {
                        Image(systemName: viewModel.isSaved(work) ? "star.fill" : "star")
                            .foregroundStyle(viewModel.isSaved(work) ? cs.hazard : cs.onSpace.opacity(0.6))
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { viewModel.closeDetail() }
                        .foregroundStyle(cs.orbitPrimary)
                }
            }
        }
        .task {
            if viewModel.detail == nil && viewModel.detailFailure == nil {
                await viewModel.loadDetail(for: work)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: DesignSystem.Sizes.md) {
            cover
            VStack(alignment: .leading, spacing: DesignSystem.Sizes.xs) {
                Text(work.title)
                    .font(designSystem.types.titleLarge)
                    .foregroundStyle(cs.onSpace)
                Text(work.primaryAuthor)
                    .font(designSystem.types.bodyMedium)
                    .foregroundStyle(cs.onSpace.opacity(0.6))
                if let year = work.firstPublishYear {
                    Text("First published \(year)")
                        .font(designSystem.types.labelMedium)
                        .foregroundStyle(cs.onSpace.opacity(0.5))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Sizes.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cs.spaceSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
        .modifier(designSystem.shadow(for: .neoCard))
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
        .frame(width: 96, height: 140)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.sm))
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

    // MARK: - Stats

    private var statsGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Sizes.md), count: 2)
        return LazyVGrid(columns: cols, spacing: DesignSystem.Sizes.md) {
            StatTile(title: "First Published",
                     value: work.firstPublishYear.map(String.init) ?? "—",
                     icon: "calendar", accent: cs.orbitAccent)
            StatTile(title: "Editions",
                     value: work.editionCount.map(String.init) ?? "—",
                     icon: "books.vertical.fill", accent: cs.orbitPrimary)
            StatTile(title: "Language",
                     value: work.language?.first?.uppercased() ?? "—",
                     icon: "globe", accent: cs.distanceSafe)
            StatTile(title: "Access",
                     value: accessLabel,
                     icon: accessIcon, accent: cs.hazard)
        }
    }

    private var accessLabel: String {
        switch work.ebookAccess ?? "" {
        case "readable": return "Readable"
        case "borrowable": return "Borrowable"
        case "no_ebook": return "No ebook"
        default: return work.ebookAccess ?? "—"
        }
    }

    private var accessIcon: String {
        switch work.ebookAccess ?? "" {
        case "readable", "borrowable": return "book"
        default: return "book.closed"
        }
    }

    // MARK: - About

    private func aboutSection(_ description: String) -> some View {
        card(title: "About") {
            Text(description)
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.8))
        }
    }

    // MARK: - Subjects

    private func subjectsSection(_ subjects: [String]) -> some View {
        let trimmed = Array(subjects.prefix(24))
        return card(title: "Subjects") {
            FlexibleChips(items: trimmed, cs: cs, labelFont: designSystem.types.labelSmall)
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

// MARK: - Wrapping chip row (subjects)

/// A simple wrapping layout of pill chips. Feature-local to the book detail.
private struct FlexibleChips: View {
    let items: [String]
    let cs: ColorScheme
    let labelFont: Font

    private let rows = Array(repeating: GridItem(.adaptive(minimum: 80), spacing: 6), count: 1)

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(labelFont)
                    .foregroundStyle(cs.onSpace.opacity(0.8))
                    .padding(.horizontal, DesignSystem.Sizes.sm)
                    .padding(.vertical, 4)
                    .background(cs.onSpace.opacity(0.08))
                    .clipShape(Capsule())
                    .lineLimit(1)
            }
        }
    }
}

//
//  ForexMarketsTab.swift
//  MiniPi
//
//  The Markets tab: a segmented control (Majors / Minors / Exotics) over the curated
//  pair lists, each row showing a live rate. Tap a row to open the detail sheet. Rates
//  load on segment selection and are one-shot per segment (mirrors the one-shot lookup
//  pattern).
//

import SwiftUI

struct ForexMarketsTab: View {
    @ObservedObject var viewModel: ForexViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            VStack(spacing: DesignSystem.Sizes.md) {
                segmentedBar
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.top, DesignSystem.Sizes.md)

                content
            }

            if let failure = viewModel.marketsFailure {
                ErrorSnackbar(failure: failure, onDismiss: { viewModel.marketsFailure = nil })
                    .padding(.bottom, 56)
            }
        }
        .task {
            await viewModel.loadMarkets(force: false)
        }
    }

    // MARK: - Segmented control

    private var segmentedBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Sizes.sm) {
                ForEach(ForexSegment.allCases) { segment in
                    Chip(
                        label: segment.title,
                        icon: segment.icon,
                        isSelected: viewModel.selectedSegment == segment,
                        action: { viewModel.selectSegment(segment) }
                    )
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoadingMarkets && viewModel.marketsQuotes.isEmpty {
            Spacer()
            ProgressView().tint(cs.orbitPrimary)
            Spacer()
        } else if viewModel.marketsQuotes.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: DesignSystem.Sizes.sm) {
                    ForEach(viewModel.marketsQuotes) { item in
                        ForexRow(item: item) {
                            viewModel.openDetail(item.pair)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Sizes.md)
                .padding(.bottom, DesignSystem.Sizes.xxl)
            }
            .refreshable { await viewModel.loadMarkets(force: true) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: viewModel.selectedSegment.icon)
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text("No \(viewModel.selectedSegment.title.lowercased()) available")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            if viewModel.marketsFailure != nil {
                Button("Retry") { Task { await viewModel.loadMarkets(force: true) } }
                    .font(designSystem.types.labelLarge)
                    .foregroundStyle(cs.orbitPrimary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

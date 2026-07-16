//
//  EarthquakeHomeTab.swift
//  MiniPi
//
//  The Home tab of the earthquake screen set. Built on the shared PageScaffold
//  (header + responsive ScrollView), mirroring AsteroidHomeTab. Loading / error /
//  refresh states wrap PageScaffold since they are feature-specific. Error routing
//  follows the same severity rules (critical + no cache → full ErrorView; warning
//  with cached data → non-blocking snackbar).
//

import SwiftUI

struct EarthquakeHomeTab: View {
    @ObservedObject var viewModel: EarthquakeViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    @State private var detailEarthquake: Earthquake?

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            if isLoadingCritical {
                ErrorView(failure: viewModel.currentFailure!,
                          onRetry: { Task { await viewModel.loadFeed(force: true) } })
            } else if viewModel.isLoading && viewModel.earthquakes.isEmpty {
                ProgressView().tint(cs.orbitPrimary)
            } else {
                PageScaffold(
                    title: "USGS Earthquakes",
                    mobile: { AnyView(dashboardContent(columns: 2)) },
                    tablet: { AnyView(dashboardContent(columns: 4)) },
                    background: cs.space,
                    onRefresh: { await viewModel.loadFeed(force: true) }
                )
            }

            if showsSnackbar, let failure = viewModel.currentFailure {
                ErrorSnackbar(failure: failure, onDismiss: { viewModel.clearError() })
                    .padding(.bottom, 56)
            }
        }
        .sheet(item: $detailEarthquake) { quake in
            EarthquakeDetailSheet(
                earthquake: quake,
                isSaved: viewModel.isSaved(quake),
                onToggleSaved: { viewModel.toggleSaved(quake) }
            )
        }
        .task {
            if viewModel.earthquakes.isEmpty && viewModel.currentFailure == nil {
                await viewModel.loadFeed()
            }
        }
    }

    // MARK: - State helpers

    private var isLoadingCritical: Bool {
        guard let failure = viewModel.currentFailure else { return false }
        return failure.severity == .critical && viewModel.earthquakes.isEmpty
    }

    private var showsSnackbar: Bool {
        guard let failure = viewModel.currentFailure else { return false }
        return failure.severity != .critical || !viewModel.earthquakes.isEmpty
    }

    // MARK: - Dashboard content

    @ViewBuilder
    private func dashboardContent(columns: Int) -> some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: DesignSystem.Sizes.lg) {
                greetingRow
                statGrid(columns: columns) {
                    withAnimation { proxy.scrollTo(RecentAnchor.recent, anchor: .top) }
                }
                recentSection
                distributionCard
            }
            .padding(.horizontal, DesignSystem.Sizes.md)
            .padding(.bottom, DesignSystem.Sizes.xxl)
        }
    }

    private var greetingRow: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text(greeting)
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.6))
            LiveDataBadge(source: "USGS")
        }
    }

    private func statGrid(columns: Int, todayAction: @escaping () -> Void) -> some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Sizes.md), count: columns)
        return LazyVGrid(columns: cols, spacing: DesignSystem.Sizes.md) {
            StatTile(title: viewModel.selectedFeed.title,
                     value: "\(viewModel.earthquakes.count)",
                     icon: "calendar") {
                viewModel.openSearch()
            }
            StatTile(title: "Today",
                     value: "\(viewModel.todaysEarthquakes.count)",
                     icon: "sun.max.fill",
                     accent: cs.orbitAccent) {
                todayAction()
            }
            StatTile(title: "Largest",
                     value: viewModel.largestEarthquake?.magnitudeText ?? "—",
                     icon: "waveform",
                     accent: cs.hazard) {
                if let largest = viewModel.largestEarthquake {
                    detailEarthquake = largest
                }
            }
            StatTile(title: "Notable (4.5+)",
                     value: "\(viewModel.significantCount)",
                     icon: "exclamationmark.triangle.fill",
                     accent: cs.distanceDanger) {
                viewModel.openNotableInSearch()
            }
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text("Recent Earthquakes")
                .font(designSystem.types.titleMedium)
                .foregroundStyle(cs.onSpace)
                .id(RecentAnchor.recent)

            if viewModel.recentEarthquakes.isEmpty {
                emptyRecent
            } else {
                VStack(spacing: DesignSystem.Sizes.sm) {
                    ForEach(viewModel.recentEarthquakes) { quake in
                        EarthquakeRow(
                            earthquake: quake,
                            onTap: { detailEarthquake = quake }
                        )
                    }
                }
            }
        }
    }

    /// Weekly magnitude-distribution mini bar chart. Niche to this tab, so it
    /// lives here.
    private var distributionCard: some View {
        let distribution = viewModel.magnitudeDistribution
        let maxCount = max(distribution.map(\.count).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text("Magnitude Distribution")
                .font(designSystem.types.titleSmall)
                .foregroundStyle(cs.onSpace)

            HStack(alignment: .bottom, spacing: DesignSystem.Sizes.sm) {
                ForEach(distribution, id: \.range) { entry in
                    VStack(spacing: DesignSystem.Sizes.xs) {
                        Text("\(entry.count)")
                            .font(designSystem.types.labelSmall)
                            .foregroundStyle(cs.onSpace.opacity(0.6))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(MagnitudeBadge.color(for: entry.band, in: cs))
                            .frame(height: CGFloat(entry.count) / CGFloat(maxCount) * 80)
                        Text(entry.range)
                            .font(designSystem.types.labelSmall)
                            .foregroundStyle(cs.onSpace.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(DesignSystem.Sizes.md)
        .background(cs.spaceSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
        .modifier(designSystem.shadow(for: .neoCard))
    }

    private var emptyRecent: some View {
        VStack(spacing: DesignSystem.Sizes.xs) {
            Text("No recent earthquakes")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(cs.spaceSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }
}

/// Scroll anchor for the "Recent Earthquakes" section (used by the Today tile).
private enum RecentAnchor: Hashable {
    case recent
}

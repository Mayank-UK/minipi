//
//  AsteroidHomeTab.swift
//  MiniPi
//
//  The Home tab of the asteroid screen set. Now built on the shared PageScaffold
//  (header + responsive ScrollView), with a mobile and a tablet layout. The
//  loading / error / refresh states are feature-specific, so they wrap PageScaffold
//  rather than living inside it. Error routing per Module A §A.6.
//

import SwiftUI

struct AsteroidHomeTab: View {
    @ObservedObject var viewModel: AsteroidViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            // Severity routing (§A.6): critical + no cache → full-screen ErrorView.
            if isLoadingCritical {
                ErrorView(failure: viewModel.currentFailure!, onRetry: { Task { await viewModel.loadAsteroids(force: true) } })
            } else if viewModel.isLoading && viewModel.asteroids.isEmpty {
                ProgressView().tint(cs.orbitPrimary)
            } else {
                PageScaffold(
                    title: "NASA NEOs",
                    mobile: {
                        dashboardContent(statColumns: 2, approachColumns: 1)
                    },
                    tablet: {
                        AnyView(dashboardContent(statColumns: 4, approachColumns: 2))
                    },
                    background: cs.space,
                    onRefresh: { await viewModel.loadAsteroids(force: true) }
                )
            }

            // Non-blocking snackbar for warning/info failures while cached data stays visible.
            if showsSnackbar, let failure = viewModel.currentFailure {
                ErrorSnackbar(failure: failure, onDismiss: { viewModel.clearError() })
                    .padding(.bottom, 56)
            }
        }
        .task {
            if viewModel.asteroids.isEmpty && viewModel.currentFailure == nil {
                await viewModel.loadAsteroids()
            }
        }
    }

    // MARK: - State helpers

    private var isLoadingCritical: Bool {
        guard let failure = viewModel.currentFailure else { return false }
        return failure.severity == .critical && viewModel.asteroids.isEmpty
    }

    private var showsSnackbar: Bool {
        guard let failure = viewModel.currentFailure else { return false }
        return failure.severity != .critical || !viewModel.asteroids.isEmpty
    }

    // MARK: - Shared dashboard content (mobile + tablet differ by column counts)

    @ViewBuilder
    private func dashboardContent(statColumns: Int, approachColumns: Int) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.lg) {
            greetingRow
            statGrid(columns: statColumns)
            approachesSection(columns: approachColumns)
            storyCard
        }
        .padding(.horizontal, DesignSystem.Sizes.md)
        .padding(.bottom, DesignSystem.Sizes.xxl)
    }

    private var greetingRow: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text(greeting)
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.6))
            LiveDataBadge()
        }
    }

    private func statGrid(columns: Int) -> some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Sizes.md), count: columns)
        return LazyVGrid(columns: cols, spacing: DesignSystem.Sizes.md) {
            StatTile(title: "This Week", value: "\(viewModel.asteroids.count)", icon: "calendar")
            StatTile(title: "Today", value: "\(viewModel.todaysApproaches.count)", icon: "sun.max.fill", accent: cs.orbitAccent)
            StatTile(title: "Hazardous", value: "\(viewModel.hazardousCount)", icon: "exclamationmark.triangle.fill", accent: cs.hazard)
            StatTile(title: "Closest (LD)",
                     value: viewModel.closestApproach.map { String(format: "%.2f", $0.lunar) } ?? "—",
                     icon: "ruler", accent: cs.distanceSafe)
        }
    }

    @ViewBuilder
    private func approachesSection(columns: Int) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text("Today's Close Approaches")
                .font(designSystem.types.titleMedium)
                .foregroundStyle(cs.onSpace)

            if viewModel.todaysApproaches.isEmpty {
                emptyApproaches
            } else if columns <= 1 {
                VStack(spacing: DesignSystem.Sizes.sm) {
                    ForEach(viewModel.todaysApproaches) { CloseApproachCard(asteroid: $0) }
                }
            } else {
                let cols = Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Sizes.md), count: columns)
                LazyVGrid(columns: cols, spacing: DesignSystem.Sizes.sm) {
                    ForEach(viewModel.todaysApproaches) { CloseApproachCard(asteroid: $0) }
                }
            }
        }
    }

    private var emptyApproaches: some View {
        VStack(spacing: DesignSystem.Sizes.xs) {
            Text("No close approaches today")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            if !viewModel.asteroids.isEmpty {
                Text("Showing the closest in the 7-day window.")
                    .font(designSystem.types.bodySmall)
                    .foregroundStyle(cs.onSpace.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(cs.spaceSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
    }

    private var storyCard: some View {
        HStack(spacing: DesignSystem.Sizes.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius)
                    .fill(cs.orbitPrimary.opacity(0.18))
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: DesignSystem.Sizes.iconLg))
                    .foregroundStyle(cs.orbitPrimary)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text("Planetary Defense")
                    .font(designSystem.types.labelSmall)
                    .foregroundStyle(cs.orbitPrimary)
                Text("Tracking Potentially Hazardous Asteroids")
                    .font(designSystem.types.titleSmall)
                    .foregroundStyle(cs.onSpace)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(DesignSystem.Sizes.md)
        .background(cs.spaceSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
        .modifier(designSystem.shadow(for: .neoCard))
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

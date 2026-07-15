//
//  AsteroidExploreTab.swift
//  MiniPi
//
//  The Explore tab: a 3D, NASA-"Eyes on Asteroids"-style scene where real NEOs
//  revolve along their true orbits. Time scrubber (Live → 7 days/sec), tap a body
//  for a detail card. Loading / error routing per Module A §A.6.
//

import SwiftUI

struct AsteroidExploreTab: View {
    @ObservedObject var viewModel: AsteroidViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            if isCritical {
                ErrorView(failure: viewModel.orbitalFailure!, onRetry: { Task { await viewModel.loadOrbitalAsteroids(force: true) } })
            } else if viewModel.isLoadingOrbital && viewModel.orbitalAsteroids.isEmpty {
                ProgressView().tint(cs.orbitPrimary)
            } else if viewModel.orbitalAsteroids.isEmpty {
                emptyState
            } else {
                scene
                overlays
            }

            if showsSnackbar, let failure = viewModel.orbitalFailure {
                ErrorSnackbar(failure: failure, onDismiss: { viewModel.clearOrbitalError() })
                    .padding(.bottom, 64)
            }
        }
        .task {
            if viewModel.orbitalAsteroids.isEmpty && viewModel.orbitalFailure == nil {
                await viewModel.loadOrbitalAsteroids()
            }
        }
    }

    // MARK: Subviews

    private var scene: some View {
        TimelineView(.animation) { timeline in
            SolarSystemSceneView(
                asteroids: viewModel.orbitalAsteroids,
                date: viewModel.displayedDate(at: timeline.date),
                selectedID: viewModel.selectedAsteroid?.id,
                onSelect: { viewModel.selectAsteroid($0) },
                onSelectPlanet: { viewModel.selectPlanet($0) }
            )
        }
    }

    @ViewBuilder
    private var overlays: some View {
        VStack {
            topBar
            Spacer()
            if viewModel.selectedAsteroid != nil {
                detailCard
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.bottom, DesignSystem.Sizes.sm)
            } else if viewModel.selectedPlanet != nil {
                planetCard
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.bottom, DesignSystem.Sizes.sm)
            }
            TimeScaleScrubber(selected: Binding(
                get: { viewModel.timeScale },
                set: { viewModel.setTimeScale($0) }
            ))
            .padding(.bottom, DesignSystem.Sizes.sm)
        }
    }

    private var topBar: some View {
        HStack {
            LiveDataBadge()
            Spacer()
            Label("\(viewModel.orbitalAsteroids.count)", systemImage: "circle.grid.2x1.fill")
                .font(designSystem.types.labelMedium)
                .foregroundStyle(cs.onSpace.opacity(0.7))
                .padding(.horizontal, DesignSystem.Sizes.sm + DesignSystem.Sizes.xs)
                .padding(.vertical, DesignSystem.Sizes.xs + 2)
                .background(cs.spaceSurface.opacity(0.9))
                .clipShape(Capsule())
        }
        .padding(.horizontal, DesignSystem.Sizes.md)
        .padding(.top, DesignSystem.Sizes.sm)
    }

    @ViewBuilder
    private var detailCard: some View {
        if let asteroid = viewModel.selectedAsteroid {
            VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(asteroid.name)
                            .font(designSystem.types.titleMedium)
                            .foregroundStyle(cs.onSpace)
                        Text("Near Earth Asteroid")
                            .font(designSystem.types.labelMedium)
                            .foregroundStyle(cs.onSpace.opacity(0.6))
                    }
                    Spacer()
                    Button {
                        viewModel.toggleFavorite(asteroid)
                    } label: {
                        Image(systemName: viewModel.isFavorite(asteroid) ? "star.fill" : "star")
                            .font(.system(size: DesignSystem.Sizes.iconSm, weight: .semibold))
                            .foregroundStyle(viewModel.isFavorite(asteroid) ? cs.hazard : cs.onSpace.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    Button {
                        viewModel.selectAsteroid(nil)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: DesignSystem.Sizes.iconSm, weight: .bold))
                            .foregroundStyle(cs.onSpace.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: DesignSystem.Sizes.sm) {
                    HazardBadge(isHazardous: asteroid.isPotentiallyHazardous)
                    if let ld = asteroid.nextCloseApproach?.missDistanceLunar {
                        Label(String(format: "%.2f LD", ld), systemImage: "ruler")
                            .font(designSystem.types.labelMedium)
                            .foregroundStyle(cs.onSpace.opacity(0.7))
                    }
                }

                detailFacts(asteroid)
            }
            .padding(DesignSystem.Sizes.md)
            .background(cs.spaceSurface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
            .modifier(designSystem.shadow(for: .neoCard))
        }
    }

    @ViewBuilder
    private func detailFacts(_ asteroid: Asteroid) -> some View {
        let el = asteroid.orbitalElements
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: DesignSystem.Sizes.sm + DesignSystem.Sizes.xs
        ) {
            fact("Semi-major axis", value: el?.semiMajorAxisAU.map { String(format: "%.2f AU", $0) })
            fact("Eccentricity", value: el?.eccentricity.map { String(format: "%.2f", $0) })
            fact("Orbital period", value: el?.orbitalPeriodDays.map { String(format: "%.0f days", $0) })
            fact("Inclination", value: el?.inclinationDeg.map { String(format: "%.1f°", $0) })
        }
    }

    @ViewBuilder
    private func fact(_ label: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(designSystem.types.labelSmall)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            Text(value ?? "—")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace)
        }
    }

    private struct PlanetInfo { let color: Color; let periodDays: Int; let blurb: String }
    private static let planetInfo: [String: PlanetInfo] = [
        "Mercury": PlanetInfo(color: Color(red: 0.62, green: 0.62, blue: 0.62), periodDays: 88, blurb: "Closest planet to the Sun; small, cratered, no atmosphere."),
        "Venus":   PlanetInfo(color: Color(red: 0.92, green: 0.74, blue: 0.46), periodDays: 225, blurb: "Hottest planet; thick toxic atmosphere, spins backwards."),
        "Earth":   PlanetInfo(color: Color(red: 0.28, green: 0.56, blue: 0.95), periodDays: 365, blurb: "Our home; the reference point for near-Earth objects."),
        "Mars":    PlanetInfo(color: Color(red: 0.86, green: 0.36, blue: 0.22), periodDays: 687, blurb: "The rust-red neighbour; target of asteroid comparison."),
    ]

    @ViewBuilder
    private var planetCard: some View {
        if let name = viewModel.selectedPlanet, let info = Self.planetInfo[name] {
            VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(designSystem.types.titleMedium)
                            .foregroundStyle(cs.onSpace)
                        Text("Reference planet")
                            .font(designSystem.types.labelMedium)
                            .foregroundStyle(cs.onSpace.opacity(0.6))
                    }
                    Spacer()
                    Button {
                        viewModel.selectPlanet(nil)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: DesignSystem.Sizes.iconSm, weight: .bold))
                            .foregroundStyle(cs.onSpace.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: DesignSystem.Sizes.md) {
                    HStack(spacing: DesignSystem.Sizes.xs) {
                        Circle().fill(info.color).frame(width: 10, height: 10)
                        Text("\(info.periodDays)-day orbit")
                    }
                    .font(designSystem.types.labelMedium)
                    .foregroundStyle(cs.onSpace.opacity(0.75))
                }

                Text(info.blurb)
                    .font(designSystem.types.bodySmall)
                    .foregroundStyle(cs.onSpace.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DesignSystem.Sizes.md)
            .background(cs.spaceSurface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
            .modifier(designSystem.shadow(for: .neoCard))
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "circle.grid.3d.fill")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text("No asteroids with orbits to show")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
        }
    }

    // MARK: State helpers

    private var isCritical: Bool {
        guard let failure = viewModel.orbitalFailure else { return false }
        return failure.severity == .critical && viewModel.orbitalAsteroids.isEmpty
    }

    private var showsSnackbar: Bool {
        guard let failure = viewModel.orbitalFailure else { return false }
        return failure.severity != .critical || !viewModel.orbitalAsteroids.isEmpty
    }
}

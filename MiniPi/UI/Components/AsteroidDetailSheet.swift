//
//  AsteroidDetailSheet.swift
//  MiniPi
//
//  Bottom-sheet detail for a single asteroid (Module A §A.10). Shared by the
//  Search and Saved tabs — reuses HazardBadge + the same facts grid as the
//  Explore detail card, plus a save/unsave star.
//

import SwiftUI

struct AsteroidDetailSheet: View {
    let asteroid: Asteroid
    let isFavorite: Bool
    var onToggleFavorite: () -> Void

    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) private var dismiss
    private var cs: ColorScheme { designSystem.colorScheme }

    private var el: OrbitalElements? { asteroid.orbitalElements }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Sizes.md) {
                header

                HStack(spacing: DesignSystem.Sizes.sm) {
                    HazardBadge(isHazardous: asteroid.isPotentiallyHazardous)
                    if asteroid.isSentryObject {
                        Label("Sentry", systemImage: "shield.lefthalf.filled")
                            .font(designSystem.types.labelMedium)
                            .foregroundStyle(cs.orbitAccent)
                    }
                }

                factsGrid
            }
            .padding(DesignSystem.Sizes.md)
        }
        .background(cs.space.ignoresSafeArea())
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .top, spacing: DesignSystem.Sizes.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(asteroid.name)
                    .font(designSystem.types.titleLarge)
                    .foregroundStyle(cs.onSpace)
                Text("Near Earth Asteroid")
                    .font(designSystem.types.labelMedium)
                    .foregroundStyle(cs.onSpace.opacity(0.6))
            }
            Spacer()
            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: DesignSystem.Sizes.iconLg, weight: .semibold))
                    .foregroundStyle(isFavorite ? cs.hazard : cs.onSpace.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
    }

    private var factsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: DesignSystem.Sizes.md
        ) {
            fact("Diameter",
                 value: asteroid.diameterMaxMeters.map { String(format: "%.0f m", $0) })
            fact("Abs. magnitude (H)",
                 value: asteroid.absoluteMagnitudeH.map { String(format: "%.1f", $0) })
            fact("Semi-major axis",
                 value: el?.semiMajorAxisAU.map { String(format: "%.2f AU", $0) })
            fact("Eccentricity",
                 value: el?.eccentricity.map { String(format: "%.2f", $0) })
            fact("Orbital period",
                 value: el?.orbitalPeriodDays.map { String(format: "%.0f days", $0) })
            fact("Inclination",
                 value: el?.inclinationDeg.map { String(format: "%.1f°", $0) })
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Sizes.sm + DesignSystem.Sizes.xs)
        .background(cs.spaceSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
    }
}

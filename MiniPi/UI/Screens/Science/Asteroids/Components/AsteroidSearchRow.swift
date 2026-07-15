//
//  AsteroidSearchRow.swift
//  MiniPi
//
//  A list row for an asteroid — used by the Search and Saved tabs. Shows name,
//  designation, hazard badge, diameter and next-approach distance, with a
//  tappable save/unsave star. Tap the row to open AsteroidDetailSheet.
//

import SwiftUI

struct AsteroidSearchRow: View {
    let asteroid: Asteroid
    let isFavorite: Bool
    var onToggleFavorite: () -> Void
    var onTap: () -> Void

    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    private var approach: CloseApproach? { asteroid.nextCloseApproach }

    private var diameterText: String {
        guard let max = asteroid.diameterMaxMeters else { return "—" }
        if max >= 1000 {
            return String(format: "%.2f km", max / 1000)
        }
        return String(format: "%.0f m", max)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Sizes.md) {
                ZStack {
                    Circle()
                        .fill(cs.orbitAccent.opacity(0.18))
                    Image(systemName: "circle.grid.2x2.fill")
                        .foregroundStyle(asteroid.isPotentiallyHazardous ? cs.hazard : cs.orbitAccent)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(asteroid.name)
                        .font(designSystem.types.titleSmall)
                        .foregroundStyle(cs.onSpace)
                        .lineLimit(1)
                    HStack(spacing: DesignSystem.Sizes.sm) {
                        Label(diameterText, systemImage: "ruler")
                        if let lunar = approach?.missDistanceLunar {
                            Label(String(format: "%.2f LD", lunar), systemImage: "scope")
                        }
                    }
                    .font(designSystem.types.labelMedium)
                    .foregroundStyle(cs.onSpace.opacity(0.6))
                }

                Spacer()

                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.system(size: DesignSystem.Sizes.iconMd, weight: .semibold))
                        .foregroundStyle(isFavorite ? cs.hazard : cs.onSpace.opacity(0.4))
                }
                .buttonStyle(.plain)
                .padding(.leading, DesignSystem.Sizes.sm)
            }
            .padding(DesignSystem.Sizes.md)
            .background(cs.spaceSurface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
            .modifier(designSystem.shadow(for: .neoCard))
        }
        .buttonStyle(.plain)
    }
}

//
//  CloseApproachCard.swift
//  MiniPi
//
//  A row in the Home "Close Approaches" list.
//

import SwiftUI

struct CloseApproachCard: View {
    let asteroid: Asteroid
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    private var approach: CloseApproach? { asteroid.nextCloseApproach }

    /// Prefer the epoch timestamp (carries time-of-day) over the date-only field.
    private var timing: Date? {
        if let ms = approach?.epochDateMs {
            return Date(timeIntervalSince1970: TimeInterval(ms) / 1000.0)
        }
        return approach?.date
    }

    var body: some View {
        HStack(spacing: DesignSystem.Sizes.md) {
            // Thumbnail
            ZStack {
                Circle()
                    .fill(cs.orbitAccent.opacity(0.18))
                Image(systemName: "circle.grid.2x2.fill")
                    .foregroundStyle(asteroid.isPotentiallyHazardous ? cs.hazard : cs.orbitAccent)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: DesignSystem.Sizes.sm) {
                    Text(asteroid.name)
                        .font(designSystem.types.titleSmall)
                        .foregroundStyle(cs.onSpace)
                        .lineLimit(1)
                    HazardBadge(isHazardous: asteroid.isPotentiallyHazardous)
                }

                HStack(spacing: DesignSystem.Sizes.sm) {
                    if let timing {
                        Label(timing.formatted(date: .omitted, time: .shortened),
                              systemImage: "clock")
                    } else {
                        Label("—", systemImage: "clock")
                    }
                    if let lunar = approach?.missDistanceLunar {
                        Label(String(format: "%.2f LD", lunar), systemImage: "ruler")
                    }
                }
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
}

//
//  StatTile.swift
//  MiniPi
//
//  Generic KPI/stat tile used across dashboard screens (asteroid counts, weather
//  readings, magnitudes, prices, …). Domain-agnostic: styling comes entirely
//  from the MiniPi DesignSystem — no feature-specific colors or text.
//
//  Pass `onTap` to make the tile drill into details; a trailing chevron appears
//  only when the tile is tappable, so non-interactive tiles still read as plain
//  stats.
//

import SwiftUI

struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    var accent: Color? = nil
    var onTap: (() -> Void)? = nil

    @EnvironmentObject var designSystem: DesignSystem

    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        if let onTap {
            Button(action: onTap) {
                card
            }
            .buttonStyle(.plain)
        } else {
            card
        }
    }

    @ViewBuilder
    private var card: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.Sizes.iconMd, weight: .semibold))
                    .foregroundStyle(accent ?? cs.orbitPrimary)

                Spacer()

                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: DesignSystem.Sizes.iconSm, weight: .semibold))
                        .foregroundStyle(cs.onSpace.opacity(0.35))
                }
            }

            Text(value)
                .font(designSystem.types.titleLarge)
                .foregroundStyle(cs.onSpace)

            Text(title)
                .font(designSystem.types.labelMedium)
                .foregroundStyle(cs.onSpace.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Sizes.md)
        .background(cs.spaceSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
        .modifier(designSystem.shadow(for: .neoCard))
        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
    }
}

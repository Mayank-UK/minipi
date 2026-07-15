//
//  AsteroidUIComponents.swift
//  MiniPi
//
//  Small reusable asteroid-section components. All styling comes from the MiniPi
//  DesignSystem (tokens added in Module A §A.11) — no hardcoded colors.
//

import SwiftUI

// MARK: - Stat tile (Home dashboard)

struct StatTile: View {
    let title: String
    let value: String
    let icon: String
    var accent: Color? = nil

    @EnvironmentObject var designSystem: DesignSystem

    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.Sizes.iconMd, weight: .semibold))
                .foregroundStyle(accent ?? cs.orbitPrimary)

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
    }
}

// MARK: - "Live data from NASA" pill

struct LiveDataBadge: View {
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        HStack(spacing: DesignSystem.Sizes.xs) {
            Circle()
                .fill(cs.distanceSafe)
                .frame(width: 7, height: 7)
            Text("Live data from NASA")
                .font(designSystem.types.labelSmall)
                .foregroundStyle(cs.onSpace.opacity(0.75))
        }
        .padding(.horizontal, DesignSystem.Sizes.sm + DesignSystem.Sizes.xs)
        .padding(.vertical, DesignSystem.Sizes.xs + 2)
        .background(cs.orbitPrimary.opacity(0.16))
        .clipShape(Capsule())
    }
}

// MARK: - Hazard badge

struct HazardBadge: View {
    let isHazardous: Bool
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        Group {
            if isHazardous {
                label(text: "Hazardous", icon: "exclamationmark.triangle.fill", color: cs.hazard)
            } else {
                label(text: "Safe", icon: "checkmark.shield.fill", color: cs.distanceSafe)
            }
        }
    }

    private func label(text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(designSystem.types.labelSmall)
        .foregroundStyle(color)
        .padding(.horizontal, DesignSystem.Sizes.sm)
        .padding(.vertical, DesignSystem.Sizes.xxs + 2)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - "Coming soon" placeholder for not-yet-built tabs

struct ComingSoonView: View {
    let title: String
    let icon: String
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        VStack(spacing: DesignSystem.Sizes.md) {
            Image(systemName: icon)
                .font(.system(size: DesignSystem.Sizes.iconXl, weight: .light))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text(title)
                .font(designSystem.types.titleLarge)
                .foregroundStyle(cs.onSpace)
            Text("Coming soon")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

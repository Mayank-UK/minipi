//
//  MagnitudeBadge.swift
//  MiniPi
//
//  Magnitude pill for the earthquake feature — colour-coded by band (micro/minor/
//  moderate/major). Used across Home, Search, Watchlist and the detail sheet, so
//  it lives in global components (mirrors HazardBadge for the asteroid feature).
//

import SwiftUI

struct MagnitudeBadge: View {
    let magnitude: Double?
    var compact: Bool = false

    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    private var band: MagnitudeBand { MagnitudeBand(magnitude: magnitude ?? 0) }

    /// One colour per band, drawn from the existing design tokens (no new colours).
    /// Safe to call from anywhere a `ColorScheme` is available — does NOT read the
    /// environment, so it can be used off the view hierarchy (e.g. from a parent's
    /// computed property) where a throwaway `MagnitudeBadge` would have a nil
    /// `@EnvironmentObject`.
    static func color(for band: MagnitudeBand, in cs: ColorScheme) -> Color {
        switch band {
        case .micro:    return cs.distanceSafe
        case .minor:    return cs.distanceWarn
        case .moderate: return cs.hazard
        case .major:    return cs.distanceDanger
        }
    }

    /// Instance colour — only valid when this view is in the hierarchy (so the
    /// environment is injected). Off-hierarchy callers must use `color(for:in:)`.
    var color: Color { Self.color(for: band, in: cs) }

    var body: some View {
        HStack(spacing: compact ? 2 : DesignSystem.Sizes.xs) {
            Image(systemName: "waveform")
                .font(.system(size: compact ? DesignSystem.Sizes.iconSm - 2 : DesignSystem.Sizes.iconSm,
                              weight: .semibold))
            Text(magnitude.map { String(format: "%.1f", $0) } ?? "—")
        }
        .font(compact ? designSystem.types.labelSmall : designSystem.types.labelMedium)
        .foregroundStyle(color)
        .padding(.horizontal, compact ? DesignSystem.Sizes.sm : DesignSystem.Sizes.sm + DesignSystem.Sizes.xs)
        .padding(.vertical, DesignSystem.Sizes.xxs + 2)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

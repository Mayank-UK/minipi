//
//  Chip.swift
//  MiniPi
//
//  Generic filter-chip primitives used by any screen with a filter row
//  (asteroid search, weather by city, earthquakes by magnitude, …). The
//  surrounding chip-bar composition is feature-specific and lives with each
//  screen; these are just the reusable building blocks.
//

import SwiftUI

/// A tappable filter chip — a button wrapping `ChipLabel`.
struct Chip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        Button(action: action) {
            ChipLabel(label: label, icon: icon, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }
}

/// The visual for a chip — also usable on its own as a `Menu` label.
struct ChipLabel: View {
    let label: String
    let icon: String
    let isSelected: Bool

    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(label)
        }
        .font(designSystem.types.labelMedium)
        .foregroundStyle(isSelected ? cs.hazard : cs.onSpace.opacity(0.75))
        .padding(.horizontal, DesignSystem.Sizes.sm + DesignSystem.Sizes.xs)
        .padding(.vertical, DesignSystem.Sizes.xs + 2)
        .background((isSelected ? cs.hazard : cs.onSpace).opacity(isSelected ? 0.15 : 0.06))
        .clipShape(Capsule())
    }
}

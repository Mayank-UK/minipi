//
//  HazardBadge.swift
//  MiniPi
//
//  Asteroid-specific "Hazardous / Safe" status pill. Tied to asteroid semantics,
//  so it stays with the asteroid feature rather than in global components.
//

import SwiftUI

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

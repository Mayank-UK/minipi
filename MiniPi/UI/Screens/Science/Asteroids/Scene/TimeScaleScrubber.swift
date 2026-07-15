//
//  TimeScaleScrubber.swift
//  MiniPi
//
//  Horizontal preset selector for the scene's time scale (Module A §A.2):
//  Live · 1m/s · 1h/s · 1d/s · 3d/s · 7d/s.
//

import SwiftUI

struct TimeScaleScrubber: View {
    @Binding var selected: AsteroidTimeScale
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Sizes.sm) {
                ForEach(AsteroidTimeScale.allCases, id: \.self) { scale in
                    Button {
                        selected = scale
                    } label: {
                        Text(scale.label)
                            .font(designSystem.types.labelMedium)
                            .foregroundStyle(selected == scale ? cs.onSpace : cs.onSpace.opacity(0.6))
                            .padding(.horizontal, DesignSystem.Sizes.md)
                            .padding(.vertical, DesignSystem.Sizes.sm)
                            .background(selected == scale ? cs.orbitPrimary : cs.spaceSurface)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DesignSystem.Sizes.md)
        }
    }
}

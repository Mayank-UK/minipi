//
//  LiveDataBadge.swift
//  MiniPi
//
//  "Live data from <source>" pill. Generic across any live-API screen — pass the
//  data provider as `source` (e.g. "NASA", "USGS", "OpenWeather").
//

import SwiftUI

struct LiveDataBadge: View {
    let source: String

    init(source: String = "NASA") {
        self.source = source
    }

    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        HStack(spacing: DesignSystem.Sizes.xs) {
            Circle()
                .fill(cs.distanceSafe)
                .frame(width: 7, height: 7)
            Text("Live data from \(source)")
                .font(designSystem.types.labelSmall)
                .foregroundStyle(cs.onSpace.opacity(0.75))
        }
        .padding(.horizontal, DesignSystem.Sizes.sm + DesignSystem.Sizes.xs)
        .padding(.vertical, DesignSystem.Sizes.xs + 2)
        .background(cs.orbitPrimary.opacity(0.16))
        .clipShape(Capsule())
    }
}

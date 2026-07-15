//
//  AsteroidTabBar.swift
//  MiniPi
//
//  Custom bottom tab bar for the asteroid screen set, themed with the space tokens.
//

import SwiftUI

struct AsteroidTabBar: View {
    @Binding var selected: AsteroidTab
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AsteroidTab.allCases, id: \.self) { tab in
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: DesignSystem.Sizes.iconMd, weight: .semibold))
                        Text(tab.title)
                            .font(designSystem.types.labelSmall)
                    }
                    .foregroundStyle(selected == tab ? cs.orbitPrimary : cs.onSpace.opacity(0.45))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Sizes.sm)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Sizes.sm)
        .padding(.bottom, DesignSystem.Sizes.sm)
        .background(cs.spaceSurface.opacity(0.96))
        .overlay(
            Rectangle()
                .fill(cs.onSpace.opacity(0.08))
                .frame(height: 0.5),
            alignment: .top
        )
    }
}

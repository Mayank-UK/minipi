//
//  AboutView.swift
//  MiniPi
//
//  Short placeholder about page.
//

import SwiftUI

struct AboutView: View {
    @StateObject var viewModel: AboutViewModel

    @EnvironmentObject var designSystem: DesignSystem

    var body: some View {
        let cs = designSystem.colorScheme

        PageScaffold(
            title: "About",
            mobile: {
                VStack(spacing: DesignSystem.Sizes.md) {
                    Image(systemName: "globe")
                        .font(.system(size: DesignSystem.Sizes.iconXl))
                        .foregroundStyle(cs.primary)

                    Text("MiniPi")
                        .font(designSystem.types.titleLarge)
                        .foregroundStyle(cs.onBackground)

                    Text("A pocket dashboard for science, finance, AI and more.")
                        .font(designSystem.types.bodyMedium)
                        .foregroundStyle(cs.onBackground.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Sizes.lg)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, DesignSystem.Sizes.xl)
            }
        )
    }
}

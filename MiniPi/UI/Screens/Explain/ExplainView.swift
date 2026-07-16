//
//  ExplainView.swift
//  MiniPi
//
//  Intentionally empty for now. Over time this page will document how each
//  feature in the app works (asteroids, weather, finance, etc.).
//

import SwiftUI

struct ExplainView: View {
    @StateObject var viewModel: ExplainViewModel

    @EnvironmentObject var designSystem: DesignSystem

    var body: some View {
        let cs = designSystem.colorScheme

        PageScaffold(
            title: "Explain",
            mobile: {
                VStack(spacing: DesignSystem.Sizes.md) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: DesignSystem.Sizes.iconXl))
                        .foregroundStyle(cs.primary)

                    Text("Coming soon")
                        .font(designSystem.types.titleMedium)
                        .foregroundStyle(cs.onBackground)

                    Text("This page will explain how each feature of MiniPi works.")
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

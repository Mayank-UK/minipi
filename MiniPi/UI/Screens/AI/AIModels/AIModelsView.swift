//
//  AIModelsView.swift
//  MiniPi
//
//  Entry point for the OpenRouter-backed AI Models feature. Hosts the screen-set tab
//  shell (Home · Ranking · Search · Compare), mirroring CryptoView. The custom bottom
//  tab bar is themed with the space tokens and niche to this screen, so it lives here
//  rather than as a shared component — exactly like the crypto/forex/stocks shells.
//

import SwiftUI
import FactoryKit

struct AIModelsView: View {
    @StateObject var viewModel: AIModelsViewModel
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var router: Router

    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Group {
                switch viewModel.selectedTab {
                case .home:
                    AIModelsHomeTab(viewModel: viewModel)
                case .ranking:
                    AIModelsRankingTab(viewModel: viewModel)
                case .search:
                    AIModelsSearchTab(viewModel: viewModel)
                case .compare:
                    AIModelsCompareTab(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
        }
        .background(cs.space.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $viewModel.detailModel) { model in
            AIModelDetailView(model: model)
        }
    }

    /// Custom bottom tab bar for the AI Models screen set, themed with the space tokens.
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AIModelsTab.allCases, id: \.self) { tab in
                Button {
                    viewModel.selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: DesignSystem.Sizes.iconMd, weight: .semibold))
                        Text(tab.title)
                            .font(designSystem.types.labelSmall)
                    }
                    .foregroundStyle(viewModel.selectedTab == tab ? cs.orbitPrimary : cs.onSpace.opacity(0.45))
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

    private var topBar: some View {
        HStack {
            Button {
                router.navigateBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: DesignSystem.Sizes.iconMd, weight: .semibold))
                    .foregroundStyle(cs.onSpace.opacity(0.8))
                    .padding(DesignSystem.Sizes.sm)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Sizes.sm)
        .padding(.top, DesignSystem.Sizes.sm)
    }
}

#Preview {
    AIModelsView(viewModel: Container.shared.aiModelsViewModel())
        .environmentObject(DesignSystem(colorScheme: ColorScheme(dark: DarkColors.self, light: LightColors.self)))
        .environmentObject(Router())
}

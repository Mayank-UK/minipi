//
//  AsteroidView.swift
//  MiniPi
//
//  Entry point for Module A — NASA Asteroids. Hosts the screen-set tab shell
//  (Home · 3D · Search · Saved · More). The Home tab is implemented; the others
//  show a themed "coming soon" placeholder until we build them one by one.
//

import SwiftUI
import FactoryKit

struct AsteroidView: View {
    @StateObject var viewModel: AsteroidViewModel
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var router: Router

    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Group {
                switch viewModel.selectedTab {
                case .home:
                    AsteroidHomeTab(viewModel: viewModel)
                case .explore:
                    AsteroidExploreTab(viewModel: viewModel)
                case .search:
                    AsteroidSearchTab(viewModel: viewModel)
                case .favorites:
                    AsteroidFavoritesTab(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            AsteroidTabBar(selected: $viewModel.selectedTab)
        }
        .background(cs.space.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
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
    AsteroidView(viewModel: Container.shared.asteroidViewModel())
        .environmentObject(DesignSystem(colorScheme: ColorScheme(dark: DarkColors.self, light: LightColors.self)))
        .environmentObject(Router())
}

//
//  IndicatorsView.swift
//  MiniPi
//
//  Entry point for the World Bank-backed Indicators feature. Hosts the screen-set tab
//  shell (Home · Ranking · Search · Compare · Stats), mirroring AIModelsView. The custom
//  bottom tab bar is themed with the space tokens and niche to this screen, so it lives
//  here rather than as a shared component — exactly like the ai/crypto/forex/stocks shells.
//

import SwiftUI
import FactoryKit

struct IndicatorsView: View {
    @StateObject var viewModel: IndicatorsViewModel
    @EnvironmentObject var designSystem: DesignSystem
    @EnvironmentObject var router: Router

    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            Group {
                switch viewModel.selectedTab {
                case .home:
                    IndicatorsHomeTab(viewModel: viewModel)
                case .ranking:
                    IndicatorsRankingTab(viewModel: viewModel)
                case .search:
                    IndicatorsSearchTab(viewModel: viewModel)
                case .compare:
                    IndicatorsCompareTab(viewModel: viewModel)
                case .stats:
                    IndicatorsStatsTab(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
        }
        .background(cs.space.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $viewModel.detailCountry) { country in
            CountryDetailView(country: country, viewModel: viewModel)
        }
    }

    /// Custom bottom tab bar for the Indicators screen set, themed with the space tokens.
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(IndicatorsTab.allCases, id: \.self) { tab in
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
    IndicatorsView(viewModel: Container.shared.indicatorsViewModel())
        .environmentObject(DesignSystem(colorScheme: ColorScheme(dark: DarkColors.self, light: LightColors.self)))
        .environmentObject(Router())
}

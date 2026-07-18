//
//  HomeView.swift
//  MiniPi
//

import SwiftUI
import FactoryKit

struct HomeView: View {
    // Injected from the route / app entry point.
    @StateObject var viewModel: HomeViewModel
    @EnvironmentObject var router: Router
    @EnvironmentObject var designSystem: DesignSystem

    @State private var isDrawerOpen = false
    
    @ViewBuilder
    private func sectionTitle(title: String) -> some View {
        HStack {
            Text(title)
                .font(designSystem.types.titleLarge)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(designSystem.colorScheme.onBackground.opacity(0.3))
        }
        .padding(.horizontal, DesignSystem.Sizes.md)
    }

    @ViewBuilder
    private func links(links: [LinkData]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: DesignSystem.Sizes.md) {
                ForEach(links, id: \.self) { link in
                    Button {
                        router.navigateTo(routePath: link.routePath)
                    } label: {
                        
                        Image(link.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: DesignSystem.Sizes.xxl + DesignSystem.Sizes.xl, height: DesignSystem.Sizes.xxl + DesignSystem.Sizes.xxl)
                            .overlay(alignment: .bottomLeading) {
                                ZStack(alignment: .bottomLeading) {
                                    LinearGradient(
                                        colors: [
                                            .clear,
                                            .black.opacity(0.2),
                                            .black.opacity(0.75)
                                        ],
                                        startPoint: .center,
                                        endPoint: .bottom
                                    )

                                    Text(link.title)
                                        .font(designSystem.types.titleMedium)
                                        .foregroundStyle(.white)
                                        .padding(16)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        
                    }
                    .buttonStyle(.plain)
                }
            }.padding(DesignSystem.Sizes.md)
        }
    }

    var body: some View {
        PageScaffold(
            title: "MiniPi",
            mobile: {
                sectionTitle(title: "Science")
                links(links: viewModel.scienceLinks)
                sectionTitle(title: "Finance")
                links(links: viewModel.financeLinks)
                sectionTitle(title: "AI")
                links(links: viewModel.aiLinks)
                sectionTitle(title: "Education")
                links(links: viewModel.educationLinks)
            },
            trailing: {
                AnyView(
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isDrawerOpen = true
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: DesignSystem.Sizes.iconMd, weight: .semibold))
                            .foregroundStyle(designSystem.colorScheme.onBackground)
                            .frame(width: DesignSystem.Sizes.iconLg, height: DesignSystem.Sizes.iconLg)
                    }
                    .buttonStyle(.plain)
                )
            }
        )
        .overlay {
            AppDrawer(isOpen: $isDrawerOpen) { route in
                router.navigateTo(routePath: route)
            }
        }
    }
}


#Preview {
    HomeView(viewModel: Container.shared.homeViewModel())
}

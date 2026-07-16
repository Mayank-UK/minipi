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
        Text(title)
         .font(designSystem.types.titleLarge)
         .frame(maxWidth: .infinity, alignment: .leading)
         .padding(.leading, DesignSystem.Sizes.md)
    }

    @ViewBuilder
    private func links(links: [LinkData]) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: DesignSystem.Sizes.md),
                GridItem(.flexible(), spacing: DesignSystem.Sizes.md)
            ],
            spacing: DesignSystem.Sizes.md
        ) {
            ForEach(links, id: \.self) { link in
                Button {
                    router.navigateTo(routePath: link.routePath)
                } label: {
                    // Rectangle establishes the square frame; the image overlays into it.
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            ZStack(alignment: .bottomLeading) {
                                Image(link.image)
                                    .resizable()
                                    .scaledToFill()

                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.10)],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )
                            }
                        }
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.sm + DesignSystem.Sizes.xs))
                        .modifier(designSystem.shadow(for: .neoCard))
                }
                .buttonStyle(.plain)
            }
        }.padding(DesignSystem.Sizes.md)
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

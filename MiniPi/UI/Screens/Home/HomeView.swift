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
            ForEach(links, id: \.self) {
                link in Button {
                    router.navigateTo(routePath: link.routePath)
                } label: {
                    Image(link.image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.sm + DesignSystem.Sizes.xs))
                }.buttonStyle(.plain)
            }
        }.padding(DesignSystem.Sizes.md)
    }
    
    var body: some View {
        PageScaffold(
            pageTitle: "MiniPi",
            content: {
                sectionTitle(title: "Science")
                links(links: viewModel.links)
            }
        )
    }
}


#Preview {
    HomeView(viewModel: Container.shared.homeViewModel())
}

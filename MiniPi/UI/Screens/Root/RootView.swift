//
//  RouterView.swift
//  IosDevelopersGuide
//
//  Created by Mayank Upadhyay on 01/03/24.
//

import SwiftUI
import Combine

struct RootView<InitialView: View>: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @StateObject private var designSystem = DesignSystem(
        colorScheme: ColorScheme(dark: DarkColors.self, light: LightColors.self)
    )
    @StateObject var screenData: ScreenData = ScreenData()
    @StateObject var router: Router = Router()
        
    private let initialView: InitialView
    
    init(@ViewBuilder content: @escaping () -> InitialView) {
        self.initialView = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            NavigationStack(path: $router.navigationStack) {
                initialView
                    .navigationDestination(for: Router.routePaths.self) { route in
                    router.view(for: route)
                }
                    
            }
                .preference(key: SizePreferenceKey.self, value: geometry.size)
                .onPreferenceChange(SizePreferenceKey.self) { newSize in
                    screenData.height = newSize.height
                    screenData.width = newSize.width
                    
                    screenData.isCompactHeight = verticalSizeClass == .compact
                    screenData.isCompactWidth = horizontalSizeClass == .compact
                }
        }
        
            .onChange(of: colorScheme) {
                let colorScheme = ColorScheme(dark: DarkColors.self, light: LightColors.self)
                designSystem.updateColorScheme(colorScheme)
            }
            .environmentObject(designSystem)
            .environmentObject(screenData)
            .environmentObject(router)
    }
}

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = CGSize.init(width: 1, height: 1)

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

//#Preview {
//    RootView {
//        HomeView()
//    }
//}

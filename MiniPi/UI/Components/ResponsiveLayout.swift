//
//  ResponsiveLayout.swift
//  MiniPi
//
//  Mirrors the flutter_developers_guide ResponsiveLayout: pick one of three
//  layouts by width. Breakpoints match the Flutter project (600 / 1100).
//

import SwiftUI

enum ResponsiveBreakpoint {
    static let tablet: CGFloat = 600
    static let desktop: CGFloat = 1100
}

struct ResponsiveLayout<Mobile: View, Tablet: View, Desktop: View>: View {

    @ViewBuilder private let mobileLayout: () -> Mobile
    @ViewBuilder private let tabletLayout: () -> Tablet
    @ViewBuilder private let desktopLayout: () -> Desktop

    @State private var width: CGFloat = .zero

    init(
        @ViewBuilder mobileLayout: @escaping () -> Mobile,
        @ViewBuilder tabletLayout: @escaping () -> Tablet,
        @ViewBuilder desktopLayout: @escaping () -> Desktop
    ) {
        self.mobileLayout = mobileLayout
        self.tabletLayout = tabletLayout
        self.desktopLayout = desktopLayout
    }

    var body: some View {
        currentLayout
            .frame(maxWidth: .infinity, alignment: .top)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { newWidth in
                guard newWidth != width else { return }
                width = newWidth
            }
    }

    @ViewBuilder private var currentLayout: some View {
        if width >= ResponsiveBreakpoint.desktop {
            desktopLayout()
        } else if width >= ResponsiveBreakpoint.tablet {
            tabletLayout()
        } else {
            mobileLayout()
        }
    }
}

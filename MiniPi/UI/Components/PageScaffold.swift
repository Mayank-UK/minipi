//
//  PageScaffold.swift
//  MiniPi
//
//  Faithful port of the flutter_developers_guide PageScaffold: owns the page header
//  (in-body, themed from the DesignSystem) and wraps the body in a ScrollView +
//  ResponsiveLayout so each screen supplies mobile / tablet / desktop layouts.
//  tablet/desktop fall back to mobile when omitted — exactly like the Flutter version.
//

import SwiftUI

struct PageScaffold: View {

    let title: String

    private let mobileContent: () -> AnyView
    private let tabletContent: () -> AnyView
    private let desktopContent: () -> AnyView
    private let background: Color?
    private let onRefresh: (() async -> Void)?

    @EnvironmentObject var designSystem: DesignSystem

    init<T: View>(
        title: String,
        @ViewBuilder mobile: @escaping () -> T,
        tablet: (() -> AnyView)? = nil,
        desktop: (() -> AnyView)? = nil,
        background: Color? = nil,
        onRefresh: (() async -> Void)? = nil
    ) {
        self.title = title
        let mobileErased: () -> AnyView = { AnyView(mobile()) }
        self.mobileContent = mobileErased
        self.tabletContent = tablet ?? mobileErased
        self.desktopContent = desktop ?? mobileErased
        self.background = background
        self.onRefresh = onRefresh
    }

    var body: some View {
        let cs = designSystem.colorScheme
        let pageBackground = background ?? cs.background

        VStack(spacing: 0) {
            header(cs: cs)

            ScrollView(.vertical) {
                ResponsiveLayout(
                    mobileLayout: { mobileContent() },
                    tabletLayout: { tabletContent() },
                    desktopLayout: { desktopContent() }
                )
                .padding(.top, DesignSystem.Sizes.lg)
            }
            .modifier(RefreshableModifier(onRefresh: onRefresh))
        }
        .background(pageBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private func header(cs: ColorScheme) -> some View {
        HStack {
            Text(title)
                .font(designSystem.types.headlineSmall)
                .foregroundStyle(cs.onBackground)
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Sizes.md)
        .padding(.top, DesignSystem.Sizes.sm)
        .padding(.bottom, DesignSystem.Sizes.sm)
        .background(cs.surface)
    }
}

/// Applies `.refreshable` only when a refresh handler is supplied, so screens
/// that don't need pull-to-refresh pay nothing for it.
private struct RefreshableModifier: ViewModifier {
    let onRefresh: (() async -> Void)?

    func body(content: Content) -> some View {
        if let onRefresh {
            content.refreshable { await onRefresh() }
        } else {
            content
        }
    }
}

#Preview {
    PageScaffold(title: "Test", mobile: {
        Text("Hello world!")
    })
    .environmentObject(DesignSystem(colorScheme: ColorScheme(dark: DarkColors.self, light: LightColors.self)))
}

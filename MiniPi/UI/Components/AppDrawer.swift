//
//  AppDrawer.swift
//  MiniPi
//
//  A reusable slide-in navigation drawer. Currently surfaced on the home page;
//  hosts the in-app appearance switch plus links to the Explain and About pages.
//

import SwiftUI

struct AppDrawer: View {

    /// Drives the open/closed animation. Owned by the host screen.
    @Binding var isOpen: Bool

    /// Invoked with a destination route when a drawer link is tapped. The drawer
    /// closes itself before calling back.
    let onNavigate: (Router.routePaths) -> Void

    @EnvironmentObject private var designSystem: DesignSystem
    @EnvironmentObject private var appearance: AppearanceManager

    /// Drawer panel width.
    private let panelWidth: CGFloat = 300

    var body: some View {
        ZStack(alignment: .leading) {
            // Dimmed backdrop — tap to dismiss. Only interactive while open so it
            // never swallows touches from the screen underneath when closed.
            Color.black
                .opacity(isOpen ? 0.45 : 0)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { close() }
                .allowsHitTesting(isOpen)
                .accessibilityHidden(!isOpen)

            panel
                .frame(width: panelWidth, alignment: .leading)
                .background(designSystem.colorScheme.surface)
                .foregroundStyle(designSystem.colorScheme.onSurface)
                // Black-based so the shadow reads as depth on both light and dark.
                // A fixed `.gray` (like .navigationMenu) is lighter than the dark
                // surface, which looks like a white halo in dark mode.
                .shadow(color: .black.opacity(0.35), radius: 20, x: 4, y: 0)
                .offset(x: isOpen ? 0 : -panelWidth)
                .allowsHitTesting(isOpen)
                .accessibilityHidden(!isOpen)
        }
        .animation(.easeInOut(duration: 0.25), value: isOpen)
    }

    @ViewBuilder
    private var panel: some View {
        let cs = designSystem.colorScheme

        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("MiniPi")
                    .font(designSystem.types.headlineSmall)
                    .foregroundStyle(cs.onSurface)
                Spacer()
                Button {
                    close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: DesignSystem.Sizes.iconMd, weight: .semibold))
                        .foregroundStyle(cs.onSurface)
                        .frame(width: DesignSystem.Sizes.iconLg, height: DesignSystem.Sizes.iconLg)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignSystem.Sizes.md)
            .padding(.top, DesignSystem.Sizes.lg)
            .padding(.bottom, DesignSystem.Sizes.md)

            Divider().background(cs.onSurface.opacity(0.15))

            // Appearance switch
            VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
                Text("Appearance")
                    .font(designSystem.types.titleSmall)
                    .foregroundStyle(cs.onSurface.opacity(0.7))

                Picker("Appearance", selection: $appearance.preference) {
                    ForEach(AppearancePreference.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, DesignSystem.Sizes.md)
            .padding(.top, DesignSystem.Sizes.md)
            .padding(.bottom, DesignSystem.Sizes.md)

            Divider().background(cs.onSurface.opacity(0.15))

            // Navigation links
            linkRow(icon: "text.book.closed", title: "Explain", tint: cs.primary) {
                navigate(to: .explain)
            }
            Divider().background(cs.onSurface.opacity(0.1))
            linkRow(icon: "info.circle", title: "About", tint: cs.primary) {
                navigate(to: .about)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func linkRow(
        icon: String,
        title: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: DesignSystem.Sizes.md) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.Sizes.iconMd))
                    .foregroundStyle(tint)
                    .frame(width: DesignSystem.Sizes.iconLg, alignment: .center)

                Text(title)
                    .font(designSystem.types.bodyLarge)
                    .foregroundStyle(designSystem.colorScheme.onSurface)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: DesignSystem.Sizes.iconSm))
                    .foregroundStyle(designSystem.colorScheme.onSurface.opacity(0.4))
            }
            .contentShape(Rectangle())
            .padding(.horizontal, DesignSystem.Sizes.md)
            .padding(.vertical, DesignSystem.Sizes.md)
        }
        .buttonStyle(.plain)
    }

    private func navigate(to route: Router.routePaths) {
        close()
        // Defer the push until after the dismiss animation starts so the new
        // screen doesn't appear under the closing panel.
        DispatchQueue.main.async {
            onNavigate(route)
        }
    }

    private func close() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isOpen = false
        }
    }
}

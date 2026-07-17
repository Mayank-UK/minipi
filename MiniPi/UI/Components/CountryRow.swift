//
//  CountryRow.swift
//  MiniPi
//
//  A list row for a World Bank country — used by the Indicators Ranking tab, the Home
//  "Top Performers" list, and the Compare picker. Shows the flag, country name, region
//  subtitle, and an optional trailing value for the active indicator; tap to open the
//  country detail sheet. Mirrors AIModelRow/CryptoRow.
//
//  Convention (per minipi.md): there is no Watchlist in the Indicators feature, so rows
//  never show a save star — they always render the detail chevron (or a compare toggle
//  when used inside the Compare picker). (This is the recurring-mistake rule satisfied by
//  construction.)
//

import SwiftUI

struct CountryRow: View {
    let country: Country
    /// Optional trailing value text for the active indicator (e.g. "99.2%"). Omit to hide.
    var valueText: String? = nil
    /// Optional compare toggle shown as a trailing circle button (used by Compare's picker).
    /// Omit (nil) to show the standard detail chevron.
    var compareState: CompareToggleState? = nil
    var onTap: () -> Void

    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    enum CompareToggleState: Equatable {
        case selected
        case available
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Sizes.md) {
                flagBadge

                VStack(alignment: .leading, spacing: 4) {
                    Text(country.name)
                        .font(designSystem.types.titleSmall)
                        .foregroundStyle(cs.onSpace)
                        .lineLimit(1)
                    Text(country.subtitle)
                        .font(designSystem.types.labelMedium)
                        .foregroundStyle(cs.onSpace.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                if let valueText {
                    Text(valueText)
                        .font(designSystem.types.titleSmall)
                        .foregroundStyle(cs.onSpace)
                        .monospacedDigit()
                }

                trailing
            }
            .padding(DesignSystem.Sizes.md)
            .background(cs.spaceSurface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
            .modifier(designSystem.shadow(for: .neoCard))
        }
        .buttonStyle(.plain)
    }

    private var flagBadge: some View {
        ZStack {
            Circle()
                .fill(cs.orbitPrimary.opacity(0.16))
            Text(country.flag)
                .font(.system(size: DesignSystem.Sizes.iconSm))
        }
        .frame(width: 48, height: 48)
    }

    @ViewBuilder
    private var trailing: some View {
        switch compareState {
        case .selected:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: DesignSystem.Sizes.iconMd, weight: .semibold))
                .foregroundStyle(cs.distanceSafe)
                .padding(.leading, DesignSystem.Sizes.sm)
        case .available:
            Image(systemName: "plus.circle")
                .font(.system(size: DesignSystem.Sizes.iconMd, weight: .semibold))
                .foregroundStyle(cs.onSpace.opacity(0.4))
                .padding(.leading, DesignSystem.Sizes.sm)
        case .none:
            Image(systemName: "chevron.right")
                .font(.system(size: DesignSystem.Sizes.iconSm, weight: .semibold))
                .foregroundStyle(cs.onSpace.opacity(0.3))
                .padding(.leading, DesignSystem.Sizes.sm)
        }
    }
}

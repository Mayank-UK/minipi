//
//  AIModelRow.swift
//  MiniPi
//
//  A list row for an AI model — used by the Ranking, Search and Compare tabs. Shows the
//  model name, provider subtitle, and the trailing context-length + prompt-price; tap to
//  open the detail sheet. Mirrors CryptoRow/ForexRow/StocksRow.
//
//  Convention (per minipi.md): there is no Watchlist in the AI Models feature, so rows
//  never show a save star — they always render the detail chevron. (This is the
//  recurring-mistake rule satisfied by construction.)
//

import SwiftUI

struct AIModelRow: View {
    let model: AIModel
    /// Optional compare toggle shown as a trailing circle button (used by Compare's
    /// picker list). Omit (nil) to show the standard detail chevron.
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
                iconBadge

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(designSystem.types.titleSmall)
                        .foregroundStyle(cs.onSpace)
                        .lineLimit(1)
                    HStack(spacing: DesignSystem.Sizes.xs) {
                        Text(model.subtitle)
                            .font(designSystem.types.labelMedium)
                            .foregroundStyle(cs.onSpace.opacity(0.6))
                            .lineLimit(1)
                        if model.isOpenWeight {
                            tag("Open", color: cs.distanceSafe)
                        }
                        if model.isFree {
                            tag("Free", color: cs.orbitAccent)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(model.contextText)
                        .font(designSystem.types.titleSmall)
                        .foregroundStyle(cs.onSpace)
                        .monospacedDigit()
                    Text(model.promptPriceText)
                        .font(designSystem.types.labelMedium)
                        .foregroundStyle(cs.onSpace.opacity(0.6))
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

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(cs.orbitPrimary.opacity(0.16))
            Image(systemName: "cpu")
                .font(.system(size: DesignSystem.Sizes.iconSm, weight: .bold))
                .foregroundStyle(cs.orbitPrimary)
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

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(designSystem.types.labelSmall)
            .foregroundStyle(color)
            .padding(.horizontal, DesignSystem.Sizes.xs + 2)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

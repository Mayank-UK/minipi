//
//  ForexRow.swift
//  MiniPi
//
//  A list row for a quoted currency pair — used by the Home (majors/movers), Markets,
//  Search and Watchlist tabs. Shows the pair label, name, last rate and % change
//  (green/red). Tap the row to open the detail sheet. Mirrors StocksRow.
//
//  Convention (per minipi.md): supply `onToggleSaved` to show a save/remove star; omit
//  it (nil) to show a detail chevron. List rows in Home / Markets / Search / Watchlist
//  pass NO `onToggleSaved` so they render the chevron (saving happens from the detail
//  sheet).
//
//  Rates are POINTS, not money — formatted by quote currency precision (JPY → 3 dp,
//  else 5 dp) via `ForexQuote.rateText`, never a currency symbol.
//

import SwiftUI

struct ForexRow: View {
    let item: ForexQuoteItem
    /// Supply to show a save/remove star; omit (nil) to show a detail chevron.
    var onToggleSaved: (() -> Void)? = nil
    var onTap: () -> Void

    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    private var changeColor: Color {
        item.quote.isUp ? cs.distanceSafe : cs.distanceDanger
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Sizes.md) {
                ZStack {
                    Circle()
                        .fill(cs.orbitPrimary.opacity(0.16))
                    Text(item.pair.base.prefix(1))
                        .font(.system(size: DesignSystem.Sizes.iconSm, weight: .bold))
                        .foregroundStyle(cs.orbitPrimary)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.pair.displaySymbol)
                        .font(designSystem.types.titleSmall)
                        .foregroundStyle(cs.onSpace)
                        .lineLimit(1)
                    Text(item.pair.subtitle)
                        .font(designSystem.types.labelMedium)
                        .foregroundStyle(cs.onSpace.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(item.quote.rateText)
                        .font(designSystem.types.titleSmall)
                        .foregroundStyle(cs.onSpace)
                        .monospacedDigit()
                    Text(item.quote.percentText)
                        .font(designSystem.types.labelMedium)
                        .foregroundStyle(changeColor)
                }

                if let onToggleSaved {
                    Button(action: onToggleSaved) {
                        Image(systemName: "star.fill")
                            .font(.system(size: DesignSystem.Sizes.iconMd, weight: .semibold))
                            .foregroundStyle(cs.hazard)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, DesignSystem.Sizes.sm)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: DesignSystem.Sizes.iconSm, weight: .semibold))
                        .foregroundStyle(cs.onSpace.opacity(0.3))
                        .padding(.leading, DesignSystem.Sizes.sm)
                }
            }
            .padding(DesignSystem.Sizes.md)
            .background(cs.spaceSurface)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
            .modifier(designSystem.shadow(for: .neoCard))
        }
        .buttonStyle(.plain)
    }
}

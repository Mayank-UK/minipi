//
//  StocksRow.swift
//  MiniPi
//
//  A list row for a quoted instrument — used by the Home (indices/movers), Markets,
//  Search and Watchlist tabs. Shows the ticker, description, last price and %
//  change (green/red), with a tappable save/unsave star. Tap the row to open the
//  detail sheet. Mirrors EarthquakeRow / AsteroidSearchRow.
//
//  Convention (per minipi.md): supply `onToggleSaved` to show a save/remove star;
//  omit it (nil) to show a detail chevron.
//

import SwiftUI

struct StocksRow: View {
    let item: StockQuoteItem
    var isSaved: Bool = false
    var currency: String? = nil
    /// Supply to show a save/remove star; omit (nil) to show a detail chevron.
    var onToggleSaved: (() -> Void)? = nil
    var onTap: () -> Void

    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    private var changeColor: Color {
        item.quote.isUp ? cs.distanceSafe : cs.distanceDanger
    }

    /// Indices quote in points, not money — show a plain grouped number (no ₹/$).
    /// Stocks use their currency.
    private var valueText: String {
        if item.symbol.type == .index {
            return StockQuote.formattedPoints(item.quote.current)
        }
        return item.quote.priceText(currency: currency ?? item.symbol.currency)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Sizes.md) {
                ZStack {
                    Circle()
                        .fill(cs.orbitPrimary.opacity(0.16))
                    Image(systemName: item.symbol.type.icon)
                        .font(.system(size: DesignSystem.Sizes.iconMd, weight: .semibold))
                        .foregroundStyle(cs.orbitPrimary)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.symbol.displaySymbol)
                        .font(designSystem.types.titleSmall)
                        .foregroundStyle(cs.onSpace)
                        .lineLimit(1)
                    Text(item.symbol.subtitle)
                        .font(designSystem.types.labelMedium)
                        .foregroundStyle(cs.onSpace.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(valueText)
                        .font(designSystem.types.titleSmall)
                        .foregroundStyle(cs.onSpace)
                    Text(item.quote.percentText)
                        .font(designSystem.types.labelMedium)
                        .foregroundStyle(changeColor)
                }

                if let onToggleSaved {
                    Button(action: onToggleSaved) {
                        Image(systemName: isSaved ? "star.fill" : "star")
                            .font(.system(size: DesignSystem.Sizes.iconMd, weight: .semibold))
                            .foregroundStyle(isSaved ? cs.hazard : cs.onSpace.opacity(0.4))
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

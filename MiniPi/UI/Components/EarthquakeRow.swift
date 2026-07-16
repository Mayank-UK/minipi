//
//  EarthquakeRow.swift
//  MiniPi
//
//  A list row for an earthquake — used by the Home, Search and Watchlist tabs.
//  Shows the magnitude circle (band-coloured), place, time and depth, with a
//  tappable save/unsave star. Tap the row to open EarthquakeDetailSheet. Mirrors
//  AsteroidSearchRow.
//

import SwiftUI

struct EarthquakeRow: View {
    let earthquake: Earthquake
    var isSaved: Bool = false
    /// Supply to show a save/remove star; omit (nil) to show a detail chevron.
    var onToggleSaved: (() -> Void)? = nil
    var onTap: () -> Void

    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    private var bandColor: Color {
        MagnitudeBadge.color(for: earthquake.magnitudeBand, in: cs)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Sizes.md) {
                ZStack {
                    Circle()
                        .fill(bandColor.opacity(0.18))
                    Text(earthquake.magnitudeText)
                        .font(designSystem.types.titleSmall)
                        .foregroundStyle(bandColor)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(earthquake.place ?? earthquake.title ?? "Unknown location")
                        .font(designSystem.types.titleSmall)
                        .foregroundStyle(cs.onSpace)
                        .lineLimit(1)
                    HStack(spacing: DesignSystem.Sizes.sm) {
                        Label(timeText, systemImage: "clock")
                        Label(earthquake.depthText, systemImage: "arrow.down.right")
                    }
                    .font(designSystem.types.labelMedium)
                    .foregroundStyle(cs.onSpace.opacity(0.6))
                }

                Spacer()

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

    private var timeText: String {
        guard let time = earthquake.time else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: time, relativeTo: Date())
    }
}

//
//  EarthquakeDetailSheet.swift
//  MiniPi
//
//  Bottom-sheet detail for a single earthquake. Shared by the Home, Map, Search
//  and Watchlist tabs — reuses MagnitudeBadge + the same facts grid pattern as
//  AsteroidDetailSheet, plus a save/unsave star.
//

import SwiftUI

struct EarthquakeDetailSheet: View {
    let earthquake: Earthquake
    let isSaved: Bool
    var onToggleSaved: () -> Void

    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) private var dismiss
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Sizes.md) {
                header

                HStack(spacing: DesignSystem.Sizes.sm) {
                    MagnitudeBadge(magnitude: earthquake.magnitude)
                    if earthquake.isTsunami {
                        Label("Tsunami", systemImage: "water.waves")
                            .font(designSystem.types.labelMedium)
                            .foregroundStyle(cs.distanceDanger)
                    }
                    if let alert = earthquake.alertLevel {
                        Label("Alert: \(alert.capitalized)", systemImage: "bell.badge.fill")
                            .font(designSystem.types.labelMedium)
                            .foregroundStyle(cs.hazard)
                    }
                }

                factsGrid

                if let url = earthquake.url, let link = URL(string: url) {
                    Link(destination: link) {
                        Label("View on USGS", systemImage: "safari.fill")
                            .font(designSystem.types.labelMedium)
                            .foregroundStyle(cs.orbitPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Sizes.sm)
                            .background(cs.orbitPrimary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
                    }
                }
            }
            .padding(DesignSystem.Sizes.md)
        }
        .background(cs.space.ignoresSafeArea())
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .top, spacing: DesignSystem.Sizes.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(earthquake.place ?? earthquake.title ?? "Unknown location")
                    .font(designSystem.types.titleLarge)
                    .foregroundStyle(cs.onSpace)
                Text(originTimeText)
                    .font(designSystem.types.labelMedium)
                    .foregroundStyle(cs.onSpace.opacity(0.6))
            }
            Spacer()
            Button(action: onToggleSaved) {
                Image(systemName: isSaved ? "star.fill" : "star")
                    .font(.system(size: DesignSystem.Sizes.iconLg, weight: .semibold))
                    .foregroundStyle(isSaved ? cs.hazard : cs.onSpace.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
    }

    private var factsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: DesignSystem.Sizes.md
        ) {
            fact("Magnitude", value: earthquake.magnitudeText)
            fact("Depth", value: earthquake.depthText)
            fact("Latitude",
                 value: earthquake.coordinate.map { String(format: "%.2f°", $0.latitude) })
            fact("Longitude",
                 value: earthquake.coordinate.map { String(format: "%.2f°", $0.longitude) })
            fact("Significance",
                 value: earthquake.significance.map { String($0) })
            fact("Type", value: earthquake.type?.capitalized)
        }
    }

    private var originTimeText: String {
        guard let time = earthquake.time else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: time) + " UTC"
    }

    @ViewBuilder
    private func fact(_ label: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(designSystem.types.labelSmall)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            Text(value ?? "—")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Sizes.sm + DesignSystem.Sizes.xs)
        .background(cs.spaceSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
    }
}

//
//  EarthquakeWatchlistTab.swift
//  MiniPi
//
//  The "Watchlist" tab: saved earthquakes, persisted across launches via
//  EarthquakeWatchlistStore (UserDefaults). Tap a row for detail; tap the star
//  (or swipe) to remove. Mirrors AsteroidFavoritesTab.
//

import SwiftUI

struct EarthquakeWatchlistTab: View {
    @ObservedObject var viewModel: EarthquakeViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    @State private var detailEarthquake: Earthquake?

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            if viewModel.watchlistQuakes.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Sizes.sm) {
                        Text("\(viewModel.watchlistQuakes.count) saved")
                            .font(designSystem.types.labelMedium)
                            .foregroundStyle(cs.onSpace.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(viewModel.watchlistQuakes) { quake in
                            EarthquakeRow(
                                earthquake: quake,
                                isSaved: true,
                                onToggleSaved: { viewModel.removeSaved(id: quake.id) },
                                onTap: { detailEarthquake = quake }
                            )
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel.removeSaved(id: quake.id)
                                } label: {
                                    Label("Remove", systemImage: "star.slash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.vertical, DesignSystem.Sizes.sm)
                }
            }
        }
        .sheet(item: $detailEarthquake) { quake in
            EarthquakeDetailSheet(
                earthquake: quake,
                isSaved: viewModel.isSaved(quake),
                onToggleSaved: { viewModel.toggleSaved(quake) }
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "star")
                .font(.system(size: DesignSystem.Sizes.iconXl, weight: .light))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text("No saved earthquakes")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            Text("Tap the star on any earthquake in Search or Map to save it here.")
                .font(designSystem.types.bodySmall)
                .foregroundStyle(cs.onSpace.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DesignSystem.Sizes.lg)
    }
}

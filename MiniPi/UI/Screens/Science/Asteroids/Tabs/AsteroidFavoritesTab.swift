//
//  AsteroidFavoritesTab.swift
//  MiniPi
//
//  The "Saved" tab (Module A §A.10, screen 5): favorited NEOs, persisted across
//  launches via FavoritesStore (UserDefaults). Tap a row for detail; tap the star
//  (or swipe) to unsave. NEOs only for now — Planets tab deferred.
//

import SwiftUI

struct AsteroidFavoritesTab: View {
    @ObservedObject var viewModel: AsteroidViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    @State private var detailAsteroid: Asteroid?

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            if viewModel.savedAsteroids.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Sizes.sm) {
                        Text("\(viewModel.savedAsteroids.count) saved")
                            .font(designSystem.types.labelMedium)
                            .foregroundStyle(cs.onSpace.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(viewModel.savedAsteroids) { asteroid in
                            AsteroidSearchRow(
                                asteroid: asteroid,
                                isFavorite: true,
                                onToggleFavorite: { viewModel.removeFavorite(id: asteroid.id) },
                                onTap: { detailAsteroid = asteroid }
                            )
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel.removeFavorite(id: asteroid.id)
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
        .sheet(item: $detailAsteroid) { asteroid in
            AsteroidDetailSheet(
                asteroid: asteroid,
                isFavorite: viewModel.isFavorite(asteroid),
                onToggleFavorite: { viewModel.toggleFavorite(asteroid) }
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "star")
                .font(.system(size: DesignSystem.Sizes.iconXl, weight: .light))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text("No saved asteroids")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            Text("Tap the star on any asteroid in Search or Explore to save it here.")
                .font(designSystem.types.bodySmall)
                .foregroundStyle(cs.onSpace.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, DesignSystem.Sizes.lg)
    }
}

//
//  EarthquakeMapTab.swift
//  MiniPi
//
//  The Map tab: earthquakes plotted on a 3D globe (EarthGlobeSceneView), with a
//  floating magnitude legend and a feed-window selector (hour/day/week/month).
//  Tap a marker to open its detail sheet. The legend and selector are niche to
//  this tab, so they live here as private views.
//

import SwiftUI

struct EarthquakeMapTab: View {
    @ObservedObject var viewModel: EarthquakeViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    @State private var detailEarthquake: Earthquake?

    /// Globe markers: cap + filter the feed so the scene stays responsive with a
    /// large month feed (thousands of events would flood SceneKit).
    private var globeQuakes: [Earthquake] {
        viewModel.earthquakes
            .filter { ($0.magnitude ?? 0) >= 2.5 && $0.coordinate != nil }
            .sorted { ($0.magnitude ?? 0) > ($1.magnitude ?? 0) }
            .prefix(300)
            .map { $0 }
    }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            if viewModel.isLoading && viewModel.earthquakes.isEmpty {
                ProgressView().tint(cs.orbitPrimary)
            } else {
                EarthGlobeSceneView(
                    earthquakes: globeQuakes,
                    selectedID: viewModel.selectedEarthquake?.id,
                    onSelect: { quake in
                        viewModel.selectedEarthquake = quake
                        detailEarthquake = quake
                    }
                )
                .ignoresSafeArea()

                VStack {
                    HStack(alignment: .top) {
                        legend
                        Spacer()
                        windowSelector
                    }
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.top, DesignSystem.Sizes.sm)

                    Spacer()

                    if !globeQuakes.isEmpty {
                        Text("\(globeQuakes.count) events shown · mag 2.5+")
                            .font(designSystem.types.labelSmall)
                            .foregroundStyle(cs.onSpace.opacity(0.6))
                            .padding(.horizontal, DesignSystem.Sizes.sm)
                            .padding(.vertical, DesignSystem.Sizes.xs + 2)
                            .background(cs.spaceSurface.opacity(0.85))
                            .clipShape(Capsule())
                            .padding(.bottom, DesignSystem.Sizes.md)
                    }
                }
            }
        }
        .task {
            if viewModel.earthquakes.isEmpty {
                await viewModel.loadFeed()
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

    // MARK: - Niche subviews

    /// Magnitude colour legend. Niche to this tab.
    private var legend: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.xs) {
            ForEach(MagnitudeBand.allCases) { band in
                HStack(spacing: DesignSystem.Sizes.xs) {
                    Circle()
                        .fill(MagnitudeBadge.color(for: band, in: cs))
                        .frame(width: 8, height: 8)
                    Text(band.label)
                        .font(designSystem.types.labelSmall)
                        .foregroundStyle(cs.onSpace.opacity(0.75))
                }
            }
        }
        .padding(DesignSystem.Sizes.sm)
        .background(cs.spaceSurface.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.pillRadius))
    }

    /// Feed window selector (hour/day/week/month). Niche to this tab.
    private var windowSelector: some View {
        Menu {
            Picker("Window", selection: Binding(
                get: { viewModel.selectedFeed },
                set: { viewModel.setFeed($0) }
            )) {
                ForEach(EarthquakeFeed.allCases) { feed in
                    Text(feed.title).tag(feed)
                }
            }
        } label: {
            HStack(spacing: DesignSystem.Sizes.xs) {
                Image(systemName: "calendar")
                Text(viewModel.selectedFeed.title)
                Image(systemName: "chevron.down")
            }
            .font(designSystem.types.labelMedium)
            .foregroundStyle(cs.onSpace.opacity(0.85))
            .padding(.horizontal, DesignSystem.Sizes.sm)
            .padding(.vertical, DesignSystem.Sizes.xs + 2)
            .background(cs.spaceSurface.opacity(0.85))
            .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
    }
}

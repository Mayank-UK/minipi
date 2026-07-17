//
//  IndicatorsCompareTab.swift
//  MiniPi
//
//  The Compare tab: pick 2–4 countries and compare them side by side across the curated
//  indicators. Built as a horizontal scroll of per-country cards (each card shows the same
//  rows, so the eye scans across columns) plus an "+ Add country" card when there is room.
//  The picker is a sheet listing the cached country catalog (client-side search).
//
//  Everything is client-side over the cached catalog — no per-item network calls. Mirrors
//  AIModelsCompareTab.
//

import SwiftUI

struct IndicatorsCompareTab: View {
    @ObservedObject var viewModel: IndicatorsViewModel
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ZStack {
            cs.space.ignoresSafeArea()

            if viewModel.catalog == nil && viewModel.isLoading {
                ProgressView().tint(cs.orbitPrimary)
            } else if viewModel.compareSelection.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .sheet(isPresented: $viewModel.showComparePicker) {
            ComparePickerSheet(viewModel: viewModel)
        }
        .task {
            if viewModel.catalog == nil && viewModel.currentFailure == nil {
                await viewModel.bootstrap()
            }
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Sizes.md) {
                HStack {
                    Text("Comparing \(viewModel.compareSelection.count) of \(viewModel.compareLimit)")
                        .font(designSystem.types.bodyMedium)
                        .foregroundStyle(cs.onSpace.opacity(0.6))
                    Spacer()
                    YearPicker(viewModel: viewModel)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: DesignSystem.Sizes.sm) {
                        ForEach(viewModel.compareSelection) { country in
                            CompareCard(country: country,
                                        indicators: viewModel.catalog?.indicators ?? [],
                                        viewModel: viewModel,
                                        cs: cs,
                                        types: designSystem.types) {
                                viewModel.removeFromCompare(country)
                            }
                        }
                        if viewModel.canAddToCompare {
                            addCard
                        }
                    }
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.bottom, DesignSystem.Sizes.xxl)
                }
            }
            .padding(.top, DesignSystem.Sizes.md)
        }
    }

    private var addCard: some View {
        Button {
            viewModel.showComparePicker = true
        } label: {
            VStack(spacing: DesignSystem.Sizes.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: DesignSystem.Sizes.iconLg))
                    .foregroundStyle(cs.orbitPrimary)
                Text("Add country")
                    .font(designSystem.types.labelLarge)
                    .foregroundStyle(cs.orbitPrimary)
            }
            .frame(width: 220, height: 360)
            .background(cs.spaceSurface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius)
                    .stroke(cs.orbitPrimary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6]))
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "rectangle.split.3x1")
                .font(.system(size: DesignSystem.Sizes.iconXl))
                .foregroundStyle(cs.orbitAccent.opacity(0.8))
            Text("Compare countries side by side")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace.opacity(0.5))
            Text("Pick up to \(viewModel.compareLimit) countries to compare their indicators.")
                .font(designSystem.types.labelSmall)
                .foregroundStyle(cs.onSpace.opacity(0.4))
                .multilineTextAlignment(.center)
            Button {
                viewModel.showComparePicker = true
            } label: {
                Label("Add a country", systemImage: "plus")
                    .font(designSystem.types.labelLarge)
                    .foregroundStyle(cs.orbitPrimary)
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.vertical, DesignSystem.Sizes.sm)
                    .background(cs.orbitPrimary.opacity(0.12))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, DesignSystem.Sizes.sm)
        }
        .padding(.horizontal, DesignSystem.Sizes.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Compare card (one column)

/// A single country's comparison column: flag + name + remove, then one row per curated
/// indicator so values line up across cards. Feature-local to Compare (single consumer).
private struct CompareCard: View {
    let country: Country
    let indicators: [Indicator]
    @ObservedObject var viewModel: IndicatorsViewModel
    let cs: ColorScheme
    let types: FontScheme
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(country.flag)
                        Text(country.name)
                            .font(types.titleSmall)
                            .foregroundStyle(cs.onSpace)
                            .lineLimit(2)
                    }
                    Text(country.region.trimmingCharacters(in: .whitespaces))
                        .font(types.labelMedium)
                        .foregroundStyle(cs.onSpace.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer()
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: DesignSystem.Sizes.iconMd))
                        .foregroundStyle(cs.onSpace.opacity(0.4))
                }
                .buttonStyle(.plain)
            }

            Divider().background(cs.onSpace.opacity(0.1))

            ForEach(indicators) { indicator in
                let value = viewModel.value(for: country.id, indicatorId: indicator.id, year: viewModel.selectedYear)
                row(indicator.name, indicator.formatValue(value))
            }
        }
        .frame(width: 220, alignment: .leading)
        .padding(DesignSystem.Sizes.md)
        .background(cs.spaceSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
        .modifier(ShadowProxy(cs: cs))
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(types.labelSmall)
                .foregroundStyle(cs.onSpace.opacity(0.5))
                .lineLimit(1)
            Text(value)
                .font(types.labelLarge)
                .foregroundStyle(cs.onSpace)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Picker sheet

/// Lists catalog countries (client-side search), toggling them into the compare selection.
private struct ComparePickerSheet: View {
    @ObservedObject var viewModel: IndicatorsViewModel
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) private var dismiss
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        NavigationStack {
            ZStack {
                cs.space.ignoresSafeArea()
                VStack(spacing: DesignSystem.Sizes.md) {
                    searchBar
                        .padding(.horizontal, DesignSystem.Sizes.md)
                        .padding(.top, DesignSystem.Sizes.md)

                    if viewModel.compareCandidates.isEmpty {
                        Spacer()
                        Text("No countries match")
                            .font(designSystem.types.bodyMedium)
                            .foregroundStyle(cs.onSpace.opacity(0.5))
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: DesignSystem.Sizes.sm) {
                                ForEach(viewModel.compareCandidates) { country in
                                    CountryRow(country: country,
                                               compareState: viewModel.canAddToCompare ? .available : nil) {
                                        viewModel.toggleCompare(country)
                                    }
                                }
                            }
                            .padding(.horizontal, DesignSystem.Sizes.md)
                            .padding(.bottom, DesignSystem.Sizes.xxl)
                        }
                    }
                }
            }
            .navigationTitle("Add to Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(cs.space, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(cs.orbitPrimary)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: DesignSystem.Sizes.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(cs.onSpace.opacity(0.5))
            TextField("Search countries…", text: $viewModel.compareQuery)
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onSpace)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !viewModel.compareQuery.isEmpty {
                Button {
                    viewModel.compareQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(cs.onSpace.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignSystem.Sizes.md)
        .padding(.vertical, DesignSystem.Sizes.sm)
        .background(cs.spaceSurface)
        .clipShape(Capsule())
    }
}

/// Bridges the card shadow without re-reading the `DesignSystem` env off a throwaway
/// instance — same rule as the ai/crypto/forex/stocks `ShadowProxy`.
private struct ShadowProxy: ViewModifier {
    let cs: ColorScheme
    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(0.45), radius: 10, x: 0, y: 6)
    }
}

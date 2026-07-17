//
//  CountryDetailView.swift
//  MiniPi
//
//  Detail sheet for a single World Bank country: flag header, a StatTile per curated
//  indicator (the country's latest value), and a general-info card (region, income level,
//  capital, code). The catalog already carries the country's values, so this view is
//  instant (no sub-fetch) — same rule as AIModelDetailView. Presented as a `.sheet` from
//  IndicatorsView. Feature-local (single consumer).
//

import SwiftUI

struct CountryDetailView: View {
    let country: Country
    @ObservedObject var viewModel: IndicatorsViewModel
    @EnvironmentObject var designSystem: DesignSystem
    @Environment(\.dismiss) private var dismiss

    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        NavigationStack {
            ZStack {
                cs.space.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Sizes.md) {
                        header
                        statsGrid
                        generalCard
                    }
                    .padding(.horizontal, DesignSystem.Sizes.md)
                    .padding(.bottom, DesignSystem.Sizes.xxl)
                }
            }
            .navigationTitle("Country")
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

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.xs) {
            HStack(alignment: .top, spacing: DesignSystem.Sizes.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.Sizes.sm)
                        .fill(cs.orbitPrimary.opacity(0.16))
                    Text(country.flag)
                        .font(.system(size: DesignSystem.Sizes.iconMd))
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(country.name)
                        .font(designSystem.types.titleLarge)
                        .foregroundStyle(cs.onSpace)
                    Text(country.id)
                        .font(designSystem.types.bodyMedium)
                        .foregroundStyle(cs.onSpace.opacity(0.6))
                }
                Spacer()
            }
        }
        .padding(DesignSystem.Sizes.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cs.spaceSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
        .modifier(designSystem.shadow(for: .neoCard))
    }

    // MARK: - Stat tiles (one per curated indicator)

    private var statsGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Sizes.md), count: 2)
        return LazyVGrid(columns: cols, spacing: DesignSystem.Sizes.md) {
            ForEach(viewModel.catalog?.indicators ?? []) { indicator in
                let value = viewModel.value(for: country.id, indicatorId: indicator.id)
                StatTile(
                    title: indicator.name,
                    value: indicator.formatValue(value),
                    icon: indicator.category.icon,
                    accent: cs.orbitPrimary
                )
            }
        }
    }

    // MARK: - General info

    private var generalCard: some View {
        card(title: "General Information") {
            VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
                infoRow("Region", country.region)
                infoRow("Income Level", country.incomeLevel)
                infoRow("Capital", country.capital)
                infoRow("Code", country.id)
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(designSystem.types.labelMedium)
                .foregroundStyle(cs.onSpace.opacity(0.6))
                .frame(width: 112, alignment: .leading)
            Text(value)
                .font(designSystem.types.labelLarge)
                .foregroundStyle(cs.onSpace)
            Spacer()
        }
    }

    @ViewBuilder
    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            Text(title)
                .font(designSystem.types.titleSmall)
                .foregroundStyle(cs.onSpace)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Sizes.md)
        .background(cs.spaceSurface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
        .modifier(designSystem.shadow(for: .neoCard))
    }
}

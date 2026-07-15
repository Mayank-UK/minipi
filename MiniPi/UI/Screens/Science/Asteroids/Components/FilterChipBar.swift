//
//  FilterChipBar.swift
//  MiniPi
//
//  Chip row for the Search tab (Module A §A.10, screen 4): a hazardous toggle,
//  a min-diameter segmented picker, and a sort picker. Styled like the rest of
//  the asteroid section (space-surface capsules).
//

import SwiftUI

struct FilterChipBar: View {
    @Binding var filters: SearchFilters
    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Sizes.sm) {
                Chip(
                    label: "Hazardous",
                    icon: "exclamationmark.triangle.fill",
                    isSelected: filters.hazardousOnly
                ) { filters.hazardousOnly.toggle() }

                Menu {
                    Picker("Minimum size", selection: $filters.minDiameterBucket) {
                        ForEach(AsteroidMinDiameter.allCases) { bucket in
                            Text(bucket.label).tag(bucket)
                        }
                    }
                } label: {
                    ChipLabel(
                        label: filters.minDiameterBucket.label,
                        icon: "circle.dashed",
                        isSelected: filters.minDiameterBucket != .any
                    )
                }
                .menuStyle(.borderlessButton)

                Menu {
                    Picker("Sort by", selection: $filters.sortBy) {
                        ForEach(AsteroidSort.allCases) { sort in
                            Label(sort.label, systemImage: sort.icon).tag(sort)
                        }
                    }
                } label: {
                    ChipLabel(
                        label: filters.sortBy.label,
                        icon: "arrow.up.arrow.down",
                        isSelected: false
                    )
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.horizontal, DesignSystem.Sizes.md)
        }
    }

    // MARK: - Chips

    private struct Chip: View {
        let label: String
        let icon: String
        let isSelected: Bool
        let action: () -> Void
        @EnvironmentObject var designSystem: DesignSystem
        private var cs: ColorScheme { designSystem.colorScheme }

        var body: some View {
            Button(action: action) {
                ChipLabel(label: label, icon: icon, isSelected: isSelected)
            }
            .buttonStyle(.plain)
        }
    }

    private struct ChipLabel: View {
        let label: String
        let icon: String
        let isSelected: Bool
        @EnvironmentObject var designSystem: DesignSystem
        private var cs: ColorScheme { designSystem.colorScheme }

        var body: some View {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(label)
            }
            .font(designSystem.types.labelMedium)
            .foregroundStyle(isSelected ? cs.hazard : cs.onSpace.opacity(0.75))
            .padding(.horizontal, DesignSystem.Sizes.sm + DesignSystem.Sizes.xs)
            .padding(.vertical, DesignSystem.Sizes.xs + 2)
            .background((isSelected ? cs.hazard : cs.onSpace).opacity(isSelected ? 0.15 : 0.06))
            .clipShape(Capsule())
        }
    }
}

//
//  ExplainView.swift
//  MiniPi
//
//  Documents how every feature in the app is implemented — providers & endpoints,
//  DTOs, repositories, use cases, persistence, and the algorithms/3D scenes
//  behind each screen. All detail lives in ExplainContent.swift as typed blocks;
//  this file just renders them.
//

import SwiftUI

struct ExplainView: View {
    @StateObject var viewModel: ExplainViewModel

    @EnvironmentObject var designSystem: DesignSystem

    @State private var expanded: Set<String> = []

    var body: some View {
        let cs = designSystem.colorScheme
        let sections = ExplainContent.sections(cs: cs)

        PageScaffold(
            title: "Explain",
            mobile: {
                VStack(alignment: .leading, spacing: DesignSystem.Sizes.md) {
                    introCard(cs: cs)
                    ForEach(sections) { section in
                        SectionCard(
                            section: section,
                            cs: cs,
                            isExpanded: expanded.contains(section.id),
                            onToggle: { toggle(section.id) }
                        )
                    }
                }
                .padding(.horizontal, DesignSystem.Sizes.md)
                .padding(.bottom, DesignSystem.Sizes.xxl)
            }
        )
    }

    private func toggle(_ id: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expanded.contains(id) {
                expanded.remove(id)
            } else {
                expanded.insert(id)
            }
        }
    }

    @ViewBuilder
    private func introCard(cs: ColorScheme) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
            HStack(spacing: DesignSystem.Sizes.sm) {
                Image(systemName: "text.book.closed.fill")
                    .font(.system(size: DesignSystem.Sizes.iconLg))
                    .foregroundStyle(cs.primary)
                Text("How MiniPi is built")
                    .font(designSystem.types.titleMedium)
                    .foregroundStyle(cs.onBackground)
            }
            Text("Tap any section to drill into the provider, endpoints, DTOs, repositories, use cases, persistence and the algorithms or 3D scenes behind it. Every feature is a Clean Architecture slice (Data → Domain → UI) that shares one networking engine and one Result/Failure error model.")
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onBackground.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Sizes.md)
        .background(cs.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
        .modifier(designSystem.shadow(for: .neoCard))
    }
}

// MARK: - Section card

private struct SectionCard: View {
    let section: ExplainSection
    let cs: ColorScheme
    let isExpanded: Bool
    let onToggle: () -> Void

    @EnvironmentObject var designSystem: DesignSystem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: DesignSystem.Sizes.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DesignSystem.Sizes.pillRadius)
                            .fill(section.accent.opacity(0.16))
                        Image(systemName: section.icon)
                            .font(.system(size: DesignSystem.Sizes.iconMd))
                            .foregroundStyle(section.accent)
                    }
                    .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title)
                            .font(designSystem.types.titleSmall)
                            .foregroundStyle(cs.onBackground)
                        Text(section.subtitle)
                            .font(designSystem.types.bodySmall)
                            .foregroundStyle(cs.onBackground.opacity(0.55))
                            .lineLimit(isExpanded ? 2 : 1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: DesignSystem.Sizes.iconSm, weight: .semibold))
                        .foregroundStyle(cs.onBackground.opacity(0.4))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .padding(DesignSystem.Sizes.md)
                .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().background(cs.onBackground.opacity(0.08))

                VStack(alignment: .leading, spacing: DesignSystem.Sizes.md) {
                    ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                        BlockView(block: block, cs: cs, designSystem: designSystem)
                    }
                }
                .padding(DesignSystem.Sizes.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(cs.surface)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
        .modifier(designSystem.shadow(for: .neoCard))
    }
}

// MARK: - Block renderers

private struct BlockView: View {
    let block: ExplainBlock
    let cs: ColorScheme
    let designSystem: DesignSystem

    var body: some View {
        switch block {
        case .text(let text):
            Text(text)
                .font(designSystem.types.bodyMedium)
                .foregroundStyle(cs.onBackground.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

        case .bullets(let items):
            VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: DesignSystem.Sizes.sm) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5))
                            .foregroundStyle(cs.primary.opacity(0.7))
                            .frame(width: 10, height: 14, alignment: .center)
                        Text(item)
                            .font(designSystem.types.bodyMedium)
                            .foregroundStyle(cs.onBackground.opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .keyValue(let header, let rows):
            VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
                if !header.isEmpty {
                    Text(header)
                        .font(designSystem.types.labelMedium)
                        .foregroundStyle(cs.primary)
                        .textCase(.uppercase)
                }
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        VStack(spacing: 0) {
                            HStack(alignment: .top, spacing: DesignSystem.Sizes.md) {
                                Text(row.0)
                                    .font(designSystem.types.labelMedium)
                                    .foregroundStyle(cs.onBackground.opacity(0.55))
                                    .frame(width: 110, alignment: .leading)
                                Text(row.1)
                                    .font(designSystem.types.bodyMedium)
                                    .foregroundStyle(cs.onBackground.opacity(0.82))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, DesignSystem.Sizes.sm)
                            if index < rows.count - 1 {
                                Divider().background(cs.onBackground.opacity(0.07))
                            }
                        }
                    }
                }
            }

        case .code(let label, let text):
            VStack(alignment: .leading, spacing: DesignSystem.Sizes.xs) {
                if !label.isEmpty {
                    Text(label)
                        .font(designSystem.types.labelSmall)
                        .foregroundStyle(cs.orbitAccent)
                }
                Text(text)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(cs.onBackground.opacity(0.9))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignSystem.Sizes.sm + DesignSystem.Sizes.xs)
                    .background(cs.background.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Sizes.pillRadius)
                            .stroke(cs.onBackground.opacity(0.08), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.pillRadius))
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .flow(let text):
            Text(text)
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(cs.onBackground.opacity(0.85))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignSystem.Sizes.md)
                .background(cs.orbitPrimary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius)
                        .stroke(cs.orbitPrimary.opacity(0.18), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.cardRadius))
                .fixedSize(horizontal: false, vertical: true)

        case .nested(let title, let blocks):
            VStack(alignment: .leading, spacing: DesignSystem.Sizes.sm) {
                HStack(spacing: DesignSystem.Sizes.sm) {
                    Image(systemName: "square.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(cs.orbitAccent.opacity(0.8))
                    Text(title)
                        .font(designSystem.types.titleSmall)
                        .foregroundStyle(cs.onBackground)
                }
                VStack(alignment: .leading, spacing: DesignSystem.Sizes.md) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, inner in
                        BlockView(block: inner, cs: cs, designSystem: designSystem)
                    }
                }
                .padding(.leading, DesignSystem.Sizes.sm)
            }
        }
    }
}

#Preview {
    ExplainView(viewModel: ExplainViewModel())
        .environmentObject(DesignSystem(colorScheme: ColorScheme(dark: DarkColors.self, light: LightColors.self)))
}

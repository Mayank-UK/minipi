//
//  LibraryRow.swift
//  MiniPi
//
//  A list row for a library work — used by the Home (trending), Search, Ranking and
//  Watchlist tabs. Shows the cover thumbnail, title and author · year. Tap the row to open
//  the detail sheet. Mirrors CryptoRow/ForexRow/StocksRow.
//
//  Convention (per minipi.md): supply `onToggleSaved` to show a save/remove star; omit it
//  (nil) to show a detail chevron. List rows in Home / Search / Ranking / Watchlist pass NO
//  `onToggleSaved` so they render the chevron (saving happens from the detail sheet). An
//  optional `rank` shows a leading number badge (Ranking tab only).
//

import SwiftUI

struct LibraryRow: View {
    let work: LibraryWork
    /// Optional leading rank number (Ranking tab). nil elsewhere.
    var rank: Int? = nil
    /// Supply to show a save/remove star; omit (nil) to show a detail chevron.
    var onToggleSaved: (() -> Void)? = nil
    var onTap: () -> Void

    @EnvironmentObject var designSystem: DesignSystem
    private var cs: ColorScheme { designSystem.colorScheme }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Sizes.md) {
                if let rank {
                    Text("\(rank)")
                        .font(designSystem.types.titleSmall)
                        .foregroundStyle(cs.onSpace.opacity(0.5))
                        .frame(width: 20)
                }

                cover

                VStack(alignment: .leading, spacing: 4) {
                    Text(work.title)
                        .font(designSystem.types.titleSmall)
                        .foregroundStyle(cs.onSpace)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(work.subtitle)
                        .font(designSystem.types.labelMedium)
                        .foregroundStyle(cs.onSpace.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                if let onToggleSaved {
                    Button(action: onToggleSaved) {
                        Image(systemName: "star.fill")
                            .font(.system(size: DesignSystem.Sizes.iconMd, weight: .semibold))
                            .foregroundStyle(cs.hazard)
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

    // MARK: - Cover

    private var cover: some View {
        Group {
            if let url = work.coverURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        coverPlaceholder
                    }
                }
            } else {
                coverPlaceholder
            }
        }
        .frame(width: 44, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Sizes.sm))
    }

    private var coverPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignSystem.Sizes.sm)
                .fill(cs.orbitPrimary.opacity(0.16))
            Image(systemName: "book.closed")
                .font(.system(size: DesignSystem.Sizes.iconMd, weight: .semibold))
                .foregroundStyle(cs.orbitPrimary)
        }
    }
}

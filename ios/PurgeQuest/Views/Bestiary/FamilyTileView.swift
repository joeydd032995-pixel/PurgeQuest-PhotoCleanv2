//
//  FamilyTileView.swift
//  PurgeQuest
//
//  A Bestiary family tile: line icon in the family hue, engraved name, one-line
//  intro, and a "found" count pill, on a card with a tinted border. The
//  spotlight tile (the family of the latest encounter) gets a bolder border and
//  a soft glow.
//

import SwiftUI

struct FamilyTileView: View {
    let family: MonsterFamily
    let discovered: Int
    let total: Int
    var isSpotlight: Bool = false

    private var accent: Color { family.accentColor }
    private var borderOpacity: Double { isSpotlight ? 0.95 : 0.40 }
    private var borderWidth: CGFloat { isSpotlight ? 1.5 : 1.0 }
    private var glowOpacity: Double { isSpotlight ? 0.22 : 0.0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            icon
            titleBlock
            Spacer(minLength: 4)
            countPill
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 208, alignment: .topLeading)
        .background(plate)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        "\(family.displayName). \(family.tagline). \(discovered) of \(total) found"
    }

    private var icon: some View {
        Image(family.iconAssetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(accent)
            .frame(maxWidth: 76, maxHeight: 56, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(family.displayName)
                .font(.dungeonHeader)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Text(family.tagline)
                .font(.footnote)
                .foregroundStyle(Color.textSecondary)
                .lineLimit(2)
        }
    }

    private var countPill: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        return Text("\(discovered) / \(total) found")
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(shape.fill(accent.opacity(0.14)))
    }

    private var plate: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return shape
            .fill(Color.dungeonStone)
            .overlay(shape.fill(accent.opacity(0.07)))
            .overlay(shape.strokeBorder(accent.opacity(borderOpacity), lineWidth: borderWidth))
            .shadow(color: accent.opacity(glowOpacity), radius: 10)
    }
}

//
//  DungeonSurface.swift
//  PurgeQuest
//
//  The app's one panel surface and its one progress bar. Depth comes from a faint sheen along the
//  top edge and a low shadow, never from color, so both palettes and both appearances keep their
//  own character.
//

import SwiftUI

/// Corner radii. Three sizes only: a chip, a card, and the one hero panel a screen may have.
enum DungeonRadius {
    static let chip: CGFloat = 8
    static let card: CGFloat = 12
    static let hero: CGFloat = 16
}

/// The stone panel behind every card. Use it as a background:
/// `.background(DungeonPanelBackground())`, or with `accent:` for a panel that belongs to something
/// (a race, a quest that is done), which tints the border and nothing else.
struct DungeonPanelBackground: View {
    var cornerRadius: CGFloat = DungeonRadius.card
    var accent: Color? = nil
    var fillOpacity: Double = 1
    /// False for small inline chips, which should sit flat on their panel.
    var elevated: Bool = true

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(Color.dungeonStone.opacity(fillOpacity))
            .overlay(
                shape.fill(
                    LinearGradient(
                        colors: [Color.white.opacity(colorScheme == .dark ? 0.045 : 0.35), Color.white.opacity(0)],
                        startPoint: .top, endPoint: .center
                    )
                )
            )
            .overlay(shape.strokeBorder(accent?.opacity(0.45) ?? Color.dungeonAsh, lineWidth: 1))
            .shadow(
                color: Color.black.opacity(elevated ? (colorScheme == .dark ? 0.32 : 0.07) : 0),
                radius: 8, x: 0, y: 3
            )
    }
}

/// A capsule progress bar: a recessed track and a filled run that springs when the value changes.
struct DungeonProgressBar: View {
    /// 0...1; values outside are clamped.
    let value: Double
    var tint: Color = .questAmber
    var height: CGFloat = 8

    private var clamped: Double { min(max(value, 0), 1) }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.dungeonVoid)
                    .overlay(Capsule().strokeBorder(Color.dungeonAsh, lineWidth: 1))
                Capsule()
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.72)], startPoint: .top, endPoint: .bottom))
                    // Any progress at all shows at least a dot, so "started" never reads as "empty".
                    .frame(width: clamped > 0 ? max(height, geometry.size.width * clamped) : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: clamped)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue("\(Int((clamped * 100).rounded())) percent")
    }
}

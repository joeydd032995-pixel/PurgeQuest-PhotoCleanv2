//
//  Color+Theme.swift
//  PurgeQuest
//
//  Adaptive design tokens. Dark is "Verdigris Deep" (green-black vault
//  neutrals, unchanged); Light is "Parchment Gold" (cream canvas, near-black
//  ink, deepened accents). Values live in ThemePalette so contrast is unit
//  tested; the names below are the long-standing ones, so existing views pick
//  up both appearances automatically.
//
//  Two kinds of gold on purpose:
//   - `questAmber` is gold *as an accent*: text, icons and tints. It deepens in
//     Light so it stays legible on cream.
//   - `goldInk` / `LinearGradient.goldPlate` is the brand gold *plate*
//     (buttons, badges, emblem) and looks the same in both appearances.
//  No purple, neon, pastel, or rainbow tones anywhere.
//

import SwiftUI
import UIKit

extension UIColor {
    convenience init(_ rgb: ThemeRGB, alpha: CGFloat = 1) {
        self.init(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: alpha)
    }

    /// A dynamic color that resolves to `pair.light` or `pair.dark` with the
    /// appearance of whatever it is drawn in.
    static func adaptive(_ pair: ThemePair) -> UIColor {
        UIColor { traits in
            UIColor(traits.userInterfaceStyle == .dark ? pair.dark : pair.light)
        }
    }
}

extension Color {
    /// A color that resolves to `pair.light` or `pair.dark` with the current appearance.
    init(_ pair: ThemePair) {
        self.init(uiColor: UIColor.adaptive(pair))
    }

    /// A fixed color, identical in both appearances.
    init(_ rgb: ThemeRGB) {
        self.init(uiColor: UIColor(rgb))
    }

    // Neutrals
    static let dungeonVoid       = Color(ThemePalette.canvas)          // canvas: #0C1512 dark, #F4F4EC light
    static let dungeonStone      = Color(ThemePalette.surface)         // surface
    static let dungeonStoneLight = Color(ThemePalette.surfaceRaised)   // raised surface (a recessed well in Light)
    static let dungeonAsh        = Color(ThemePalette.hairline)        // hairline border

    // Accents (gamified zones only)
    static let questAmber        = Color(ThemePalette.amber)           // treasure gold
    static let questAmberDeep    = Color(ThemePalette.amberDeep)
    static let combatCrimson     = Color(ThemePalette.crimson)         // brick
    static let combatCrimsonDeep = Color(ThemePalette.crimsonDeep)
    static let gemEmerald        = Color(ThemePalette.emerald)         // reward jade
    static let gemEmeraldDeep    = Color(ThemePalette.emeraldDeep)
    /// Arcane accent (verdigris jade). Historic name kept for compatibility.
    static let xpViolet          = Color(ThemePalette.jade)
    static let videoSapphire     = Color(ThemePalette.sapphire)        // steel blue

    // Bestiary family hues
    static let behemothIndigo    = Color(ThemePalette.indigo)
    static let dragonCoral       = Color(ThemePalette.coral)
    static let glitchRose        = Color(ThemePalette.rose)

    // Text
    static let textPrimary       = Color(ThemePalette.textPrimary)
    static let textSecondary     = Color(ThemePalette.textSecondary)
    static let textTertiary      = Color(ThemePalette.textTertiary)

    /// Ink for text/icons on an accent fill (dark on bright dark-mode accents, cream on deep light-mode ones).
    static let onAccent          = Color(ThemePalette.onAccent)
    /// Wordmark and display titles.
    static let goldTitle         = Color(ThemePalette.goldTitle)

    // Brand gold plate: the same in both appearances.
    static let goldInk           = Color(ThemePalette.Gold.ink)
    static let goldRim           = Color(ThemePalette.Gold.rim)
    static let goldBevel         = Color(ThemePalette.Gold.bevel)
    /// Mid-plate gold, for small fills (badges, chips) that need the brand gold.
    static let goldFill          = Color(ThemePalette.Gold.plateStops[2].color)

    /// Edge shading for the canvas: deep shadow in Dark, a faint warm tint in Light.
    static let canvasVignette = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0, alpha: 0.35)
            : UIColor(red: 0.36, green: 0.29, blue: 0.12, alpha: 0.07)
    })
}

extension ShapeStyle where Self == Color {
    static var dungeonVoid: Color       { .dungeonVoid }
    static var dungeonStone: Color      { .dungeonStone }
    static var dungeonStoneLight: Color { .dungeonStoneLight }
    static var dungeonAsh: Color        { .dungeonAsh }
    static var questAmber: Color        { .questAmber }
    static var questAmberDeep: Color    { .questAmberDeep }
    static var combatCrimson: Color     { .combatCrimson }
    static var combatCrimsonDeep: Color { .combatCrimsonDeep }
    static var gemEmerald: Color        { .gemEmerald }
    static var gemEmeraldDeep: Color    { .gemEmeraldDeep }
    static var xpViolet: Color          { .xpViolet }
    static var videoSapphire: Color     { .videoSapphire }
    static var behemothIndigo: Color    { .behemothIndigo }
    static var dragonCoral: Color       { .dragonCoral }
    static var glitchRose: Color        { .glitchRose }
    static var textPrimary: Color       { .textPrimary }
    static var textSecondary: Color     { .textSecondary }
    static var textTertiary: Color      { .textTertiary }
    static var onAccent: Color          { .onAccent }
    static var goldTitle: Color         { .goldTitle }
    static var goldInk: Color           { .goldInk }
}

// Barely-tonal fills only. Harsh glow gradients are gone; these read as flat
// color with a hint of depth for progress fills and framed panels.
extension LinearGradient {
    static let dungeonBackground = LinearGradient(
        colors: [Color(ThemePalette.canvasTop), .dungeonVoid],
        startPoint: .top, endPoint: .bottom
    )
    static let amberGlow = LinearGradient(
        colors: [.questAmber, .questAmberDeep],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let crimsonGlow = LinearGradient(
        colors: [.combatCrimson, .combatCrimsonDeep],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let emeraldGlow = LinearGradient(
        colors: [.gemEmerald, .gemEmeraldDeep],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    /// The brand gold plate (Continue button, badges). Lighter at the top,
    /// bronze at the lower edge, identical in Light and Dark.
    static let goldPlate = LinearGradient(
        stops: ThemePalette.Gold.plateStops.map { Gradient.Stop(color: Color($0.color), location: $0.location) },
        startPoint: .top, endPoint: .bottom
    )
}

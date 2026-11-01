//
//  Color+Theme.swift
//  PurgeQuest
//
//  Adaptive design tokens, resolved along two independent axes:
//    appearance  Light or Dark (follows the system, or the user's choice), and
//    palette     Classic (charcoal / parchment) or Verdigris (green-black / sage),
//                chosen in Settings and published through `ThemeStore`.
//  Values live in ThemePalette so contrast is unit tested; the names below are
//  the long-standing ones, so existing views pick up both axes automatically.
//
//  Two kinds of gold on purpose:
//   - `questAmber` is gold *as an accent*: text, icons and tints. It deepens in
//     Light so it stays legible on light surfaces.
//   - `goldInk` / `LinearGradient.goldPlate` is the brand gold *plate*
//     (buttons, badges, emblem) and looks the same everywhere.
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

/// The palette-dependent colors for one `ColorTheme`, built once so that every
/// read returns the same instance (and UIKit never has to re-resolve a stale one).
private struct ThemeColors {
    let canvas: Color
    let canvasTop: Color
    let surface: Color
    let surfaceRaised: Color
    let hairline: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let onAccent: Color
    let vignette: Color

    init(_ neutrals: ThemeNeutrals) {
        canvas = Color(neutrals.canvas)
        canvasTop = Color(neutrals.canvasTop)
        surface = Color(neutrals.surface)
        surfaceRaised = Color(neutrals.surfaceRaised)
        hairline = Color(neutrals.hairline)
        textPrimary = Color(neutrals.textPrimary)
        textSecondary = Color(neutrals.textSecondary)
        textTertiary = Color(neutrals.textTertiary)
        onAccent = Color(neutrals.onAccent)
        let lightTint = neutrals.lightVignetteTint
        vignette = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0, alpha: 0.35)
                : UIColor(lightTint, alpha: 0.07)
        })
    }

    static let classic = ThemeColors(ThemePalette.classic)
    static let verdigris = ThemeColors(ThemePalette.verdigris)

    /// The palette the user chose (see `ThemeStore`).
    static var current: ThemeColors {
        ThemeStore.shared.current == .verdigris ? verdigris : classic
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

    // Neutrals: these follow the chosen palette as well as the appearance.
    static var dungeonVoid: Color       { ThemeColors.current.canvas }          // canvas
    static var dungeonStone: Color      { ThemeColors.current.surface }         // cards and panels
    static var dungeonStoneLight: Color { ThemeColors.current.surfaceRaised }   // wells (recessed in Light)
    static var dungeonAsh: Color        { ThemeColors.current.hairline }        // hairline border

    // Text
    static var textPrimary: Color       { ThemeColors.current.textPrimary }
    static var textSecondary: Color     { ThemeColors.current.textSecondary }
    static var textTertiary: Color      { ThemeColors.current.textTertiary }

    /// Ink for text/icons on an accent fill (dark on bright dark-mode accents, cream on deep light-mode ones).
    static var onAccent: Color          { ThemeColors.current.onAccent }

    /// Edge shading for the canvas: deep shadow in Dark, a faint tint in Light.
    static var canvasVignette: Color    { ThemeColors.current.vignette }

    // Accents (gamified zones only): shared by every palette.
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

    /// Wordmark and display titles.
    static let goldTitle         = Color(ThemePalette.goldTitle)

    // Brand gold plate: the same in every palette and appearance.
    static let goldInk           = Color(ThemePalette.Gold.ink)
    static let goldRim           = Color(ThemePalette.Gold.rim)
    static let goldBevel         = Color(ThemePalette.Gold.bevel)
    /// Mid-plate gold, for small fills (badges, chips) that need the brand gold.
    static let goldFill          = Color(ThemePalette.Gold.plateStops[2].color)
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
    /// The canvas gradient; follows the chosen palette.
    static var dungeonBackground: LinearGradient {
        let colors = ThemeColors.current
        return LinearGradient(
            colors: [colors.canvasTop, colors.canvas],
            startPoint: .top, endPoint: .bottom
        )
    }
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
    /// bronze at the lower edge, identical in every palette and appearance.
    static let goldPlate = LinearGradient(
        stops: ThemePalette.Gold.plateStops.map { Gradient.Stop(color: Color($0.color), location: $0.location) },
        startPoint: .top, endPoint: .bottom
    )
}

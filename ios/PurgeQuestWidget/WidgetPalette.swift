//
//  WidgetPalette.swift
//  PurgeQuestWidget
//
//  The nine colors the home-screen widgets use, as Light and Dark 0xRRGGBB pairs. They copy the
//  app's Classic palette (ThemePalette.swift). The widget target stays self-contained, so
//  tools/ci/repo_guard.py fails CI if any value drifts from the app's, or loses contrast on the
//  widget backgrounds (canvasTop and surface).
//

import Foundation

/// One color in both appearances.
nonisolated struct WidgetPair: Equatable, Sendable {
    let light: UInt32
    let dark: UInt32
}

nonisolated enum WidgetPalette {
    // Neutrals: ThemePalette.classic
    static let canvasTop     = WidgetPair(light: 0xF9F9F2, dark: 0x141413)
    static let surface       = WidgetPair(light: 0xFBFAF4, dark: 0x2A2927)
    static let hairline      = WidgetPair(light: 0xD9D4C0, dark: 0x45433F)
    static let textPrimary   = WidgetPair(light: 0x1B1B17, dark: 0xF2EFE9)
    static let textSecondary = WidgetPair(light: 0x5A574A, dark: 0xB0ACA3)

    // Accents shared by both app palettes: ThemePalette.amber, .sapphire, .crimson, .emerald
    static let amber    = WidgetPair(light: 0x8A6210, dark: 0xE3B341)
    static let sapphire = WidgetPair(light: 0x2D6A8E, dark: 0x6D9BB5)
    static let crimson  = WidgetPair(light: 0xA93B2E, dark: 0xC45B4E)
    static let emerald  = WidgetPair(light: 0x1F7452, dark: 0x3D9E76)
}

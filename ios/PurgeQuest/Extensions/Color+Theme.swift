//
//  Color+Theme.swift
//  PurgeQuest
//
//  "Iron Vault" design system. Cool steel neutrals form the utility base;
//  dungeon accents are reserved for gamified surfaces. No purple, neon,
//  pastel, or rainbow tones anywhere.
//

import SwiftUI

extension Color {
    // Iron Vault neutrals
    static let dungeonVoid       = Color(red: 0.055, green: 0.063, blue: 0.075)   // canvas #0E1013
    static let dungeonStone      = Color(red: 0.098, green: 0.110, blue: 0.129)   // surface #191C21
    static let dungeonStoneLight = Color(red: 0.133, green: 0.149, blue: 0.176)   // raised surface #22262D
    static let dungeonAsh        = Color(red: 0.169, green: 0.188, blue: 0.220)   // hairline border #2B3038

    // Dungeon accents (gamified zones only)
    static let questAmber        = Color(red: 0.788, green: 0.635, blue: 0.153)   // muted gold #C9A227
    static let questAmberDeep    = Color(red: 0.561, green: 0.451, blue: 0.098)   // deep gold #8F7319
    static let combatCrimson     = Color(red: 0.753, green: 0.333, blue: 0.290)   // brick #C0554A
    static let combatCrimsonDeep = Color(red: 0.494, green: 0.200, blue: 0.173)   // deep brick #7E332C
    static let gemEmerald        = Color(red: 0.369, green: 0.612, blue: 0.463)   // reward green #5E9C76
    static let gemEmeraldDeep    = Color(red: 0.184, green: 0.361, blue: 0.259)   // deep green #2F5C42
    /// Arcane accent (verdigris teal #4E9B8F). Historic name kept for compatibility.
    static let xpViolet          = Color(red: 0.306, green: 0.608, blue: 0.561)
    static let videoSapphire     = Color(red: 0.357, green: 0.529, blue: 0.627)   // steel blue #5B87A0

    // Text
    static let textPrimary       = Color(red: 0.925, green: 0.929, blue: 0.933)   // off-white
    static let textSecondary     = Color(red: 0.604, green: 0.627, blue: 0.659)   // quiet gray
    static let textTertiary      = Color(red: 0.427, green: 0.447, blue: 0.478)
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
    static var textPrimary: Color       { .textPrimary }
    static var textSecondary: Color     { .textSecondary }
    static var textTertiary: Color      { .textTertiary }
}

// Barely-tonal fills only. Harsh glow gradients are gone; these read as flat
// color with a hint of depth for progress fills and framed panels.
extension LinearGradient {
    static let dungeonBackground = LinearGradient(
        colors: [Color(red: 0.043, green: 0.051, blue: 0.063), .dungeonVoid],
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
}

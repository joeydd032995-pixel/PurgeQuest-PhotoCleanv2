//
//  Color+Theme.swift
//  PurgeQuest
//
//  "Verdigris Deep" design system. Green-black vault neutrals form the
//  utility base; dungeon accents are reserved for gamified surfaces.
//  No purple, neon, pastel, or rainbow tones anywhere.
//

import SwiftUI

extension Color {
    // Verdigris Deep neutrals
    static let dungeonVoid       = Color(red: 0.047, green: 0.082, blue: 0.071)   // canvas #0C1512
    static let dungeonStone      = Color(red: 0.078, green: 0.129, blue: 0.110)   // surface #14211C
    static let dungeonStoneLight = Color(red: 0.106, green: 0.165, blue: 0.141)   // raised surface #1B2A24
    static let dungeonAsh        = Color(red: 0.149, green: 0.216, blue: 0.188)   // hairline border #263730

    // Dungeon accents (gamified zones only)
    static let questAmber        = Color(red: 0.890, green: 0.702, blue: 0.255)   // treasure gold #E3B341
    static let questAmberDeep    = Color(red: 0.659, green: 0.498, blue: 0.157)   // deep gold #A87F28
    static let combatCrimson     = Color(red: 0.769, green: 0.357, blue: 0.306)   // brick #C45B4E
    static let combatCrimsonDeep = Color(red: 0.561, green: 0.243, blue: 0.200)   // deep brick #8F3E33
    static let gemEmerald        = Color(red: 0.239, green: 0.620, blue: 0.463)   // reward jade #3D9E76
    static let gemEmeraldDeep    = Color(red: 0.141, green: 0.333, blue: 0.255)   // deep jade #245541
    /// Arcane accent (verdigris jade #4FC49B). Historic name kept for compatibility.
    static let xpViolet          = Color(red: 0.310, green: 0.769, blue: 0.608)
    static let videoSapphire     = Color(red: 0.427, green: 0.608, blue: 0.710)   // steel blue #6D9BB5

    // Text
    static let textPrimary       = Color(red: 0.937, green: 0.949, blue: 0.937)   // off-white
    static let textSecondary     = Color(red: 0.576, green: 0.651, blue: 0.612)   // quiet sage gray
    static let textTertiary      = Color(red: 0.365, green: 0.435, blue: 0.396)
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
        colors: [Color(red: 0.031, green: 0.059, blue: 0.047), .dungeonVoid],
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

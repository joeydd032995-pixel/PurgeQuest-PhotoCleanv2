//
//  Color+Theme.swift
//  PurgeQuest
//

import SwiftUI

extension Color {
    // Dungeon palette - deep, atmospheric
    static let dungeonVoid       = Color(red: 0.04, green: 0.04, blue: 0.06)
    static let dungeonStone      = Color(red: 0.10, green: 0.09, blue: 0.13)
    static let dungeonStoneLight = Color(red: 0.16, green: 0.15, blue: 0.20)
    static let dungeonAsh        = Color(red: 0.22, green: 0.21, blue: 0.27)

    // Accents
    static let questAmber        = Color(red: 1.00, green: 0.74, blue: 0.21)
    static let questAmberDeep    = Color(red: 0.92, green: 0.55, blue: 0.10)
    static let combatCrimson     = Color(red: 0.96, green: 0.24, blue: 0.34)
    static let combatCrimsonDeep = Color(red: 0.62, green: 0.10, blue: 0.18)
    static let gemEmerald        = Color(red: 0.18, green: 0.85, blue: 0.55)
    static let gemEmeraldDeep    = Color(red: 0.06, green: 0.55, blue: 0.36)
    static let xpViolet          = Color(red: 0.62, green: 0.42, blue: 0.95)
    static let videoSapphire     = Color(red: 0.32, green: 0.62, blue: 0.98)

    static let textPrimary       = Color(red: 0.96, green: 0.94, blue: 0.90)
    static let textSecondary     = Color(red: 0.66, green: 0.64, blue: 0.72)
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
}

extension LinearGradient {
    static let dungeonBackground = LinearGradient(
        colors: [.dungeonVoid, .dungeonStone, .dungeonVoid],
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

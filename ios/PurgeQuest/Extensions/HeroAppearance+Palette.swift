//
//  HeroAppearance+Palette.swift
//  PurgeQuest
//
//  Color mapping for the hero identity traits. Grounded naturals plus
//  fantasy jade, ember, and steel-blue tints — no purple, no neon.
//

import SwiftUI

extension SkinTone {
    var color: Color {
        switch self {
        case .moonlit:   return Color(red: 0.96, green: 0.87, blue: 0.74)
        case .sandstone: return Color(red: 0.90, green: 0.74, blue: 0.54)
        case .honey:     return Color(red: 0.83, green: 0.63, blue: 0.42)
        case .umber:     return Color(red: 0.62, green: 0.44, blue: 0.29)
        case .ebony:     return Color(red: 0.42, green: 0.30, blue: 0.21)
        case .jadekin:   return Color(red: 0.62, green: 0.72, blue: 0.66)
        case .ashen:     return Color(red: 0.55, green: 0.57, blue: 0.55)
        }
    }
}

extension EyeColor {
    var color: Color {
        switch self {
        case .bark:     return Color(red: 0.42, green: 0.29, blue: 0.16)
        case .moss:     return Color(red: 0.42, green: 0.55, blue: 0.32)
        case .jade:     return Color(red: 0.24, green: 0.62, blue: 0.46)
        case .ember:    return Color(red: 0.78, green: 0.42, blue: 0.20)
        case .sapphire: return Color(red: 0.35, green: 0.52, blue: 0.63)
        case .slate:    return Color(red: 0.52, green: 0.56, blue: 0.54)
        }
    }
}

extension HairColor {
    var color: Color {
        switch self {
        case .bark:     return Color(red: 0.38, green: 0.26, blue: 0.15)
        case .raven:    return Color(red: 0.19, green: 0.18, blue: 0.19)
        case .wheat:    return Color(red: 0.84, green: 0.72, blue: 0.44)
        case .rust:     return Color(red: 0.60, green: 0.33, blue: 0.19)
        case .jade:     return Color(red: 0.24, green: 0.58, blue: 0.45)
        case .ember:    return Color(red: 0.76, green: 0.36, blue: 0.22)
        case .sapphire: return Color(red: 0.36, green: 0.51, blue: 0.63)
        case .ash:      return Color(red: 0.62, green: 0.64, blue: 0.62)
        }
    }
}

extension GearTier {
    var accent: Color {
        switch self {
        case .standard:  return .dungeonAsh
        case .seasoned:  return .gemEmerald
        case .elite:     return .videoSapphire
        case .legendary: return .questAmber
        case .mythic:    return .xpViolet
        }
    }

    var displayName: String {
        switch self {
        case .standard:  return "Standard"
        case .seasoned:  return "Seasoned"
        case .elite:     return "Elite"
        case .legendary: return "Legendary"
        case .mythic:    return "Mythic"
        }
    }
}

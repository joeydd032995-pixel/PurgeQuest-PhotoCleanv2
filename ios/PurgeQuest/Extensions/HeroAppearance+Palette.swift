//
//  HeroAppearance+Palette.swift
//  PurgeQuest
//
//  Color mapping for the hero identity traits. Grounded naturals plus
//  fantasy jade, ember, and steel-blue tints — no purple, no neon.
//

import SwiftUI

private extension Color {
    /// An opaque sRGB colour from a material colour (the recolor tables in LookRecolor.swift).
    init(_ rgba: MaterialRGBA) {
        self.init(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: 1)
    }
}

extension SkinTone {
    /// The swatch colour; the same table the skin recolor aims for (LookRecolor.swift), so a swatch is exactly what it paints.
    var color: Color { Color(materialRGBA) }
}

extension EyeColor {
    var color: Color {
        switch self {
        case .bark:      return Color(red: 0.42, green: 0.29, blue: 0.16)
        case .moss:      return Color(red: 0.42, green: 0.55, blue: 0.32)
        case .jade:      return Color(red: 0.24, green: 0.62, blue: 0.46)
        case .ember:     return Color(red: 0.78, green: 0.42, blue: 0.20)
        case .sapphire:  return Color(red: 0.35, green: 0.52, blue: 0.63)
        case .slate:     return Color(red: 0.52, green: 0.56, blue: 0.54)
        case .gilded:    return Color(red: 0.82, green: 0.62, blue: 0.24)
        case .verdigris: return Color(red: 0.27, green: 0.53, blue: 0.46)
        case .crimson:   return Color(red: 0.68, green: 0.20, blue: 0.20)
        }
    }
}

extension HairColor {
    /// The swatch colour; the same table the hair recolor aims for (LookRecolor.swift).
    var color: Color { Color(materialRGBA) }
}

extension ArmorDye {
    /// The swatch colour; the same table the dye recolor aims for (LookRecolor.swift). None shows the dungeon ash.
    var color: Color {
        guard let rgba = materialRGBA else { return Color.dungeonAsh }
        return Color(rgba)
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

    /// Colour for the tier's text label. The standard tier's accent is the hairline
    /// colour (right for borders, too faint for text), so it reads as secondary text.
    var labelColor: Color {
        switch self {
        case .standard: return .textSecondary
        default:        return accent
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

//
//  CosmeticItem.swift
//  PurgeQuest
//

import Foundation
import SwiftData

enum CosmeticType: String, CaseIterable, Codable {
    case skin
    case head
    case armor
    case weapon
    case shield
    case pet
    case effect

    /// Human-friendly slot name shown in the Hero tab.
    var displayName: String {
        switch self {
        case .skin:   return "Skin"
        case .head:   return "Head"
        case .armor:  return "Armor"
        case .weapon: return "Weapon"
        case .shield: return "Shield"
        case .pet:    return "Pet"
        case .effect: return "FX"
        }
    }
}

@Model
final class CosmeticItem {
    @Attribute(.unique) var id: String
    var name: String
    var subtitle: String
    var typeRaw: String
    var iconName: String
    var priceGems: Int
    var isPremium: Bool
    var isVideoThemed: Bool
    var isUnlocked: Bool
    var isEquipped: Bool

    var type: CosmeticType {
        CosmeticType(rawValue: typeRaw) ?? .skin
    }

    init(id: String, name: String, subtitle: String, type: CosmeticType, iconName: String, priceGems: Int, isPremium: Bool = false, isVideoThemed: Bool = false, isUnlocked: Bool = false) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.typeRaw = type.rawValue
        self.iconName = iconName
        self.priceGems = priceGems
        self.isPremium = isPremium
        self.isVideoThemed = isVideoThemed
        self.isUnlocked = isUnlocked
        self.isEquipped = false
    }
}

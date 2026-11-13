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
    case legs
    case hands
    case weapon
    case shield
    case pet
    case effect
    case upgrade

    /// Slots the Armory does not sell in 1.0. The hero sprite draws only held gear (`SpriteLoadout`), so a
    /// helm, chest piece, legs or hands would show as a badge and not on the hero. The items stay in the
    /// catalog (nothing is deleted from a store, and a save that already owns one keeps it); they only
    /// come back to the shop once the layered art can draw them.
    nonisolated static let hiddenFromShop: Set<CosmeticType> = [.head, .armor, .legs, .hands]

    nonisolated var isSoldInShop: Bool { !Self.hiddenFromShop.contains(self) }

    /// The same slots are not shown on the hero either: no tag, no row under Equipped Gear, no vector
    /// figure helm or armor, and no vote in the plaque tier. Held weapons and shields are unaffected.
    nonisolated static var hiddenFromHero: Set<CosmeticType> { hiddenFromShop }

    nonisolated var isShownOnHero: Bool { !Self.hiddenFromHero.contains(self) }

    /// Human-friendly slot name shown in the Hero tab.
    var displayName: String {
        switch self {
        case .skin:    return "Skin"
        case .head:    return "Helm"
        case .armor:   return "Chest"
        case .legs:    return "Legs"
        case .hands:   return "Hands"
        case .weapon:  return "Weapon"
        case .shield:  return "Shield"
        case .pet:     return "Pet"
        case .effect:  return "FX"
        case .upgrade: return "Upgrade"
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
    /// Sprite render kind for gear-backed items (sword/bow/staff); nil for
    /// icon-only cosmetics and armor pieces.
    var gearKindRaw: String? = nil

    var type: CosmeticType {
        CosmeticType(rawValue: typeRaw) ?? .skin
    }

    var gearKind: GearKind? {
        gearKindRaw.flatMap(GearKind.init(rawValue:))
    }

    init(id: String, name: String, subtitle: String, type: CosmeticType, iconName: String, priceGems: Int, isPremium: Bool = false, isVideoThemed: Bool = false, isUnlocked: Bool = false, gearKind: GearKind? = nil) {
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
        self.gearKindRaw = gearKind?.rawValue
    }
}

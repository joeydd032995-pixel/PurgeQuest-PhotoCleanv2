//
//  GearCatalog.swift
//  PurgeQuest
//
//  The equippable gear catalog: 40 staves and 40 shields from the weapon
//  packs, each race's signature weapon, and per-race armor sets. Gear is
//  seeded into the CosmeticItem store so ownership and equipping reuse the
//  existing Armory economy — once owned, gear is never lost.
//

import Foundation

/// How a gear item renders on the hero sprite.
nonisolated enum GearKind: String, Codable {
    case sword
    case bow
    case staff
}

nonisolated struct GearDesign: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let slot: CosmeticType
    let kind: GearKind?
    let priceGems: Int
    let iconName: String
    /// Bundled image base name for sprite rendering; nil for armor (rendered
    /// via the race's baked art + dye).
    let resourceName: String?

    var isVideoThemed: Bool { false }
}

nonisolated enum GearCatalog {

    // MARK: - Set names

    static let staffSets = [
        "Ashen Bough", "Verdant Coil", "Tidecaller", "Ember Scepter",
        "Storm Spire", "Gilded Crook", "Bone Reliquary", "Voidspike"
    ]
    static let shieldSets = [
        "Oaken Ward", "Templar Aegis", "Scaled Bulwark", "Runic Disc",
        "Valkyrie Wing", "Iron Moon", "Bone Paragon", "Verdigris Sigil"
    ]
    static let tierNames = ["I", "II", "III", "IV", "V"]

    // MARK: - Weapons

    /// 40 staves: 8 themed sets of 5 ascending tiers.
    static var staves: [GearDesign] {
        var designs: [GearDesign] = []
        for (setIndex, setName) in staffSets.enumerated() {
            for tier in 1...5 {
                designs.append(GearDesign(
                    id: "weapon.staff.\(setIndex + 1).\(tier)",
                    name: "\(setName) \(tierNames[tier - 1])",
                    subtitle: "\(setName) staff, tier \(tierNames[tier - 1]). Fits any race's grip.",
                    slot: .weapon,
                    kind: .staff,
                    priceGems: 200 + setIndex * 80 + (tier - 1) * 60,
                    iconName: "wand.and.stars",
                    resourceName: "staff_\(setIndex + 1)_\(tier)"
                ))
            }
        }
        return designs
    }

    /// 40 shields: 8 themed sets of 5 ascending tiers.
    static var shields: [GearDesign] {
        var designs: [GearDesign] = []
        for (setIndex, setName) in shieldSets.enumerated() {
            for tier in 1...5 {
                designs.append(GearDesign(
                    id: "shield.set.\(setIndex + 1).\(tier)",
                    name: "\(setName) \(tierNames[tier - 1])",
                    subtitle: "\(setName) shield, tier \(tierNames[tier - 1]). Off-hand ready.",
                    slot: .shield,
                    kind: nil,
                    priceGems: 150 + setIndex * 70 + (tier - 1) * 50,
                    iconName: "shield.fill",
                    resourceName: "shield_\(setIndex + 1)_\(tier)"
                ))
            }
        }
        return designs
    }

    /// Each race's signature weapon, lifted from its own art pack.
    static var signatureWeapons: [GearDesign] {
        let entries: [(HeroRace, String, String)] = [
            (.valkyrie, "Valkyrie Blade", "Gilded edge that remembers every oath."),
            (.elven, "Elven Recurve", "Cut from living heartwood."),
            (.seer, "Seer's Edge", "A blade that reflects fates back at them."),
            (.vampyri, "Vampyri Cleaver", "Stained by a hundred experiments."),
            (.scarredOnes, "Scarred Fang", "Whispers prophecies mid-swing."),
            (.lostSouls, "Shadowbrand", "Forged in the cold between worlds."),
            (.skeletalUndead, "Undead Claymore", "An oath that outlived its body."),
            (.golem, "Vaultcracker", "Carved from the deepest vault door.")
        ]
        return entries.map { race, name, subtitle in
            let isBow = race == .elven
            return GearDesign(
                id: "weapon.\(race.rawValue)",
                name: name,
                subtitle: subtitle,
                slot: .weapon,
                kind: isBow ? .bow : .sword,
                priceGems: 400,
                iconName: isBow ? "arrowtriangle.right.fill" : "sword.fill",
                resourceName: "\(race.rawValue)_v1_\(isBow ? "bow" : "sword")"
            )
        }
    }

    // MARK: - Armor sets

    /// Armor slot categories with display names.
    static let armorCategories: [(suffix: String, slot: CosmeticType, label: String, price: Int, icon: String)] = [
        ("helm", .head, "Helm", 250, "crown.fill"),
        ("chest", .armor, "Chestplate", 350, "tshirt.fill"),
        ("legs", .legs, "Legguards", 280, "figure.walk"),
        ("hands", .hands, "Gauntlets", 220, "hand.raised.fill")
    ]

    /// 32 armor pieces: each race's signature look across four slots.
    static var armorSets: [GearDesign] {
        var designs: [GearDesign] = []
        for race in HeroRace.allCases {
            for category in armorCategories {
                designs.append(GearDesign(
                    id: "armor.\(race.rawValue).\(category.suffix)",
                    name: "\(race.displayName) \(category.label)",
                    subtitle: "Signature armor of the \(race.displayName). Dye it in the Forge.",
                    slot: category.slot,
                    kind: nil,
                    priceGems: category.price,
                    iconName: category.icon,
                    resourceName: nil
                ))
            }
        }
        return designs
    }

    // MARK: - Access

    static var all: [GearDesign] {
        staves + shields + signatureWeapons + armorSets
    }

    /// Merges the removed Skeleton Warrior gear ids into their Skeletal
    /// Undead equivalents so previously owned pieces keep working.
    static func migratedID(for id: String) -> String {
        if id == "weapon.skeleton_warrior" { return "weapon.skeleton_crusader" }
        if id.hasPrefix("armor.skeleton_warrior.") {
            return "armor.skeleton_crusader." + id.dropFirst("armor.skeleton_warrior.".count)
        }
        return id
    }

    static func design(id: String) -> GearDesign? {
        let normalized = migratedID(for: id)
        return all.first { $0.id == normalized }
    }

    /// Maps catalog designs into the CosmeticItem store.
    static var cosmeticSeeds: [CosmeticItem] {
        all.map { design in
            CosmeticItem(
                id: design.id,
                name: design.name,
                subtitle: design.subtitle,
                type: design.slot,
                iconName: design.iconName,
                priceGems: design.priceGems,
                gearKind: design.kind
            )
        }
    }
}

import Testing
import Foundation
import SwiftData
import UIKit
@testable import PurgeQuest

/// Needs the app bundle (the unit tests are app-hosted): every resource the manifests reference must ship,
/// store catalog identity must be untouched, and the fallback renderer inputs must still resolve.
@MainActor
struct ModularAssetBundleTests {
    private func hasPNG(_ name: String) -> Bool {
        Bundle.main.url(forResource: name, withExtension: "png") != nil
    }

    @Test func bundledManifestsLoad() {
        let catalog = ModularAssetCatalog.shared
        #expect(catalog.parts.count > 400)
        #expect(catalog.gearItems.count == 102)
        #expect(catalog.gear?.titanScale == 2)
    }

    @Test func everyReferencedResourceAndMaskShips() {
        let catalog = ModularAssetCatalog.shared
        var missing: [String] = []
        for part in catalog.parts {
            if !hasPNG(part.resourceBaseName) { missing.append(part.resourceBaseName) }
            for mask in part.maskResources.values where !hasPNG(mask) { missing.append(mask) }
        }
        for item in catalog.gearItems {
            if !hasPNG(item.resourceName) { missing.append(item.resourceName) }
            for mask in item.maskResources.values where !hasPNG(mask) { missing.append(mask) }
        }
        #expect(missing.isEmpty, "missing resources: \(missing.prefix(10))")
    }

    @Test func legacyRaceArtStillShipsForTheFallbackRenderer() {
        for race in HeroRace.allCases {
            for variant in 1...race.variantCount {
                let base = race.artBase(variant: variant)
                #expect(Bundle.main.url(forResource: base, withExtension: "scml") != nil, "\(base).scml")
                for stem in ["head", "body", "left_arm", "right_arm", "left_hand", "right_hand", "left_leg", "right_leg"] {
                    #expect(hasPNG("\(base)_\(stem)"), "\(base)_\(stem)")
                }
            }
        }
    }

    @Test func attackAnimationExistsForEveryVariant() {
        for race in HeroRace.allCases {
            for variant in 1...race.variantCount {
                let count = SpriteRenderer.shared.frameCount(race: race, variant: variant,
                                                             animation: SpriteRenderer.shared.attackAnimation(race: race, variant: variant))
                #expect(count > 0, "\(race.rawValue) v\(variant) has no playable attack animation")
            }
        }
    }

    @Test func rendererFallsBackToLegacyWhenNothingIsVerified() {
        let look = HeroAppearance.default(for: .valkyrie)
        let frame = SpriteRenderer.shared.frame(race: .valkyrie, variant: 1, animation: "Idle", frameIndex: 0, appearance: look)
        #expect(frame != nil)
        #expect(frame?.layout == SpriteCanvasLayout.zero)
    }

    @Test func titanFrameGrowsTheCanvasWithoutChangingTheBaseSize() throws {
        let look = HeroAppearance.default(for: .valkyrie)
        let plain = try #require(SpriteRenderer.shared.frame(race: .valkyrie, variant: 1, animation: "Slashing", frameIndex: 3, appearance: look))
        let titan = try #require(SpriteRenderer.shared.frame(race: .valkyrie, variant: 1, animation: "Slashing", frameIndex: 3, appearance: look,
                                                              loadout: SpriteLoadout(titanWeapon: true)))
        #expect(titan.image.size.width > plain.image.size.width)
        #expect(titan.layout != SpriteCanvasLayout.zero)
        let base = try #require(SpriteRenderer.shared.canvasSize(race: .valkyrie, variant: 1))
        #expect(plain.image.size == base)
    }

    @Test func heldGearRendersForEverySupportedPackWithoutBlankFrames() throws {
        let look = HeroAppearance.default(for: .valkyrie)
        for id in ["weapon.staff.1.1", "weapon.valkyrie", "weapon.arcane", "weapon.fireworkBlade"] {
            for race in HeroRace.allCases {
                let frame = SpriteRenderer.shared.frame(race: race, variant: 1, animation: "Idle", frameIndex: 0, appearance: look,
                                                        loadout: SpriteLoadout(weaponID: id, shieldID: "shield.set.1.1", headID: "head.starhat"))
                #expect(frame != nil, "\(id) on \(race.rawValue)")
            }
        }
    }

    // MARK: Catalog identity (IDs, prices, unlocks) must not drift

    @Test func storeGearIdentityIsPreserved() throws {
        let container = try ModelContainer(for: CosmeticItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        GameDataService.seedCosmeticsIfNeeded(in: context)
        let items = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<CosmeticItem>()).map { ($0.id, $0) })
        let expected: [(String, String, Int, Bool)] = [
            ("head.starhat", "Starlit Cap", 300, false), ("head.hood", "Shadow Hood", 500, false), ("head.dragoncrest", "Dragoncrest Helm", 650, false),
            ("weapon.shard", "Crystal Shard", 0, true), ("weapon.reel", "Film Reel Blade", 600, false), ("weapon.gem", "Gem Hammer", 800, false),
            ("weapon.staff", "Archmage Staff", 500, false), ("weapon.stormblade", "Storm Cleaver", 700, false),
            ("weapon.chevron", "Oathbreaker Greatsword", 750, false), ("weapon.ruby", "Ruby Fang", 700, false),
            ("weapon.arcane", "Arcane Edge", 900, false), ("weapon.fireworkBlade", "Firework Blade", 750, false),
            ("shield.crux", "Azure Aegis", 500, false), ("shield.templar", "Templar Bulwark", 850, false),
            ("upgrade.titanBlade", "Titan Blade", 3000, false)
        ]
        for (id, name, price, unlocked) in expected {
            let item = try #require(items[id], "\(id)")
            #expect(item.name == name && item.priceGems == price && item.isUnlocked == unlocked, "\(id)")
        }
    }

    @Test func titanBladeCopyAndRendererAgree() throws {
        let container = try ModelContainer(for: CosmeticItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        GameDataService.seedCosmeticsIfNeeded(in: context)
        let titan = try #require(try context.fetch(FetchDescriptor<CosmeticItem>()).first { $0.id == "upgrade.titanBlade" })
        #expect(titan.subtitle.localizedCaseInsensitiveContains("doubles"))
        #expect(HeldGearFit.titanScale == 2)
    }
}

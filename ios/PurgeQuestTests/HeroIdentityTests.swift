//
//  HeroIdentityTests.swift
//  PurgeQuest
//
//  Tests for the eight-race identity overhaul: class roster and legacy
//  mapping, race defaults, appearance v3 migration, gear catalog integrity,
//  class perk math, and sprite part naming.
//

import Testing
import SwiftData
import Foundation
@testable import PurgeQuest

@MainActor
struct HeroIdentityTests {

    // MARK: - Class roster

    @Test func classRosterCounts() {
        #expect(HeroClass.allCases.count == 17)
        #expect(HeroClass.allCases.filter { $0.discipline == .melee }.count == 6)
        #expect(HeroClass.allCases.filter { $0.discipline == .ranged }.count == 3)
        #expect(HeroClass.allCases.filter { $0.discipline == .magic }.count == 8)
    }

    @Test func legacyClassMappingPreservesPerks() {
        #expect(HeroClass.legacyClass(forRaw: "purgeKnight") == .paladinHoly)
        #expect(HeroClass.legacyClass(forRaw: "archivist") == .priestDivine)
        #expect(HeroClass.legacyClass(forRaw: "cinematographer") == .windrunner)
        #expect(HeroClass.legacyClass(forRaw: "digitalHermit") == .shamanEarth)
        #expect(HeroClass.legacyClass(forRaw: "bogus") == nil)
    }

    @Test func heroFallsBackToLegacyClass() {
        let hero = Hero()
        hero.heroClassRaw = "archivist"
        #expect(hero.heroClass == .priestDivine)
        hero.heroClassRaw = "cinematographer"
        #expect(hero.heroClass == .windrunner)
        hero.heroClassRaw = "nonsense"
        #expect(hero.heroClass == .paladinHoly)
    }

    // MARK: - Races

    @Test func legacyArchetypeMapsToDefaultRace() {
        #expect(HeroRace(legacyArchetype: .knight) == .valkyrie)
        #expect(HeroRace(legacyArchetype: .magician) == .seer)
    }

    @Test func racePalettesAndAnimations() {
        #expect(HeroRace.valkyrie.palette == .flesh)
        #expect(HeroRace.skeletalUndead.palette == .bone)
        #expect(HeroRace.golem.palette == .stone)
        #expect(HeroRace.elven.attackAnimationName == "Shooting")
        #expect(HeroRace.valkyrie.attackAnimationName == "Slashing")
    }

    @Test func raceRenamesAndMerge() {
        #expect(HeroRace.allCases.count == 8)
        #expect(HeroRace.elven.rawValue == "forest_ranger")
        #expect(HeroRace.elven.displayName == "Elven")
        #expect(HeroRace.vampyri.displayName == "Vampyri")
        #expect(HeroRace.scarredOnes.displayName == "The Scarred Ones")
        #expect(HeroRace.lostSouls.displayName == "Lost Souls")
        #expect(HeroRace.skeletalUndead.displayName == "Skeletal Undead")
        #expect(HeroRace.skeletalUndead.variantCount == 6)
        #expect(HeroRace.valkyrie.variantCount == 3)
        #expect(HeroRace.skeletalUndead.artBase(variant: 5) == "skeleton_warrior_v2")
        #expect(HeroRace.skeletalUndead.artBase(variant: 1) == "skeleton_crusader_v1")
        #expect(HeroRace.elven.artBase(variant: 2) == "forest_ranger_v2")
    }

    @Test func skeletonWarriorSaveMigratesIntoSkeletalUndead() {
        let warrior = HeroAppearance.decode(
            Data("{\"schemaVersion\":3,\"race\":\"skeleton_warrior\",\"paintVariant\":2}".utf8),
            for: .knight
        )
        #expect(warrior.race == .skeletalUndead)
        #expect(warrior.paintVariant == 5)

        let crusader = HeroAppearance.decode(
            Data("{\"schemaVersion\":3,\"race\":\"skeleton_crusader\",\"paintVariant\":3}".utf8),
            for: .knight
        )
        #expect(crusader.race == .skeletalUndead)
        #expect(crusader.paintVariant == 3)
    }

    @Test func legacyWarriorGearIDsMigrate() {
        #expect(GearCatalog.migratedID(for: "weapon.skeleton_warrior") == "weapon.skeleton_crusader")
        #expect(GearCatalog.migratedID(for: "armor.skeleton_warrior.helm") == "armor.skeleton_crusader.helm")
        #expect(GearCatalog.migratedID(for: "weapon.valkyrie") == "weapon.valkyrie")
        #expect(GearCatalog.design(id: "weapon.skeleton_warrior")?.kind == .sword)
    }

    // MARK: - Appearance migration

    @Test func v2JSONMigratesToV3WithDefaults() {
        let v2 = """
        {"schemaVersion":2,"skinTone":"honey","faceShape":"nimble","eyeStyle":"bright","eyeColor":"jade","browStyle":"steady","mouthStyle":"grin","hairStyle":"swept","hairColor":"raven","expression":"calm","backdropStyle":"plaque","armorDye":"crimson"}
        """
        let data = Data(v2.utf8)
        let look = HeroAppearance.decode(data, for: .magician)
        #expect(look.schemaVersion == HeroAppearance.currentSchemaVersion)
        #expect(look.race == nil)
        #expect(look.paintVariant == 1)
        #expect(look.skinHueShift == 0)
        #expect(look.armorDye == .crimson)
        #expect(look.skinTone == .honey)

        // nil race falls back to the legacy archetype's designed race.
        let hero = Hero()
        hero.archetype = .magician
        hero.appearanceData = data
        #expect(hero.race == .seer)
    }

    @Test func v3RoundTripPreservesRaceAndShifts() {
        var look = HeroAppearance.default(for: .golem)
        look.paintVariant = 3
        look.skinHueShift = HeroAppearance.clampedHue(0.4)
        look.hairHueShift = HeroAppearance.clampedHue(-0.9)
        let hero = Hero()
        hero.appearance = look
        #expect(hero.race == .golem)
        #expect(hero.appearance == look)
    }

    @Test func hueClamping() {
        #expect(HeroAppearance.clampedHue(2) == 1)
        #expect(HeroAppearance.clampedHue(-3) == -1)
        #expect(HeroAppearance.clampedHue(0.25) == 0.25)
    }

    @Test func defaultsAreRaceAppropriate() {
        #expect(HeroAppearance.default(for: .golem).skinTone == .ashen)
        #expect(HeroAppearance.default(for: .skeletalUndead).skinTone == .moonlit)
        #expect(HeroAppearance.default(for: .valkyrie).race == .valkyrie)
    }

    // MARK: - Gear catalog

    @Test func gearCatalogCounts() {
        #expect(GearCatalog.staves.count == 40)
        #expect(GearCatalog.shields.count == 40)
        #expect(GearCatalog.signatureWeapons.count == 8)
        #expect(GearCatalog.armorSets.count == 32)
    }

    @Test func gearIDsAreUnique() {
        let ids = GearCatalog.all.map(\.id)
        #expect(ids.count == Set(ids).count)
    }

    @Test func gearSlotMapping() {
        #expect(GearCatalog.staves.allSatisfy { $0.slot == .weapon && $0.kind == .staff && $0.resourceName != nil })
        #expect(GearCatalog.shields.allSatisfy { $0.slot == .shield && $0.resourceName != nil })
        #expect(GearCatalog.signatureWeapons.allSatisfy { $0.slot == .weapon && $0.resourceName != nil })
        #expect(GearCatalog.armorSets.allSatisfy { $0.resourceName == nil })

        let rangerBow = GearCatalog.signatureWeapons.first { $0.id == "weapon.forest_ranger" }
        #expect(rangerBow?.kind == .bow)
        #expect(rangerBow?.resourceName == "forest_ranger_v1_bow")

        let valkyrieBlade = GearCatalog.signatureWeapons.first { $0.id == "weapon.valkyrie" }
        #expect(valkyrieBlade?.kind == .sword)
        #expect(valkyrieBlade?.resourceName == "valkyrie_v1_sword")
    }

    @Test func armorSlotsCoverAllCategories() {
        for race in HeroRace.allCases {
            let pieces = GearCatalog.armorSets.filter { $0.id.hasPrefix("armor.\(race.rawValue).") }
            #expect(pieces.count == 4)
            #expect(Set(pieces.map(\.slot)) == Set([.head, .armor, .legs, .hands]))
        }
    }

    // MARK: - Perks

    @Test func classPerkMath() {
        #expect(HeroClass.hunter.xpMultiplier(photo: true, monsterType: .blurBeast) == 1.20)
        #expect(HeroClass.hunter.xpMultiplier(photo: false, monsterType: .blurBeast) == 1.0)
        #expect(HeroClass.windrunner.xpMultiplier(photo: false, monsterType: .videoVampire) == 1.20)
        #expect(HeroClass.windrunner.xpMultiplier(photo: true, monsterType: .videoVampire) == 1.0)
        #expect(HeroClass.priestPlague.xpMultiplier(photo: true, monsterType: .duplicateDragon) == 1.20)
        #expect(HeroClass.paladinUnholy.xpMultiplier(photo: true, monsterType: .corruptedCodec) == 1.25)
        #expect(HeroClass.warriorBlood.xpMultiplier(photo: true, monsterType: .blurBeast) == 1.20)
        #expect(HeroClass.mageIce.xpMultiplier(photo: true, monsterType: .ancientArchive) == 1.20)
        #expect(HeroClass.rogueAssassin.xpMultiplier(photo: true, monsterType: .blurBeast) == 1.25)
        #expect(HeroClass.paladinHoly.gemMultiplier == 1.0)
        #expect(HeroClass.voidstalker.gemMultiplier == 1.15)
        #expect(HeroClass.shamanEarth.gemMultiplier == 1.10)
    }

    // MARK: - Sprite naming

    @Test func partBaseNaming() {
        #expect(SpriteRenderer.partBaseName(race: .valkyrie, variant: 1, fileName: "Face 01.png") == "valkyrie_v1_face_01")
        #expect(SpriteRenderer.partBaseName(race: .golem, variant: 2, fileName: "Body.png") == "golem_v2_body")
        #expect(SpriteRenderer.partBaseName(race: .skeletalUndead, variant: 4, fileName: "Head.png") == "skeleton_warrior_v1_head")
    }
}

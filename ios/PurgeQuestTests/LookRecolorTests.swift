//
//  LookRecolorTests.swift
//  PurgeQuestTests
//
//  The skin, hair and armor-dye swatches must recolor the baked sprite through the shipped masks. Expected
//  values are literals from outside the code under test: swatch colors from the palette
//  (HeroAppearance+Palette.swift), dye shading and clamp vectors from the Python reference
//  (tools/modular_assets imgops.recolor_pixels / OKLab, via the look-recolor reference), window weights
//  worked by hand from the formula, and capability/plan expectations from the shipped manifest.
//

import Testing
import Foundation
@testable import PurgeQuest

// MARK: - Fixtures

private let repoRoot: URL = {
    if let root = ProcessInfo.processInfo.environment["PQ_REPO_ROOT"] { return URL(fileURLWithPath: root) }
    return URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
}()

private func loadCatalog() throws -> ModularAssetCatalog {
    let dir = repoRoot.appendingPathComponent("ios/PurgeQuest/Art/Modular")
    return ModularAssetCatalog(
        racesData: try Data(contentsOf: dir.appendingPathComponent("modular_races_manifest.json")),
        gearData: try Data(contentsOf: dir.appendingPathComponent("modular_gear_manifest.json")))
}

private func allPaints() -> [(race: HeroRace, variant: Int, pack: String)] {
    HeroRace.allCases.flatMap { race in (1...race.variantCount).map { (race, $0, race.artBase(variant: $0)) } }
}

private func packs(
    withAvailable control: KeyPath<LookCapabilities, LookAvailability>, catalog: ModularAssetCatalog, available: Bool
) -> [String] {
    allPaints().filter { paint in
        let state = LookCapabilities.forPaint(race: paint.race, variant: paint.variant, parts: catalog.parts(forPack: paint.pack))[keyPath: control]
        return (state == .available) == available
    }.map(\.pack).sorted()
}

/// A hand-built manifest entry, for the rules the shipped manifest cannot exercise (for example a hair mask on a skull).
private func syntheticPart(pack: String, part: String, kind: String, masks: [String: String]) -> PartManifest {
    PartManifest(
        id: "\(pack).\(part).\(kind)", resourceBaseName: "\(pack)_\(part)_\(kind)", slot: .head,
        maskResources: masks, pack: pack, part: part, kind: kind)
}

private func expectColor(
    _ actual: MaterialRGBA?, _ expected: (Double, Double, Double), tolerance: Double = 1e-6,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    guard let actual else {
        Issue.record("expected a color but got none", sourceLocation: sourceLocation)
        return
    }
    #expect(
        abs(actual.red - expected.0) <= tolerance && abs(actual.green - expected.1) <= tolerance
            && abs(actual.blue - expected.2) <= tolerance,
        "got (\(actual.red), \(actual.green), \(actual.blue)), expected \(expected)", sourceLocation: sourceLocation)
}

/// Region tones of Seer 2's body armor layer, as shipped in the manifest.
private let seerTwoBodyTones: [String: [Double]] = ["primary": [0.40713, 0.05587], "secondary": [0.3275, 0.03648]]

struct LookRecolorTests {

    // MARK: Swatch choices

    @Test func choosingASkinToneStoresATaggedColorAndKeepsOtherRegions() {
        var look = HeroAppearance.default(for: .seer)
        let custom = MaterialSelection(id: "custom", color: MaterialRGBA(red: 0.1, green: 0.2, blue: 0.3))
        look.materials = CharacterMaterialSet(armorPrimary: custom)
        let chosen = look.choosingSkin(.honey)
        #expect(chosen.skinTone == .honey)
        #expect(chosen.materials?.skin?.id == "skin.honey")
        expectColor(chosen.materials?.skin?.color, (0.83, 0.63, 0.42))
        #expect(chosen.materials?.armorPrimary == custom)
    }

    @Test func choosingAHairColorStoresATaggedColor() {
        let chosen = HeroAppearance.default(for: .seer).choosingHair(.wheat)
        #expect(chosen.hairColor == .wheat)
        #expect(chosen.materials?.hair?.id == "hair.wheat")
        expectColor(chosen.materials?.hair?.color, (0.84, 0.72, 0.44))
    }

    @Test func asPaintedClearsOnlyTheSkinEntry() {
        var look = HeroAppearance.default(for: .seer)
        let custom = MaterialSelection(id: "custom", color: MaterialRGBA(red: 0.1, green: 0.2, blue: 0.3))
        look.materials = CharacterMaterialSet(armorPrimary: custom)
        let cleared = look.choosingSkin(.ebony).choosingSkin(nil)
        #expect(cleared.materials == CharacterMaterialSet(armorPrimary: custom))
    }

    @Test func asPaintedOnAnUntouchedLookRestoresTheWholeLook() {
        let look = HeroAppearance.default(for: .seer)
        #expect(look.choosingSkin(.umber).choosingSkin(nil).materials == nil)
        #expect(look.choosingHair(.ember).choosingHair(nil).materials == nil)
        // The saved enum goes back to the race default too, so the Forge does not see a phantom customization
        // (isDefaultLook, AncestryChange.hasCustomization) and previews do not keep the last swatch.
        #expect(look.choosingSkin(.umber).choosingSkin(nil) == look)
        #expect(look.choosingHair(.ember).choosingHair(nil) == look)
    }

    @Test func asPaintedWithoutAKnownRaceLeavesTheEnumAlone() {
        var legacy = HeroAppearance.default(for: .seer)
        legacy.race = nil
        let cleared = legacy.choosingSkin(.umber).choosingSkin(nil)
        #expect(cleared.materials == nil)
        #expect(cleared.skinTone == .umber, "with no race there is no default to restore")
    }

    @Test func theChosenSwatchIsReadBackFromItsTag() {
        let look = HeroAppearance.default(for: .seer)
        #expect(look.chosenSkinTone == nil && look.chosenHairColor == nil)
        let chosen = look.choosingSkin(.jadekin).choosingHair(.rust)
        #expect(chosen.chosenSkinTone == .jadekin)
        #expect(chosen.chosenHairColor == .rust)
        var custom = look
        custom.materials = CharacterMaterialSet(
            skin: MaterialSelection(id: "custom", color: MaterialRGBA(red: 0.5, green: 0.5, blue: 0.5)))
        #expect(custom.chosenSkinTone == nil)
    }

    // MARK: Armor dye

    @Test func dyeReachesBodyArmsAndLegsButNeverHeadOrHands() {
        var look = HeroAppearance.default(for: .seer)
        look.armorDye = .verdigris
        for stem in ["body", "left_arm", "right_arm", "left_leg", "right_leg"] {
            let set = look.resolvedMaterials(forPart: stem, regionTones: seerTwoBodyTones)
            expectColor(set?.armorPrimary?.color, (0.29, 0.54, 0.45))
            #expect(set?.armorSecondary != nil, "\(stem) should get a secondary dye color")
        }
        for stem in ["head", "left_hand", "right_hand", "face_01", "sword"] {
            #expect(look.resolvedMaterials(forPart: stem, regionTones: seerTwoBodyTones) == nil, "\(stem) must not be dyed")
        }
    }

    @Test func noDyeAndNoStoredColorsMeansNoMaterials() {
        #expect(HeroAppearance.default(for: .seer).resolvedMaterials(forPart: "body", regionTones: seerTwoBodyTones) == nil)
    }

    @Test func storedColorsPassThroughToEveryPart() {
        let look = HeroAppearance.default(for: .seer).choosingSkin(.honey)
        for stem in ["head", "left_hand", "body"] {
            #expect(look.resolvedMaterials(forPart: stem, regionTones: seerTwoBodyTones)?.skin?.id == "skin.honey")
        }
    }

    @Test func aStoredArmorColorWinsOverTheDye() {
        var look = HeroAppearance.default(for: .seer)
        look.armorDye = .gilded
        let custom = MaterialSelection(id: "custom", color: MaterialRGBA(red: 0.1, green: 0.2, blue: 0.3))
        look.materials = CharacterMaterialSet(armorPrimary: custom)
        let set = look.resolvedMaterials(forPart: "body", regionTones: seerTwoBodyTones)
        #expect(set?.armorPrimary == custom)
        #expect(set?.armorSecondary == nil)
    }

    /// (label, dye, secondary-minus-primary lightness, expected secondary rgb), from the Python reference.
    private static let secondaryOracle: [(String, ArmorDye, Double, (Double, Double, Double))] = [
        ("verdigris dl -0.26", .verdigris, -0.26, (0.000000000, 0.248258542, 0.173232847)),
        ("crimson dl -0.26", .crimson, -0.26, (0.284282157, 0.0, 0.0)),
        ("gilded dl +0.10", .gilded, 0.1, (0.909264277, 0.703616532, 0.354560850)),
        ("bone dl +0.20 clamps", .bone, 0.20, (0.927622570, 0.897266752, 0.785787036)),
        ("bone to L 0.91", .bone, 0.042386740979, (0.914640044, 0.884351206, 0.773149785)),
        ("bone to L 0.92", .bone, 0.052386740979, (0.927622570, 0.897266752, 0.785787036)),
        ("bone to L 0.93", .bone, 0.062386740979, (0.927622570, 0.897266752, 0.785787036)),
        ("bone to L 0.95", .bone, 0.082386740979, (0.927622570, 0.897266752, 0.785787036)),
        ("crimson to L 0.13", .crimson, -0.346987915408, (0.173813848, 0.0, 0.0)),
        ("crimson to L 0.12", .crimson, -0.356987915408, (0.161066765, 0.0, 0.0)),
        ("crimson to L 0.11", .crimson, -0.366987915408, (0.161066765, 0.0, 0.0)),
        ("crimson to L 0.05", .crimson, -0.426987915408, (0.161066765, 0.0, 0.0))
    ]

    @Test func theSecondaryKeepsItsLightnessOffsetFromThePrimary() {
        for (label, dye, delta, expected) in Self.secondaryOracle {
            var look = HeroAppearance.default(for: .seer)
            look.armorDye = dye
            let tones = ["primary": [0.5, 0.1], "secondary": [0.5 + delta, 0.1]]
            let set = look.resolvedMaterials(forPart: "body", regionTones: tones)
            expectColor(set?.armorSecondary?.color, expected)
            #expect(set != nil, "\(label)")
        }
    }

    @Test func withoutRegionTonesTheSecondaryIsTheDyeItself() {
        var look = HeroAppearance.default(for: .seer)
        look.armorDye = .crimson
        let set = look.resolvedMaterials(forPart: "body", regionTones: [:])
        expectColor(set?.armorPrimary?.color, (0.62, 0.19, 0.21))
        expectColor(set?.armorSecondary?.color, (0.62, 0.19, 0.21))
    }

    @Test func aSavedHeroWithOnlyTheDyeEnumStillGetsTheDye() throws {
        let saved = #"{"schemaVersion":3,"armorDye":"crimson"}"#
        let look = try JSONDecoder().decode(HeroAppearance.self, from: Data(saved.utf8))
        #expect(look.materials == nil)
        expectColor(look.resolvedMaterials(forPart: "body", regionTones: [:])?.armorPrimary?.color, (0.62, 0.19, 0.21))
    }

    // MARK: Face window

    @Test func windowWeightIsAnatomySkinTimesOneMinusHeadgearAlpha() {
        // (255,0)->255, (255,255)->0, (255,128)->127, (0,0)->0, (128,0)->128, (200,51)->160, (1,1)->0.996 rounds to 1
        let weights = FaceWindow.weights(
            anatomySkin: [255, 255, 255, 0, 128, 200, 1],
            headgearAlpha: [0, 255, 128, 0, 0, 51, 1],
            headgearSkin: nil)
        #expect(weights == [255, 0, 127, 0, 128, 160, 1])
    }

    @Test func theHeadgearSkinMaskAddsToTheWindowAndClamps() {
        let weights = FaceWindow.weights(
            anatomySkin: [100, 255, 0],
            headgearAlpha: [255, 0, 255],
            headgearSkin: [60, 40, 0])
        #expect(weights == [60, 255, 0])
    }

    @Test func mismatchedBufferLengthsGiveNoWeights() {
        #expect(FaceWindow.weights(anatomySkin: [1, 2], headgearAlpha: [1], headgearSkin: nil) == nil)
        #expect(FaceWindow.weights(anatomySkin: [1, 2], headgearAlpha: [1, 2], headgearSkin: [1]) == nil)
    }

    // MARK: Capabilities (shipped manifest)

    @Test func dyeIsUnavailableExactlyOnPaintsWithoutBodyArmorRegions() throws {
        let catalog = try loadCatalog()
        #expect(packs(withAvailable: \.armorDye, catalog: catalog, available: false) == ["golem_v1", "skeleton_warrior_v3"])
    }

    @Test func hairIsAvailableExactlyOnPaintsWithAHairRegion() throws {
        let catalog = try loadCatalog()
        #expect(packs(withAvailable: \.hair, catalog: catalog, available: true)
            == ["forest_ranger_v1", "necromancer_v1", "seer_v3"])
    }

    @Test func skinIsAvailableOnlyOnFleshPaintsWithARealFace() throws {
        let catalog = try loadCatalog()
        #expect(packs(withAvailable: \.skin, catalog: catalog, available: true) == [
            "blood_alchemist_v1", "blood_alchemist_v2", "blood_alchemist_v3", "dark_oracle_v1",
            "forest_ranger_v1", "forest_ranger_v2", "forest_ranger_v3",
            "necromancer_v1", "necromancer_v2", "necromancer_v3",
            "seer_v1", "seer_v2", "seer_v3", "valkyrie_v1", "valkyrie_v2", "valkyrie_v3"
        ])
    }

    @Test func boneAndStoneNeverOfferHairEvenWhenAHairMaskExists() {
        // The same hair layer is offered on a flesh paint, so the palette is the only difference.
        let bone = [syntheticPart(pack: "skeleton_crusader_v1", part: "head", kind: "headgear", masks: ["hair": "m_hair"])]
        let flesh = [syntheticPart(pack: "seer_v3", part: "head", kind: "headgear", masks: ["hair": "m_hair"])]
        #expect(LookCapabilities.forPaint(race: .skeletalUndead, variant: 1, parts: bone).hair
            == .unavailable(reason: LookCapabilities.noVisibleHair))
        #expect(LookCapabilities.forPaint(race: .seer, variant: 3, parts: flesh).hair == .available)
    }

    @Test func unavailableControlsStateTheirReason() throws {
        let catalog = try loadCatalog()
        func capabilities(_ race: HeroRace, _ variant: Int) -> LookCapabilities {
            .forPaint(race: race, variant: variant, parts: catalog.parts(forPack: race.artBase(variant: variant)))
        }
        guard case .unavailable(let boneReason) = capabilities(.golem, 2).skin,
              case .unavailable(let voidReason) = capabilities(.scarredOnes, 2).skin,
              case .unavailable(let dyeReason) = capabilities(.golem, 1).armorDye,
              case .unavailable(let hairReason) = capabilities(.valkyrie, 1).hair
        else {
            Issue.record("expected all four controls to be unavailable on these paints")
            return
        }
        #expect(!boneReason.isEmpty && !voidReason.isEmpty && !dyeReason.isEmpty && !hairReason.isEmpty)
        #expect(boneReason != voidReason, "a stone body and a void face are different reasons")
    }

    // MARK: Plans (shipped manifest)

    private func seerTwo(_ catalog: ModularAssetCatalog) -> [PartManifest] { catalog.parts(forPack: "seer_v2") }

    @Test func aBodyPlansTheArmorMasksForTheDye() throws {
        let parts = seerTwo(try loadCatalog())
        var look = HeroAppearance.default(for: .seer)
        look.armorDye = .verdigris
        let set = look.resolvedMaterials(forPart: "body", regionTones: seerTwoBodyTones)
        let plan = LegacyRecolorPlanner.plan(race: .seer, variant: 2, stem: "body", materials: set, parts: parts)
        #expect(plan == [
            PlannedRecolorRegion(region: .primary, source: .mask(resource: "seer_v2_body_armor_mask_primary"),
                                 tone: RegionTone(lightness: 0.40713, chroma: 0.05587)),
            PlannedRecolorRegion(region: .secondary, source: .mask(resource: "seer_v2_body_armor_mask_secondary"),
                                 tone: RegionTone(lightness: 0.3275, chroma: 0.03648))
        ])
    }

    @Test func dyeShadingUsesTheArmorLayersTones() throws {
        let parts = seerTwo(try loadCatalog())
        let body = LegacyRecolorPlanner.armorTones(race: .seer, variant: 2, stem: "body", parts: parts)
        #expect(body["primary"] == [0.40713, 0.05587])
        #expect(body["secondary"] == [0.3275, 0.03648])
        // The head's layer is headgear and the hand's is anatomy: neither carries primary/secondary tones.
        #expect(LegacyRecolorPlanner.armorTones(race: .seer, variant: 2, stem: "head", parts: parts).isEmpty)
        #expect(LegacyRecolorPlanner.armorTones(race: .seer, variant: 2, stem: "left_hand", parts: parts).isEmpty)
    }

    @Test func aHeadPlansTheFaceWindowAndNeverTheDye() throws {
        let parts = seerTwo(try loadCatalog())
        var look = HeroAppearance.default(for: .seer)
        look.armorDye = .verdigris
        look = look.choosingSkin(.honey)
        let set = look.resolvedMaterials(forPart: "head", regionTones: seerTwoBodyTones)
        let plan = LegacyRecolorPlanner.plan(race: .seer, variant: 2, stem: "head", materials: set, parts: parts)
        #expect(plan == [
            PlannedRecolorRegion(
                region: .skin,
                source: .faceWindow(anatomySkinMask: "seer_v2_head_anatomy_mask_skin",
                                    headgearLayer: "seer_v2_head_headgear",
                                    headgearSkinMask: "seer_v2_head_headgear_mask_skin"),
                tone: RegionTone(lightness: 0.62494, chroma: 0.11008))
        ])
    }

    @Test func theSeerThreeHeadPlansItsSkinWindowThenItsHairRegion() throws {
        let parts = try loadCatalog().parts(forPack: "seer_v3")
        let look = HeroAppearance.default(for: .seer).choosingSkin(.ebony).choosingHair(.wheat)
        let set = look.resolvedMaterials(forPart: "head", regionTones: [:])
        let plan = LegacyRecolorPlanner.plan(race: .seer, variant: 3, stem: "head", materials: set, parts: parts)
        #expect(plan == [
            PlannedRecolorRegion(
                region: .skin,
                source: .faceWindow(anatomySkinMask: "seer_v3_head_anatomy_mask_skin",
                                    headgearLayer: "seer_v3_head_headgear",
                                    headgearSkinMask: "seer_v3_head_headgear_mask_skin"),
                tone: RegionTone(lightness: 0.72344, chroma: 0.09154)),
            PlannedRecolorRegion(region: .hair, source: .mask(resource: "seer_v3_head_headgear_mask_hair"),
                                 tone: RegionTone(lightness: 0.40237, chroma: 0.0684))
        ])
    }

    @Test func hairOnAHoodedPaintPlansNothing() throws {
        let parts = seerTwo(try loadCatalog())
        let set = HeroAppearance.default(for: .seer).choosingHair(.raven)
            .resolvedMaterials(forPart: "head", regionTones: [:])
        #expect(LegacyRecolorPlanner.plan(race: .seer, variant: 2, stem: "head", materials: set, parts: parts).isEmpty)
    }

    @Test func hairNeverReachesTheOutfitEvenOnAHairCapablePaint() throws {
        // Seer 3 has a hair region on its head; its armor layers have primary regions but no hair, and the hair
        // swatch must not fall back to them (the tunic turning blond).
        let parts = try loadCatalog().parts(forPack: "seer_v3")
        let set = HeroAppearance.default(for: .seer).choosingHair(.wheat)
        for stem in ["body", "left_arm", "right_arm", "left_leg", "right_leg", "left_hand", "right_hand"] {
            let resolved = set.resolvedMaterials(forPart: stem, regionTones: [:])
            #expect(LegacyRecolorPlanner.plan(race: .seer, variant: 3, stem: stem, materials: resolved, parts: parts).isEmpty,
                    "\(stem) must not take the hair color")
        }
    }

    @Test func handsPlanSkinOnlyWhenTheAnatomyLayerIsTheBakedImage() throws {
        let catalog = try loadCatalog()
        let look = HeroAppearance.default(for: .seer).choosingSkin(.honey)
        let set = look.resolvedMaterials(forPart: "left_hand", regionTones: [:])
        let seerTwoPlan = LegacyRecolorPlanner.plan(
            race: .seer, variant: 2, stem: "left_hand", materials: set, parts: catalog.parts(forPack: "seer_v2"))
        #expect(seerTwoPlan == [
            PlannedRecolorRegion(region: .skin, source: .mask(resource: "seer_v2_left_hand_anatomy_mask_skin"),
                                 tone: RegionTone(lightness: 0.62494, chroma: 0.11008))
        ])
        // Seer 3's hand art is a glove: its anatomy layer is a procedural silhouette, not the baked pixels.
        let seerThreePlan = LegacyRecolorPlanner.plan(
            race: .seer, variant: 3, stem: "left_hand", materials: set, parts: catalog.parts(forPack: "seer_v3"))
        #expect(seerThreePlan.isEmpty)
    }

    @Test func anAnatomyOnlyHeadUsesItsSkinMaskDirectly() throws {
        let parts = try loadCatalog().parts(forPack: "blood_alchemist_v1")
        let set = HeroAppearance.default(for: .vampyri).choosingSkin(.umber)
            .resolvedMaterials(forPart: "head", regionTones: [:])
        let plan = LegacyRecolorPlanner.plan(race: .vampyri, variant: 1, stem: "head", materials: set, parts: parts)
        #expect(plan == [
            PlannedRecolorRegion(region: .skin, source: .mask(resource: "blood_alchemist_v1_head_anatomy_mask_skin"),
                                 tone: RegionTone(lightness: 0.66091, chroma: 0.08826))
        ])
    }

    @Test func boneAndStonePaintsIgnoreSkinAndHair() throws {
        let catalog = try loadCatalog()
        let set = HeroAppearance.default(for: .skeletalUndead).choosingSkin(.honey).choosingHair(.raven)
            .resolvedMaterials(forPart: "head", regionTones: [:])
        let plan = LegacyRecolorPlanner.plan(
            race: .skeletalUndead, variant: 1, stem: "head", materials: set, parts: catalog.parts(forPack: "skeleton_crusader_v1"))
        #expect(plan.isEmpty)
    }

    @Test func boneAndStoneNeverPlanHairEvenWhenAHairMaskExists() {
        let bone = [syntheticPart(pack: "skeleton_crusader_v1", part: "head", kind: "headgear", masks: ["hair": "m_hair"])]
        let flesh = [syntheticPart(pack: "seer_v3", part: "head", kind: "headgear", masks: ["hair": "m_hair"])]
        let set = HeroAppearance.default(for: .seer).choosingHair(.raven).resolvedMaterials(forPart: "head", regionTones: [:])
        #expect(LegacyRecolorPlanner.plan(race: .skeletalUndead, variant: 1, stem: "head", materials: set, parts: bone).isEmpty)
        #expect(LegacyRecolorPlanner.plan(race: .seer, variant: 3, stem: "head", materials: set, parts: flesh)
            == [PlannedRecolorRegion(region: .hair, source: .mask(resource: "m_hair"), tone: nil)])
    }

    @Test func aVoidFacedPaintNeverPlansASkinRecolorEvenWithAStoredSkin() throws {
        let catalog = try loadCatalog()
        let set = HeroAppearance.default(for: .scarredOnes).choosingSkin(.honey)
            .resolvedMaterials(forPart: "head", regionTones: [:])
        for variant in [2, 3] {
            let parts = catalog.parts(forPack: HeroRace.scarredOnes.artBase(variant: variant))
            for stem in ["head", "left_hand", "right_hand"] {
                #expect(LegacyRecolorPlanner.plan(race: .scarredOnes, variant: variant, stem: stem, materials: set, parts: parts).isEmpty,
                        "Dark Oracle \(variant) \(stem): the skin control is disabled, so a stored swatch must not recolor it")
            }
        }
        // The same choice does plan on Dark Oracle 1, whose face is skin-colored.
        let plan = LegacyRecolorPlanner.plan(
            race: .scarredOnes, variant: 1, stem: "head", materials: set, parts: catalog.parts(forPack: "dark_oracle_v1"))
        #expect(plan.map(\.region) == [.skin])
        #expect(plan.first?.source == .faceWindow(
            anatomySkinMask: "dark_oracle_v1_head_anatomy_mask_skin", headgearLayer: "dark_oracle_v1_head_headgear", headgearSkinMask: nil))
    }

    @Test func dyeIsNotPlannedWhereTheDyeControlIsUnavailable() throws {
        let catalog = try loadCatalog()
        var look = HeroAppearance.default(for: .golem)
        look.armorDye = .crimson
        func plan(_ race: HeroRace, _ variant: Int, _ stem: String) -> [PlannedRecolorRegion] {
            LegacyRecolorPlanner.plan(
                race: race, variant: variant, stem: stem,
                materials: look.resolvedMaterials(forPart: stem, regionTones: [:]),
                parts: catalog.parts(forPack: race.artBase(variant: variant)))
        }
        let dyeStems = ["body", "left_arm", "right_arm", "left_leg", "right_leg"]
        // Golem 1 has primary/secondary armor on both arms and a leg, but none on the body: the control is disabled.
        for stem in dyeStems { #expect(plan(.golem, 1, stem).isEmpty, "Golem 1 \(stem)") }
        // Skeleton Warrior 3 (Skeletal Undead variant 6): its right arm has a primary region, its body has none.
        for stem in dyeStems { #expect(plan(.skeletalUndead, 6, stem).isEmpty, "Skeleton Warrior 3 \(stem)") }
        // Golem 3's body has primary and secondary armor, so the same dye plans there.
        #expect(plan(.golem, 3, "body").map(\.region) == [.primary, .secondary])
    }

    @Test func aStoredCustomArmorColorStillAppliesWhereTheDyeControlIsUnavailable() throws {
        let parts = try loadCatalog().parts(forPack: "golem_v1")
        var look = HeroAppearance.default(for: .golem)
        look.materials = CharacterMaterialSet(
            armorPrimary: MaterialSelection(id: "custom", color: MaterialRGBA(red: 0.1, green: 0.2, blue: 0.3)))
        let plan = LegacyRecolorPlanner.plan(
            race: .golem, variant: 1, stem: "right_arm",
            materials: look.resolvedMaterials(forPart: "right_arm", regionTones: [:]), parts: parts)
        #expect(plan.map(\.region) == [.primary], "only the dye is gated; the Forge's own colors are not")
        #expect(plan.first?.source == .mask(resource: "golem_v1_right_arm_armor_mask_primary"))
    }

    @Test func nothingIsPlannedWhenCandidateMasksAreNotAllowed() throws {
        let parts = seerTwo(try loadCatalog())
        var look = HeroAppearance.default(for: .seer)
        look.armorDye = .verdigris
        let set = look.resolvedMaterials(forPart: "body", regionTones: seerTwoBodyTones)
        let allowed = LegacyRecolorPlanner.plan(
            race: .seer, variant: 2, stem: "body", materials: set, parts: parts, allowCandidateMasks: true)
        let refused = LegacyRecolorPlanner.plan(
            race: .seer, variant: 2, stem: "body", materials: set, parts: parts, allowCandidateMasks: false)
        #expect(allowed.count == 2)
        #expect(refused.isEmpty)
    }

    @Test func fingerprintFollowsOnlyTheRegionsAPartUses() throws {
        let parts = seerTwo(try loadCatalog())
        func fingerprint(skin: SkinTone?, dye: ArmorDye) -> String {
            var look = HeroAppearance.default(for: .seer)
            look.armorDye = dye
            look = look.choosingSkin(skin)
            let set = look.resolvedMaterials(forPart: "body", regionTones: seerTwoBodyTones)
            let plan = LegacyRecolorPlanner.plan(race: .seer, variant: 2, stem: "body", materials: set, parts: parts)
            return LegacyRecolorPlanner.fingerprint(plan: plan, materials: set)
        }
        let base = fingerprint(skin: .honey, dye: .verdigris)
        #expect(!base.isEmpty)
        #expect(base == fingerprint(skin: .ebony, dye: .verdigris), "the skin never touches the body, so it must not re-render it")
        #expect(base != fingerprint(skin: .honey, dye: .crimson), "a different dye must produce a different image")
    }
}

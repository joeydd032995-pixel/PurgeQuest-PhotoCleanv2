import Testing
import Foundation
@testable import PurgeQuest

/// Pure-logic tests for held-gear fitting, Titan scaling, recolor math, planner gating, persistence
/// migration, and Forge draft/save/ancestry behaviour. No UI, SwiftData, or bundle access.
struct ModularGearTests {

    // MARK: Titan Blade and held-gear fitting

    @Test func titanScaleMatchesTheStorePromise() {
        #expect(HeldGearFit.titanScale == 2)
        #expect(ModularAssetCatalog.empty.titanScale == 2)
    }

    @Test func offsetKeepsTheGripOnTheHoldAtEveryScale() throws {
        let hold = [52.1, 63.5], grip = [44.6, 64.0], pivot = [0.0, 0.0]
        for scale in [1.0, 1.5, 2.0] {
            let off = try #require(HeldGearFit.offset(hold: hold, grip: grip, pivotPx: pivot, scale: scale))
            // local position of the grip = scale * (grip - pivot) + offset must equal the hold
            #expect(abs(scale * (grip[0] - pivot[0]) + off.x - hold[0]) < 1e-9)
            #expect(abs(scale * (grip[1] - pivot[1]) + off.y - hold[1]) < 1e-9)
        }
    }

    @Test func offsetRejectsMalformedInput() {
        #expect(HeldGearFit.offset(hold: [1], grip: [1, 2], pivotPx: [0, 0], scale: 1) == nil)
        #expect(HeldGearFit.offset(hold: [1, 2], grip: [1, 2], pivotPx: [0, 0], scale: 0) == nil)
        #expect(HeldGearFit.offset(hold: [1, 2], grip: [1, 2], pivotPx: [0, 0], scale: .nan) == nil)
    }

    private func anchors() -> PackAnchors {
        PackAnchors(weaponAnchor: "sword", weaponPivotPx: [0, 0], weaponHold: [52.1, 63.5],
                    shieldAnchor: "shield", shieldPivotPx: [0, 0], shieldHold: [79.5, 79.5],
                    arrowNock: nil)
    }

    private func staff(slot: String = "mainHand", packs: [String] = ["valkyrie_v1"]) throws -> HeldGearEntry {
        let json = """
        {"id":"weapon.staff.1.1","name":"Ashen Bough I","kind":"staff","slot":"\(slot)","resourceName":"staff_1_1",
         "group":"staff1","imageWidth":400,"imageHeight":128,"gripPx":[44.6,64.0],"supportedPacks":\(packs.map { "\"\($0)\"" }.joined(separator: ",").wrapped)}
        """
        return try JSONDecoder().decode(HeldGearEntry.self, from: Data(json.utf8))
    }

    @Test func titanDoublesWeaponsAboutTheGripButNeverShields() throws {
        let item = try staff()
        let normal = try #require(HeldGearFit.placement(item: item, anchors: anchors(), pack: "valkyrie_v1", titan: false))
        let titan = try #require(HeldGearFit.placement(item: item, anchors: anchors(), pack: "valkyrie_v1", titan: true))
        #expect(normal.scale == 1)
        #expect(titan.scale == 2)
        // Grip stays on the hold in both.
        #expect(abs(2 * 44.6 + titan.offsetX - 52.1) < 1e-9)
        let shield = try staff(slot: "offHand")
        #expect(try #require(HeldGearFit.placement(item: shield, anchors: anchors(), pack: "valkyrie_v1", titan: true)).scale == 1)
    }

    @Test func bakedWeaponTitanScalesAboutItsOwnGrip() {
        let p = HeldGearFit.bakedWeaponPlacement(anchors: anchors(), titan: true)
        #expect(p.scale == 2)
        // hold + pivot is the baked grip; at scale 2 the grip stays on the hold: 2*hold + off == hold
        #expect(abs(2 * 52.1 + p.offsetX - 52.1) < 1e-9)
        #expect(abs(2 * 63.5 + p.offsetY - 63.5) < 1e-9)
        #expect(HeldGearFit.bakedWeaponPlacement(anchors: anchors(), titan: false).offsetX == 0)
    }

    @Test func unsupportedPackYieldsNoPlacement() throws {
        let item = try staff(packs: ["valkyrie_v1"])
        #expect(HeldGearFit.placement(item: item, anchors: anchors(), pack: "golem_v1", titan: false) == nil)
    }

    @Test func canvasLayoutKeepsTheCharacterSizeWhenTheCanvasGrows() {
        let layout = SpriteCanvasLayout.around(baseOrigin: (0, 0), baseSize: (100, 80), frameOrigin: (-20, -10), frameSize: (180, 130))
        #expect(layout == SpriteCanvasLayout(left: 20, top: 40, right: 60, bottom: 10))
        #expect(SpriteCanvasLayout.around(baseOrigin: (0, 0), baseSize: (100, 80), frameOrigin: (0, 0), frameSize: (100, 80)) == .zero)
        #expect(SpriteCanvasLayout.pointsPerUnit(height: 160, baseHeight: 80) == 2)
    }

    // MARK: Recolor math (OKLab)

    private let blue = MaterialRGBA(red: 0.15, green: 0.45, blue: 0.85)
    private let tone = RegionTone(lightness: 0.55, chroma: 0.04)

    /// Vectors produced by tools/modular_assets/imgops.py `recolor_pixels` (the offline reference).
    @Test func swiftRecolorMatchesThePythonReference() {
        let cases: [((Double, Double, Double), (Double, Double, Double), (Double, Double, Double))] = [
            ((0.5, 0.5, 0.5), (0.386066, 0.523885, 0.72084), (0.443033, 0.511943, 0.61042)),
            ((0.8, 0.2, 0.2), (0.007788, 0.448259, 0.933371), (0.403894, 0.32413, 0.566686)),
            ((0.2, 0.35, 0.6), (0.006171, 0.351848, 0.743256), (0.103085, 0.350924, 0.671628)),
            ((0.9, 0.9, 0.85), (0.862335, 0.918664, 0.999384), (0.881168, 0.909332, 0.924692))
        ]
        for (src, full, half) in cases {
            let a = RecolorMath.recolor(pixel: src, target: blue, tone: tone, mask: 1)
            let b = RecolorMath.recolor(pixel: src, target: blue, tone: tone, mask: 0.5)
            #expect(abs(a.r - full.0) < 1e-5 && abs(a.g - full.1) < 1e-5 && abs(a.b - full.2) < 1e-5, "full \(src)")
            #expect(abs(b.r - half.0) < 1e-5 && abs(b.g - half.1) < 1e-5 && abs(b.b - half.2) < 1e-5, "half \(src)")
        }
    }

    @Test func okLabRoundTripsAndStaysInGamut() {
        for src in [(0.5, 0.5, 0.5), (0.8, 0.2, 0.2), (0.05, 0.05, 0.07), (1, 1, 1), (0, 0, 0)] {
            let lab = RecolorMath.toOKLab(r: src.0, g: src.1, b: src.2)
            let back = RecolorMath.fromOKLab(l: lab.l, a: lab.a, b: lab.b)
            #expect(abs(back.r - src.0) < 1e-6 && abs(back.g - src.1) < 1e-6 && abs(back.b - src.2) < 1e-6)
        }
        for hue in stride(from: 0.0, to: 6.28, by: 0.7) {
            for lightness in [0.05, 0.3, 0.6, 0.95] {
                let c = RecolorMath.fitChroma(lightness: lightness, chroma: 0.6, hue: hue)
                let lin = RecolorMath.toLinear(l: lightness, a: c * cos(hue), b: c * sin(hue))
                #expect(min(lin.r, lin.g, lin.b) >= -1.1e-4 && max(lin.r, lin.g, lin.b) <= 1 + 1.1e-4)
            }
        }
    }

    @Test func recolorLeavesUnmaskedPixelsAlone() {
        let src = (r: 0.5, g: 0.4, b: 0.3)
        let out = RecolorMath.recolor(pixel: src, target: blue, tone: tone, mask: 0)
        #expect(out.r == src.r && out.g == src.g && out.b == src.b)
    }

    @Test func recolorPreservesShadingOrder() {
        // Brighter source pixels must stay brighter after recoloring (highlights and shadows survive).
        var previous = -1.0
        for value in stride(from: 0.2, through: 0.9, by: 0.1) {
            let out = RecolorMath.recolor(pixel: (value, value, value), target: blue, tone: tone, mask: 1)
            let lightness = RecolorMath.toOKLab(r: out.r, g: out.g, b: out.b).l
            #expect(lightness > previous, "lightness must increase with source brightness at \(value)")
            previous = lightness
        }
    }

    @Test func recolorTakesTheTargetHueAndHonoursGreyTargets() {
        let out = RecolorMath.recolor(pixel: (0.5, 0.5, 0.5), target: blue, tone: tone, mask: 1)
        let t = RecolorMath.toOKLab(r: blue.red, g: blue.green, b: blue.blue)
        let o = RecolorMath.toOKLab(r: out.r, g: out.g, b: out.b)
        #expect(abs(atan2(o.b, o.a) - atan2(t.b, t.a)) < 0.05)
        let grey = MaterialRGBA(red: 0.5, green: 0.5, blue: 0.5)
        let g = RecolorMath.recolor(pixel: (0.8, 0.3, 0.2), target: grey, tone: tone, mask: 1)
        #expect(abs(g.r - g.g) < 1e-3 && abs(g.g - g.b) < 1e-3, "a grey target gives grey")
    }

    @Test func partsOfOneMaterialKeepTheirRelativeBrightness() {
        // Two parts share a region tone; the one whose source was brighter stays brighter (no per-part re-centring).
        let brightPart = RecolorMath.recolor(pixel: (0.7, 0.7, 0.7), target: blue, tone: tone, mask: 1)
        let darkPart = RecolorMath.recolor(pixel: (0.35, 0.35, 0.35), target: blue, tone: tone, mask: 1)
        #expect(RecolorMath.toOKLab(r: brightPart.r, g: brightPart.g, b: brightPart.b).l
                > RecolorMath.toOKLab(r: darkPart.r, g: darkPart.g, b: darkPart.b).l + 0.1)
    }

    @Test func softLimitIsIdentityInsideAndBoundedOutside() {
        #expect(RecolorMath.softLimit(0.5) == 0.5)
        #expect(RecolorMath.softLimit(1.4) < 1 && RecolorMath.softLimit(1.4) > 0.9)
        #expect(RecolorMath.softLimit(-0.4) > 0 && RecolorMath.softLimit(-0.4) < 0.1)
        #expect(RegionTone(nil) == nil && RegionTone([0.5]) == nil && RegionTone([0.5, .nan]) == nil)
        #expect(RegionTone([0.55, 0.04]) == tone)
    }

    @Test func materialPaletteSetsReadsAndNormalizes() {
        let red = MaterialSelection(id: "custom", color: MaterialRGBA(red: 1, green: 0, blue: 0))
        let set = MaterialPalette.setting(nil, .primary, to: red)
        #expect(MaterialPalette.selection(set, .primary) == red)
        #expect(MaterialPalette.selection(set, .trim) == nil)
        #expect(MaterialPalette.normalized(MaterialPalette.setting(set, .primary, to: nil)) == nil)
        #expect(MaterialPalette.fingerprint(set) != MaterialPalette.fingerprint(nil))
    }

    // MARK: Planner gate

    private func slotManifests(status: AssetVerification, approved: [String] = [], profile: BodyProfile = .athletic, adapted: [BodyProfile] = []) -> [PartManifest] {
        CharacterRenderPlanner.mandatoryAnatomySlots.map { slot in
            PartManifest(id: "p.\(slot.rawValue)", resourceBaseName: "r", slot: slot, sourceRace: .valkyrie, referenceProfile: .athletic,
                         nativeProfiles: [.athletic], adaptedProfiles: adapted, verification: .init(status: status, approvedProfiles: approved))
        }
    }

    private func recipe(_ manifests: [PartManifest], profile: BodyProfile = .athletic) -> ModularCharacterRecipe {
        ModularCharacterRecipe(ancestry: .valkyrie, bodyProfile: profile, parts: manifests.map { .init(slot: $0.slot, partID: $0.id) })
    }

    @Test func candidateAssetsNeverActivateModularRendering() {
        let manifests = slotManifests(status: .candidate)
        let plan = CharacterRenderPlanner.plan(for: recipe(manifests), manifests: manifests)
        #expect(plan.path == .legacy)
        #expect(plan.reasons.contains("unverified:p.head"))
    }

    @Test func oneUnverifiedPartKeepsTheWholeRecipeOnLegacy() {
        var manifests = slotManifests(status: .verified)
        manifests[0] = PartManifest(id: manifests[0].id, resourceBaseName: "r", slot: manifests[0].slot, sourceRace: .valkyrie,
                                    referenceProfile: .athletic, nativeProfiles: [.athletic], verification: .init(status: .mapped))
        let plan = CharacterRenderPlanner.plan(for: recipe(manifests), manifests: manifests)
        #expect(plan.path == .legacy)
        #expect(plan.reasons.count == 1)
    }

    @Test func adaptedFitNeedsItsOwnApproval() {
        let standardAdapted = slotManifests(status: .verified, approved: [], adapted: [.standard])
        let unapproved = CharacterRenderPlanner.plan(for: recipe(standardAdapted, profile: .standard), manifests: standardAdapted)
        #expect(unapproved.path == .legacy)
        #expect(unapproved.reasons.contains { $0.hasPrefix("unapproved-fit:") })

        let approved = slotManifests(status: .verified, approved: ["standard"], adapted: [.standard])
        #expect(CharacterRenderPlanner.plan(for: recipe(approved, profile: .standard), manifests: approved).path == .modular)
    }

    @Test func unsafeProfilesStayUnsupportedEvenWhenVerified() {
        let manifests = slotManifests(status: .verified, approved: ["slender"], adapted: [.slender])
        // arm thickness 0.90/1.08 = 0.83 is outside the default 0.90...1.10 range
        let plan = CharacterRenderPlanner.plan(for: recipe(manifests, profile: .slender), manifests: manifests)
        #expect(plan.path == .legacy)
        #expect(plan.reasons.contains { $0.hasPrefix("unsupported:") })
    }

    @Test func legacyManifestsStillForceTheLegacyPath() {
        let migration = LegacyCharacterRecipeFactory.make(from: .default(for: .golem), fallbackRace: .valkyrie)
        #expect(CharacterRenderPlanner.plan(for: migration.recipe, manifests: migration.manifests).path == .legacy)
    }

    // MARK: Manifest decoding and fallback

    @Test func garbageManifestsYieldAnEmptyCatalogNotACrash() {
        let catalog = ModularAssetCatalog(racesData: Data("not json".utf8), gearData: Data("{}".utf8))
        #expect(catalog.parts.isEmpty)
        #expect(catalog.gearItems.isEmpty)
        #expect(catalog.gearItem(id: "weapon.staff.1.1") == nil)
        #expect(ModularAssetCatalog.empty.parts(forPack: "valkyrie_v1").isEmpty)
    }

    @Test func partManifestDecodesGeneratedJSONAndOlderJSON() throws {
        let generated = """
        {"id":"valkyrie_v1.body.armor","resourceBaseName":"valkyrie_v1_body_armor","slot":"chestArmor","rigID":"humanoid_v1",
         "sourceRace":"valkyrie","referenceProfile":"athletic","nativeProfiles":["athletic"],"adaptedProfiles":["standard"],
         "scaleXRange":{"min":0.9,"max":1.1},"scaleYRange":{"min":0.9,"max":1.1},
         "profileOverrides":{"standard":{"scaleX":0.96,"scaleY":1.0,"offsetX":0,"offsetY":0}},
         "coverageTags":["body","armor"],"materialRegions":["primary","trim"],"representation":"modular",
         "maskResources":{"primary":"valkyrie_v1_body_armor_mask_primary"},"regionTone":{"primary":[0.41,0.05]},
         "verification":{"status":"candidate","approvedBy":null,"automated":{"x":1}},
         "pack":"valkyrie_v1","part":"body","kind":"armor","paintVariant":1}
        """
        let part = try JSONDecoder().decode(PartManifest.self, from: Data(generated.utf8))
        #expect(part.slot == .chestArmor)
        #expect(part.verification.status == .candidate)
        #expect(part.maskResources["primary"] == "valkyrie_v1_body_armor_mask_primary")
        #expect(part.pack == "valkyrie_v1" && part.kind == "armor")

        // A pre-existing manifest without any of the additive keys decodes as `mapped`, never `verified`.
        let older = """
        {"id":"x","resourceBaseName":"x","slot":"head","rigID":"humanoid_v1","referenceProfile":"standard","nativeProfiles":["standard"],
         "adaptedProfiles":[],"scaleXRange":{"min":0.9,"max":1.1},"scaleYRange":{"min":0.9,"max":1.1},"profileOverrides":{},
         "coverageTags":[],"materialRegions":[],"representation":"modular"}
        """
        #expect(try JSONDecoder().decode(PartManifest.self, from: Data(older.utf8)).verification.status == .mapped)
    }

    // MARK: Persistence and migration

    @Test func v3SavesDecodeInPlaceWithoutMaterials() {
        let v3 = Data(#"{"schemaVersion":3,"race":"seer","paintVariant":2,"skinTone":"honey","armorDye":"crimson"}"#.utf8)
        let look = HeroAppearance.decode(v3, for: .knight)
        #expect(look.schemaVersion == 3)
        #expect(look.race == .seer && look.paintVariant == 2 && look.skinTone == .honey && look.armorDye == .crimson)
        #expect(look.materials == nil && look.gearMaterials == nil)
    }

    @Test func materialsRoundTripThroughTheSaveSeam() {
        var look = HeroAppearance.default(for: .vampyri)
        look.gearMaterials = MaterialPalette.setting(nil, .primary, to: .init(id: "custom", color: MaterialRGBA(red: 0.2, green: 0.4, blue: 0.9)))
        look.materials = MaterialPalette.setting(nil, .skin, to: .init(id: "custom", color: MaterialRGBA(red: 0.9, green: 0.7, blue: 0.5)))
        let back = HeroAppearance.decode(look.encoded(), for: .knight)
        #expect(back == look)
        #expect(HeroAppearance.currentSchemaVersion == 4)
    }

    @Test func corruptMaterialsDecodeToNilAndKeepEveryOtherTrait() {
        let data = Data(#"{"schemaVersion":4,"race":"golem","skinTone":"ashen","materials":{"skin":"nope"},"gearMaterials":42}"#.utf8)
        let look = HeroAppearance.decode(data, for: .knight)
        #expect(look.race == .golem && look.skinTone == .ashen)
        #expect(look.materials == nil && look.gearMaterials == nil)
    }

    // MARK: Forge draft, save, ancestry

    @Test func draftIsDirtyOnlyWhenSomethingChanged() {
        let base = ForgeDraft(appearance: .default(for: .valkyrie), equipped: ["weapon": "weapon.shard"])
        var edited = base
        #expect(!edited.isDirty(comparedTo: base))
        edited.equip("weapon.staff.1.1", slot: "weapon")
        #expect(edited.isDirty(comparedTo: base))
        edited.equip("weapon.shard", slot: "weapon")
        #expect(!edited.isDirty(comparedTo: base))
        edited.equip(nil, slot: "weapon")
        #expect(edited.equipped.isEmpty)
    }

    private struct DiskFull: LocalizedError { var errorDescription: String? { "The disk is full." } }

    @Test func saveCommitsAndDoesNotRollBack() {
        var applied = 0, persisted = 0, rolledBack = 0
        let outcome = ForgeSaveCoordinator.commit(apply: { applied += 1 }, persist: { persisted += 1 }, rollback: { rolledBack += 1 })
        #expect(outcome == .saved)
        #expect(applied == 1 && persisted == 1 && rolledBack == 0)
    }

    @Test func failedSaveRestoresStateAndSurfacesTheError() {
        var state = "old"
        let outcome = ForgeSaveCoordinator.commit(
            apply: { state = "new" },
            persist: { throw DiskFull() },
            rollback: { state = "old" }
        )
        #expect(outcome == .failed(message: "The disk is full."))
        #expect(state == "old")
    }

    @Test func ancestryChoicesAreExplicit() {
        var custom = HeroAppearance.default(for: .valkyrie)
        custom.eyeColor = .crimson
        custom.paintVariant = 3
        custom.materials = MaterialPalette.setting(nil, .skin, to: .init(id: "custom", color: MaterialRGBA(red: 0.5, green: 0.5, blue: 0.5)))

        #expect(!AncestryChange.hasCustomization(.default(for: .valkyrie), currentRace: .valkyrie))
        #expect(AncestryChange.hasCustomization(custom, currentRace: .valkyrie))

        #expect(AncestryChange.apply(.cancel, to: custom, newRace: .golem) == custom)
        #expect(AncestryChange.apply(.wholeLook, to: custom, newRace: .golem) == .default(for: .golem))

        let anatomy = AncestryChange.apply(.anatomyOnly, to: custom, newRace: .golem)
        #expect(anatomy.race == .golem)
        #expect(anatomy.eyeColor == .crimson && anatomy.materials == custom.materials)
        #expect(anatomy.paintVariant == 3)

        var skeletal = custom
        skeletal.race = .skeletalUndead
        skeletal.paintVariant = 5
        #expect(AncestryChange.apply(.anatomyOnly, to: skeletal, newRace: .valkyrie).paintVariant == 3) // clamped to the new race's variants
    }

    @Test func packIDsMatchTheManifestNaming() {
        #expect(GearCompatibility.packID(race: .elven, variant: 3) == "forest_ranger_v3")
        #expect(GearCompatibility.packID(race: .skeletalUndead, variant: 5) == "skeleton_warrior_v2")
        #expect(GearCompatibility.packID(race: .vampyri, variant: 1) == "blood_alchemist_v1")
    }

    @Test func attackAnimationFollowsWhatTheVariantShips() {
        #expect(HeroRace.elven.attackAnimationName(variant: 1) == "Shooting")
        #expect(HeroRace.elven.attackAnimationName(variant: 2) == "Shooting")
        #expect(HeroRace.elven.attackAnimationName(variant: 3) == "Slashing")   // sword pack: no Shooting animation
        #expect(HeroRace.valkyrie.attackAnimationName(variant: 2) == "Slashing")
    }
}

private extension String {
    var wrapped: String { "[\(self)]" }
}

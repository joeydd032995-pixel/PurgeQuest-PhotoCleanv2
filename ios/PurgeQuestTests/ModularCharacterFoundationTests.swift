import Testing
import Foundation
@testable import PurgeQuest

struct ModularCharacterFoundationTests {
    @Test func legacyRecipePreservesRaceVariantAndUsesLegacyFallback() {
        var look = HeroAppearance.default(for: .vampyri)
        look.paintVariant = 2
        let migration = LegacyCharacterRecipeFactory.make(from: look, fallbackRace: .valkyrie)

        #expect(migration.recipe.ancestry == .vampyri)
        #expect(migration.recipe.bodyProfile == .athletic)
        #expect(migration.recipe.partID(for: .head) == "legacy.blood_alchemist_v2.head")
        #expect(migration.manifests.first(where: { $0.slot == .head })?.resourceBaseName == "blood_alchemist_v2_head")

        let plan = CharacterRenderPlanner.plan(for: migration.recipe, manifests: migration.manifests)
        #expect(plan.path == .legacy)
        #expect(plan.reasons.contains("legacy:legacy.blood_alchemist_v2.head"))
    }

    @Test func compatibilityDistinguishesNativeAdaptedAndUnsupported() {
        let manifest = PartManifest(
            id: "anatomy.skeletal.arm.01",
            resourceBaseName: "skeletal_arm_01",
            slot: .leftArm,
            referenceProfile: .skeletal,
            nativeProfiles: [.skeletal],
            adaptedProfiles: [.standard],
            scaleXRange: .init(min: 0.70, max: 1.35),
            scaleYRange: .init(min: 0.90, max: 1.10)
        )

        let skeletal = ModularCharacterRecipe(ancestry: .skeletalUndead, bodyProfile: .skeletal, parts: [])
        let standard = ModularCharacterRecipe(ancestry: .scarredOnes, bodyProfile: .standard, parts: [])
        let brute = ModularCharacterRecipe(ancestry: .golem, bodyProfile: .brute, parts: [])

        #expect(CharacterCompatibilityResolver.level(for: manifest, recipe: skeletal) == .native)
        #expect(CharacterCompatibilityResolver.level(for: manifest, recipe: standard) == .adapted)
        #expect(CharacterCompatibilityResolver.level(for: manifest, recipe: brute) == .unsupported)
    }

    @Test func fitterUsesProfileOverrideAndRejectsUnsafeScale() {
        let overrideManifest = PartManifest(
            id: "armor.test",
            resourceBaseName: "armor_test",
            slot: .chestArmor,
            referenceProfile: .standard,
            nativeProfiles: [.standard],
            adaptedProfiles: [.brute],
            scaleXRange: .init(min: 0.8, max: 1.2),
            scaleYRange: .init(min: 0.8, max: 1.2),
            profileOverrides: [
                BodyProfile.brute.rawValue: .init(scaleX: 1.08, scaleY: 1.02, offsetX: 4, offsetY: -7)
            ]
        )
        #expect(PartFitter.fit(overrideManifest, to: .brute) == .init(scaleX: 1.08, scaleY: 1.02, offsetX: 4, offsetY: -7))

        let unsafe = PartManifest(
            id: "armor.unsafe",
            resourceBaseName: "armor_unsafe",
            slot: .leftArm,
            referenceProfile: .skeletal,
            nativeProfiles: [.skeletal],
            adaptedProfiles: [.brute],
            scaleXRange: .init(min: 0.95, max: 1.05),
            scaleYRange: .init(min: 0.95, max: 1.05)
        )
        #expect(PartFitter.fit(unsafe, to: .brute) == nil)
    }

    @Test func renderPlannerAllowsCompleteModularRecipe() {
        let manifests = CharacterRenderPlanner.mandatoryAnatomySlots.map { slot in
            PartManifest(id: "anatomy.valkyrie.\(slot.rawValue).01", resourceBaseName: "valkyrie_\(slot.rawValue)_01", slot: slot, sourceRace: .valkyrie, referenceProfile: .athletic, nativeProfiles: [.athletic])
        }
        let recipe = ModularCharacterRecipe(
            ancestry: .valkyrie,
            bodyProfile: .athletic,
            parts: manifests.map { .init(slot: $0.slot, partID: $0.id) }
        )
        #expect(CharacterRenderPlanner.plan(for: recipe, manifests: manifests) == .init(path: .modular, reasons: []))
    }

    @Test func renderPlannerRejectsIncompleteDuplicateAndMismatchedSelections() {
        let head = PartManifest(id: "head", resourceBaseName: "head", slot: .head)
        let torso = PartManifest(id: "torso", resourceBaseName: "torso", slot: .torso)
        let recipe = ModularCharacterRecipe(ancestry: .valkyrie, bodyProfile: .standard, parts: [
            .init(slot: .head, partID: torso.id),
            .init(slot: .head, partID: head.id)
        ])
        let plan = CharacterRenderPlanner.plan(for: recipe, manifests: [head, torso])
        #expect(plan.path == .legacy)
        #expect(plan.reasons.contains("duplicate-slot:head"))
        #expect(plan.reasons.contains("slot-mismatch:head:torso"))
        #expect(plan.reasons.contains("missing-slot:torso"))
    }

    @Test func renderPlannerTreatsDuplicateManifestIDsAsAmbiguousWithoutCrashing() {
        let duplicate = PartManifest(id: "duplicate", resourceBaseName: "first", slot: .head)
        let other = PartManifest(id: "duplicate", resourceBaseName: "second", slot: .head)
        let recipe = ModularCharacterRecipe(ancestry: .valkyrie, bodyProfile: .standard, parts: [.init(slot: .head, partID: "duplicate")])
        let plan = CharacterRenderPlanner.plan(for: recipe, manifests: [duplicate, other])
        #expect(plan.path == .legacy)
        #expect(plan.reasons.contains("ambiguous:duplicate"))
    }

    @Test func fingerprintIsStableAcrossPartOrdering() {
        let a = CharacterPartSelection(slot: .head, partID: "head.a")
        let b = CharacterPartSelection(slot: .torso, partID: "torso.b")
        let first = ModularCharacterRecipe(ancestry: .valkyrie, bodyProfile: .athletic, parts: [a, b])
        let second = ModularCharacterRecipe(ancestry: .valkyrie, bodyProfile: .athletic, parts: [b, a])
        #expect(first.renderFingerprint == second.renderFingerprint)
    }

    @Test func materialRGBAClampsChannels() {
        let color = MaterialRGBA(red: -0.5, green: 0.4, blue: 1.7, alpha: 2)
        #expect(color.red == 0)
        #expect(color.green == 0.4)
        #expect(color.blue == 1)
        #expect(color.alpha == 1)
    }

    @Test func materialRGBADecodingClampsChannels() throws {
        let data = Data(#"{"red":-0.5,"green":0.4,"blue":1.7,"alpha":2}"#.utf8)
        let color = try JSONDecoder().decode(MaterialRGBA.self, from: data)
        #expect(color == MaterialRGBA(red: 0, green: 0.4, blue: 1, alpha: 1))
    }

    @Test func fingerprintCannotBeConfusedByDelimiterCharactersInPartIDs() {
        let injected = ModularCharacterRecipe(ancestry: .valkyrie, bodyProfile: .athletic, parts: [.init(slot: .head, partID: "x|torso=y")])
        let separate = ModularCharacterRecipe(ancestry: .valkyrie, bodyProfile: .athletic, parts: [.init(slot: .head, partID: "x"), .init(slot: .torso, partID: "y")])
        #expect(injected.renderFingerprint != separate.renderFingerprint)
    }

    @Test func defaultBodyProfilesKeepExtremeRacesOnCanonicalRig() {
        #expect(HeroRace.skeletalUndead.defaultBodyProfile == .skeletal)
        #expect(HeroRace.golem.defaultBodyProfile == .brute)
        #expect(HeroRace.elven.defaultBodyProfile == .slender)
        #expect(HeroRace.valkyrie.defaultBodyProfile == .athletic)
    }
}

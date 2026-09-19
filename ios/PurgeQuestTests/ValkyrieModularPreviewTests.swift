import Testing
@testable import PurgeQuest

struct ValkyrieModularPreviewTests {
    @Test func valkyrieV1DefinesEightModularAnatomyParts() {
        let manifests = ValkyrieV1ModularAssetSet.manifests
        #expect(manifests.count == 8)
        #expect(Set(manifests.map(\.slot)) == Set([
            .head, .torso, .leftArm, .rightArm,
            .leftHand, .rightHand, .leftLeg, .rightLeg
        ]))
        #expect(manifests.allSatisfy { $0.rigID == ModularCharacterRecipe.canonicalRigID })
        #expect(manifests.allSatisfy { $0.sourceRace == .valkyrie })
        #expect(manifests.allSatisfy { $0.referenceProfile == .athletic })
        #expect(manifests.allSatisfy { $0.nativeProfiles == [.athletic] })
        #expect(manifests.allSatisfy { $0.representation == .modular })
    }

    @Test func valkyrieV1RecipePassesModularPlanner() {
        #expect(ValkyrieV1ModularAssetSet.recipe.rigID == "humanoid_v1")
        #expect(ValkyrieV1ModularAssetSet.recipe.bodyProfile == .athletic)
        #expect(ValkyrieV1ModularAssetSet.renderPlan.path == .modular)
        #expect(ValkyrieV1ModularAssetSet.renderPlan.reasons.isEmpty)
    }

    @Test func scmlFileNamesResolveToMigratedResources() {
        #expect(ValkyrieV1ModularAssetSet.resourceBaseName(forSCMLFileName: "Body.png") == "valkyrie_v1_body")
        #expect(ValkyrieV1ModularAssetSet.resourceBaseName(forSCMLFileName: "Left Arm.png") == "valkyrie_v1_left_arm")
        #expect(ValkyrieV1ModularAssetSet.resourceBaseName(forSCMLFileName: "Right Hand.png") == "valkyrie_v1_right_hand")
        #expect(ValkyrieV1ModularAssetSet.resourceBaseName(forSCMLFileName: "Face 01.png") == nil)
        #expect(ValkyrieV1ModularAssetSet.resourceBaseName(forSCMLFileName: "Sword.png") == nil)
    }

    @Test func previewGateAllowsOnlyValkyrieV1() {
        #expect(ValkyrieV1ModularAssetSet.previewPlan(race: .valkyrie, variant: 1).path == .modular)
        #expect(ValkyrieV1ModularAssetSet.previewPlan(race: .valkyrie, variant: 2).path == .legacy)
        #expect(ValkyrieV1ModularAssetSet.previewPlan(race: .golem, variant: 1).path == .legacy)
    }

    @Test func crossProfileCompatibilityIsExplicit() {
        let standardRecipe = ModularCharacterRecipe(
            ancestry: .valkyrie,
            bodyProfile: .standard,
            parts: ValkyrieV1ModularAssetSet.recipe.parts
        )
        let bruteRecipe = ModularCharacterRecipe(
            ancestry: .valkyrie,
            bodyProfile: .brute,
            parts: ValkyrieV1ModularAssetSet.recipe.parts
        )
        let torso = ValkyrieV1ModularAssetSet.manifests.first { $0.slot == .torso }!

        #expect(CharacterCompatibilityResolver.level(for: torso, recipe: standardRecipe) == .adapted)
        #expect(CharacterCompatibilityResolver.level(for: torso, recipe: bruteRecipe) == .unsupported)
    }
}

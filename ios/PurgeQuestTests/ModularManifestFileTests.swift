import Testing
import Foundation
@testable import PurgeQuest

/// Reads the generated manifests straight from the repository (tools/modular_assets output) so structural
/// problems fail here even before an Xcode build bundles them. Bundle/resource presence is covered by
/// ModularAssetBundleTests, which needs the app bundle.
struct ModularManifestFileTests {
    /// Repository root: `PQ_REPO_ROOT` when set (the Linux harness links the test file elsewhere), else derived from this file.
    private static let repoRoot: URL = {
        if let root = ProcessInfo.processInfo.environment["PQ_REPO_ROOT"] { return URL(fileURLWithPath: root) }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }()
    private static let modularDir = repoRoot.appendingPathComponent("ios/PurgeQuest/Art/Modular")
    private static let ledgerURL = repoRoot.appendingPathComponent("docs/modular/approvals.json")

    private static func load() throws -> ModularAssetCatalog {
        let races = try Data(contentsOf: modularDir.appendingPathComponent("modular_races_manifest.json"))
        let gear = try Data(contentsOf: modularDir.appendingPathComponent("modular_gear_manifest.json"))
        return ModularAssetCatalog(racesData: races, gearData: gear)
    }

    private static func rawCount(_ file: String, key: String) throws -> Int {
        let data = try Data(contentsOf: modularDir.appendingPathComponent(file))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return (object[key] as? [Any])?.count ?? -1
    }

    @Test func everyGeneratedPartAndGearItemDecodes() throws {
        let catalog = try Self.load()
        #expect(catalog.parts.count == (try Self.rawCount("modular_races_manifest.json", key: "parts")))
        #expect(catalog.gearItems.count == (try Self.rawCount("modular_gear_manifest.json", key: "items")))
        #expect(catalog.parts.count > 400)
        #expect(catalog.gearItems.count == 8 + 80 + 14)
    }

    @Test func nothingIsVerifiedWithoutALedgerApproval() throws {
        let catalog = try Self.load()
        let ledger = (try? Data(contentsOf: Self.ledgerURL))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        let approved = Set(((ledger?["approvals"] as? [[String: Any]]) ?? []).compactMap { $0["assetId"] as? String })
        for part in catalog.parts where part.verification.status == .verified {
            #expect(approved.contains(part.id), "\(part.id) is verified without a recorded approval")
        }
        for item in catalog.gearItems where item.verification.status == .verified {
            #expect(approved.contains(item.id), "\(item.id) is verified without a recorded approval")
        }
    }

    @Test func everyPackHasACompleteDefaultRecipeAndStaysLegacyUntilApproved() throws {
        let catalog = try Self.load()
        let packs = Set(catalog.parts.compactMap(\.pack))
        #expect(packs.count == 27)
        for pack in packs.sorted() {
            let layers = catalog.parts(forPack: pack).filter { $0.kind != "face" }
            let race = try #require(layers.first?.sourceRace)
            let recipe = ModularCharacterRecipe(
                ancestry: race, bodyProfile: race.defaultBodyProfile,
                parts: layers.map { CharacterPartSelection(slot: $0.slot, partID: $0.id) })

            // As shipped (candidates): legacy renderer, with "unverified" reasons only.
            let shipped = CharacterRenderPlanner.plan(for: recipe, manifests: layers)
            if layers.contains(where: { $0.verification.status != .verified }) {
                #expect(shipped.path == .legacy, "\(pack)")
                #expect(shipped.reasons.allSatisfy { $0.hasPrefix("unverified:") }, "\(pack): \(shipped.reasons)")
            }

            // Rehearsal: if every layer were approved, the recipe must be structurally complete and modular.
            let rehearsal = layers.map { $0.replacingVerification(.init(status: .verified)) }
            let plan = CharacterRenderPlanner.plan(for: recipe, manifests: rehearsal)
            #expect(plan.path == .modular, "\(pack): \(plan.reasons)")
        }
    }

    @Test func everyAdaptedFitIsInsideItsSafeRange() throws {
        for part in try Self.load().parts {
            for profile in part.adaptedProfiles {
                let override = try #require(part.profileOverrides[profile.rawValue], "\(part.id) \(profile)")
                #expect(part.scaleXRange.contains(override.scaleX) && part.scaleYRange.contains(override.scaleY), "\(part.id) \(profile)")
                let fit = PartFitter.fit(part, to: profile)
                #expect(fit != nil, "\(part.id) \(profile) must resolve through PartFitter")
            }
            #expect(part.nativeProfiles.contains(part.referenceProfile) || part.kind == "face")
        }
    }

    @Test func titanScalingIsDefinedForEveryWeaponOnEverySupportedPack() throws {
        let catalog = try Self.load()
        let weapons = catalog.gearItems.filter { $0.slot == "mainHand" }
        #expect(weapons.count == 8 + 40 + 9)
        for item in weapons {
            #expect(!item.supportedPacks.isEmpty)
            for pack in item.supportedPacks {
                let anchors = try #require(catalog.anchors(pack: pack), "\(pack)")
                let titan = try #require(HeldGearFit.placement(item: item, anchors: anchors, pack: pack, titan: true), "\(item.id) \(pack)")
                #expect(titan.scale == item.scale * HeldGearFit.titanScale)
                // grip stays on the hold at 2x
                let off = try #require(HeldGearFit.offset(hold: anchors.weaponHold, grip: item.gripPx, pivotPx: anchors.weaponPivotPx, scale: titan.scale))
                #expect(abs(titan.offsetX - off.x) < 1e-9 && abs(titan.offsetY - off.y) < 1e-9)
            }
        }
    }

    @Test func theElvenRecurveIsBowOnlyAndNeverOnTheSwordPack() throws {
        let catalog = try Self.load()
        let bow = try #require(catalog.gearItem(id: "weapon.forest_ranger"))
        #expect(bow.kind == .bow)
        #expect(Set(bow.supportedPacks) == ["forest_ranger_v1", "forest_ranger_v2"])
        #expect(bow.stringAnchors != nil)
        #expect(catalog.anchors(pack: "forest_ranger_v1")?.arrowNock != nil)
        for item in catalog.gearItems where item.kind != .bow && item.kind != .headpiece && item.slot == "mainHand" {
            #expect(item.supportedPacks.contains("forest_ranger_v3"), "\(item.id) must work on the Elven sword pack")
        }
    }

    @Test func everyStoreItemIsMappedAndEveryPackHasHeadFit() throws {
        let catalog = try Self.load()
        let storeIDs = ["head.starhat", "head.hood", "head.dragoncrest",
                        "weapon.shard", "weapon.reel", "weapon.gem", "weapon.staff", "weapon.stormblade",
                        "weapon.chevron", "weapon.ruby", "weapon.arcane", "weapon.fireworkBlade",
                        "shield.crux", "shield.templar"]
        for id in storeIDs {
            let item = try #require(catalog.gearItem(id: id), "\(id)")
            #expect(!item.maskResources.isEmpty, "\(id) needs recolor masks")
        }
        for pack in Set(catalog.parts.compactMap(\.pack)) {
            #expect(catalog.anchors(pack: pack)?.headFit.widthPx ?? 0 > 0, "\(pack)")
        }
        #expect(catalog.gear?.headpieceNominal != nil)
    }
}

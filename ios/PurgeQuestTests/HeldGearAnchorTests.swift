//
//  HeldGearAnchorTests.swift
//  PurgeQuestTests
//
//  Where a shield hangs. Every art pack bakes its sword into the Left Hand, so a shield held in that
//  hand sat on top of the blade. It now goes in the Right Hand, which is where the two packs that bake
//  a shield (Valkyrie, Skeleton Crusader) already put theirs. Needs the app bundle for the real art.
//

import Testing
import Foundation
import CoreGraphics
@testable import PurgeQuest

@MainActor
struct HeldGearAnchorTests {

    private func part(_ name: String, x: CGFloat = 0, y: CGFloat = 0) -> SpritePlacement {
        SpritePlacement(
            file: SpriteFileDef(name: name, width: 40, height: 40, pivotX: 0.5, pivotY: 0.5),
            x: x, y: y, angle: 0, pivotX: 0.5, pivotY: 0.5, zIndex: 0, alpha: 1
        )
    }

    @Test func stemsMatchTheManifestNaming() {
        #expect(HeldGearAnchors.stem(of: "Left Hand.png") == "left_hand")
        #expect(HeldGearAnchors.stem(of: "Right Hand.png") == "right_hand")
        #expect(HeldGearAnchors.stem(of: "Shield.png") == "shield")
        #expect(HeldGearAnchors.stem(of: "Face 01.png") == "face_01")
    }

    @Test func theWeaponAnchorIsTheSwordOrTheBow() {
        let sword = [part("Body.png"), part("Sword.png", x: 5), part("Left Hand.png")]
        #expect(HeldGearAnchors.weapon(in: sword)?.x == 5)
        let bow = [part("Body.png"), part("Bow.png", x: 7), part("Arrow.png")]
        #expect(HeldGearAnchors.weapon(in: bow)?.x == 7)
        #expect(HeldGearAnchors.weapon(in: [part("Body.png")]) == nil)
    }

    @Test func aBakedShieldIsUsedBeforeAnyHand() {
        let frame = [part("Body.png"), part("Left Hand.png"), part("Right Hand.png"), part("Shield.png", x: 9)]
        #expect(HeldGearAnchors.shield(in: frame, manifestStem: "shield")?.x == 9)
        #expect(HeldGearAnchors.shield(in: frame, manifestStem: "right_hand")?.x == 9)
        #expect(HeldGearAnchors.shield(in: frame, manifestStem: nil)?.x == 9)
    }

    @Test func withoutABakedShieldTheShieldGoesInTheHandTheManifestNames() {
        let frame = [part("Body.png"), part("Left Hand.png", x: 1), part("Right Hand.png", x: 2), part("Sword.png", x: 3)]
        #expect(HeldGearAnchors.shield(in: frame, manifestStem: "right_hand")?.x == 2)
        // The manifest decides: naming the other hand is honored.
        #expect(HeldGearAnchors.shield(in: frame, manifestStem: "left_hand")?.x == 1)
        // No manifest entry: the Right Hand, never the sword's hand.
        #expect(HeldGearAnchors.shield(in: frame, manifestStem: nil)?.x == 2)
    }

    @Test func aMissingAnchorMeansNoShieldNotACrash() {
        #expect(HeldGearAnchors.shield(in: [part("Body.png"), part("Left Hand.png")], manifestStem: "right_hand") == nil)
        #expect(HeldGearAnchors.shield(in: [], manifestStem: nil) == nil)
    }

    /// The regression this exists for, checked on the shipped art: in the idle pose and in every frame of the
    /// attack, the shield's anchor is well away from the sword's. With the old Left Hand rule the closest pair
    /// was 23 units apart (on top of each other); with the Right Hand the closest is 148.
    @Test func theShieldAndTheSwordNeverShareAHandInAnyShippedPack() throws {
        let renderer = SpriteRenderer.shared
        var checked = 0
        for race in HeroRace.allCases {
            for variant in 1...race.variantCount {
                let pack = race.artBase(variant: variant)
                let doc = try #require(renderer.document(race: race, variant: variant), "\(pack) did not load")
                let stem = ModularAssetCatalog.shared.anchors(pack: pack)?.shieldAnchor
                #expect(stem != nil, "\(pack) has no manifest anchors")
                for animation in ["Idle", renderer.attackAnimation(race: race, variant: variant)] {
                    let frames = try #require(doc.animations[animation]?.frames, "\(pack) has no \(animation)")
                    for (index, frame) in frames.enumerated() {
                        let shield = try #require(HeldGearAnchors.shield(in: frame, manifestStem: stem),
                                                  "\(pack) \(animation) \(index): no shield anchor")
                        let weapon = try #require(HeldGearAnchors.weapon(in: frame),
                                                  "\(pack) \(animation) \(index): no weapon anchor")
                        let apart = hypot(shield.x - weapon.x, shield.y - weapon.y)
                        #expect(apart > 80, "\(pack) \(animation) \(index): shield and weapon anchors only \(Int(apart)) apart")
                        checked += 1
                    }
                }
            }
        }
        #expect(checked > 100)
    }

    @Test func everyPacksManifestAnchorIsTheBakedShieldOrTheRightHand() {
        for race in HeroRace.allCases {
            for variant in 1...race.variantCount {
                let pack = race.artBase(variant: variant)
                let stem = ModularAssetCatalog.shared.anchors(pack: pack)?.shieldAnchor
                #expect(stem == "shield" || stem == HeldGearAnchors.defaultShieldHand, "\(pack): \(stem ?? "nil")")
            }
        }
    }
}

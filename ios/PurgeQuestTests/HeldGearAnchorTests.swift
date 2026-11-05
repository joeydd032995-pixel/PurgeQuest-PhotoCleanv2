//
//  HeldGearAnchorTests.swift
//  PurgeQuestTests
//
//  Where held gear hangs and how it is layered.
//
//  Shield: every art pack bakes its sword into the Left Hand, so a shield held in that hand sat on top of
//  the blade. It now goes in the Right Hand, which is where the two packs that bake a shield (Valkyrie,
//  Skeleton Crusader) already put theirs.
//
//  Weapon: a swapped-in sword was pasted on top of the whole character, so it floated in front of the
//  body instead of being held. It now takes the layer the pack gives its own weapon in an attack (behind
//  the hand, the arm and the body), and in the idle pose the weapon hand is drawn again over its grip.
//
//  Needs the app bundle for the real art.
//

import Testing
import Foundation
import CoreGraphics
@testable import PurgeQuest

@MainActor
struct HeldGearAnchorTests {

    private func part(_ name: String, x: CGFloat = 0, y: CGFloat = 0, z: Int = 0, alpha: CGFloat = 1) -> SpritePlacement {
        SpritePlacement(
            file: SpriteFileDef(name: name, width: 40, height: 40, pivotX: 0.5, pivotY: 0.5),
            x: x, y: y, angle: 0, pivotX: 0.5, pivotY: 0.5, zIndex: z, alpha: alpha
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

    // MARK: The weapon is held, not pasted on

    @Test func aFrameIsArmedOnlyWhenThePacksOwnWeaponIsVisible() {
        #expect(HeldGearAnchors.isArmed([part("Body.png"), part("Sword.png"), part("Left Hand.png")]))
        #expect(HeldGearAnchors.isArmed([part("Bow.png", alpha: 0.5), part("Arrow.png")]))
        // The idle pose keeps the sword in the rig with alpha 0.
        #expect(!HeldGearAnchors.isArmed([part("Body.png"), part("Sword.png", alpha: 0), part("Left Hand.png")]))
        #expect(!HeldGearAnchors.isArmed([part("Body.png"), part("Left Hand.png")]))
        #expect(!HeldGearAnchors.isArmed([]))
    }

    @Test func theWeaponHandIsTheOneTheManifestNamesAndItMustBeVisible() {
        let frame = [part("Left Hand.png", x: 1), part("Right Hand.png", x: 2)]
        #expect(HeldGearAnchors.weaponHand(in: frame, manifestStem: "left_hand")?.x == 1)
        #expect(HeldGearAnchors.weaponHand(in: frame, manifestStem: "right_hand")?.x == 2)
        // No manifest entry: the Left Hand, where every pack bakes its sword.
        #expect(HeldGearAnchors.weaponHand(in: frame, manifestStem: nil)?.x == 1)
        // A hidden hand cannot close over a grip.
        #expect(HeldGearAnchors.weaponHand(in: [part("Left Hand.png", alpha: 0)], manifestStem: "left_hand") == nil)
        #expect(HeldGearAnchors.weaponHand(in: [], manifestStem: nil) == nil)
    }

    @Test func manifestsWithoutAWeaponHandStillDecode() throws {
        // A manifest written before the field existed decodes, and means the Left Hand.
        let json = """
        {"weaponAnchor":"sword","weaponPivotPx":[0,0],"weaponHold":[1,2],"shieldAnchor":"right_hand","shieldPivotPx":[0,0],"shieldHold":[3,4]}
        """
        let old = try JSONDecoder().decode(PackAnchors.self, from: Data(json.utf8))
        #expect(old.weaponHand == nil)
        #expect(HeldGearAnchors.weaponHand(in: [part("Left Hand.png", x: 7)], manifestStem: old.weaponHand)?.x == 7)
    }

    @Test func everyPackNamesTheHandThatHoldsItsWeapon() {
        for race in HeroRace.allCases {
            for variant in 1...race.variantCount {
                let pack = race.artBase(variant: variant)
                #expect(ModularAssetCatalog.shared.anchors(pack: pack)?.weaponHand == "left_hand", "\(pack)")
            }
        }
    }

    /// The layering rule the renderer relies on, checked on every frame of every animation of every shipped pack.
    /// Where the pack draws its own weapon, that weapon is behind the hand and the body, so only the blade shows and
    /// the fist covers the grip; the swapped weapon takes exactly that layer. Everywhere else the pack draws no weapon,
    /// and the weapon hand is there to be drawn again over a swapped-in grip.
    @Test func everyShippedFrameHidesTheBakedGripOrHasAHandToCloseOverOne() throws {
        let renderer = SpriteRenderer.shared
        var armedFrames = 0
        var emptyHandedFrames = 0
        for race in HeroRace.allCases {
            for variant in 1...race.variantCount {
                let pack = race.artBase(variant: variant)
                let doc = try #require(renderer.document(race: race, variant: variant), "\(pack) did not load")
                let handStem = ModularAssetCatalog.shared.anchors(pack: pack)?.weaponHand
                for (name, animation) in doc.animations {
                    for (index, frame) in animation.frames.enumerated() {
                        let label = "\(pack) \(name) \(index)"
                        let weapon = try #require(HeldGearAnchors.weapon(in: frame), "\(label): no weapon part")
                        let hand = HeldGearAnchors.weaponHand(in: frame, manifestStem: handStem)
                        if HeldGearAnchors.isArmed(frame) {
                            let body = try #require(frame.first { HeldGearAnchors.stem(of: $0.file.name) == "body" }, "\(label): no body")
                            let fist = try #require(hand, "\(label): no visible weapon hand")
                            #expect(weapon.zIndex < fist.zIndex && weapon.zIndex < body.zIndex,
                                    "\(label): the weapon (z \(weapon.zIndex)) is not behind the hand (z \(fist.zIndex)) and body (z \(body.zIndex))")
                            armedFrames += 1
                        } else {
                            #expect(hand != nil, "\(label): no visible \(handStem ?? "weapon hand") to hold a weapon")
                            emptyHandedFrames += 1
                        }
                    }
                }
            }
        }
        #expect(armedFrames > 500 && emptyHandedFrames > 1000, "armed \(armedFrames), empty-handed \(emptyHandedFrames)")
    }

    /// The idle pose is empty-handed and the attack is armed in every pack, so the two draw paths are both used.
    @Test func theIdlePoseIsEmptyHandedAndTheAttackIsArmedInEveryPack() throws {
        let renderer = SpriteRenderer.shared
        for race in HeroRace.allCases {
            for variant in 1...race.variantCount {
                let pack = race.artBase(variant: variant)
                let doc = try #require(renderer.document(race: race, variant: variant), "\(pack) did not load")
                let idle = try #require(doc.animations["Idle"]?.frames, "\(pack) has no Idle")
                #expect(idle.allSatisfy { !HeldGearAnchors.isArmed($0) }, "\(pack) Idle draws a weapon of its own")
                let attack = renderer.attackAnimation(race: race, variant: variant)
                let frames = try #require(doc.animations[attack]?.frames, "\(pack) has no \(attack)")
                #expect(frames.allSatisfy { HeldGearAnchors.isArmed($0) }, "\(pack) \(attack) has a frame with no weapon")
            }
        }
    }

    /// The art packs hold the weapon sideways at hip height (the idle pose) and through most of the swing, which reads as
    /// something it is not. Checked on every frame of every animation of every pack with a sword anchor: after the carry turn
    /// the blade never points between the floor and the carry angle, and in the idle pose it points exactly at the carry angle.
    @Test func aCarriedWeaponNeverPointsFlatOutFromTheHeroInAnyShippedFrame() throws {
        let renderer = SpriteRenderer.shared
        let catalog = ModularAssetCatalog.shared
        let item = try #require(catalog.gearItem(id: "weapon.shard"))
        let carry = try #require(item.carryAngle)
        var turned = 0
        var idleFrames = 0
        for race in HeroRace.allCases {
            for variant in 1...race.variantCount {
                let pack = race.artBase(variant: variant)
                let anchors = try #require(catalog.anchors(pack: pack), "\(pack)")
                guard anchors.weaponAnchor != "bow" else { continue }
                let doc = try #require(renderer.document(race: race, variant: variant), "\(pack) did not load")
                for (name, animation) in doc.animations {
                    for (index, frame) in animation.frames.enumerated() {
                        let label = "\(pack) \(name) \(index)"
                        let anchor = try #require(HeldGearAnchors.weapon(in: frame), "\(label)")
                        let placement = try #require(HeldGearFit.placement(item: item, anchors: anchors, pack: pack, titan: false,
                                                                           anchorAngle: Double(anchor.angle)), "\(label)")
                        let pointing = HeldGearFit.normalized(degrees: Double(anchor.angle) + placement.rotationDegrees)
                        #expect(pointing < HeldGearFit.carryFloor || pointing >= carry - 1e-9,
                                "\(label): the blade points \(Int(pointing)) degrees, flat out from the hero")
                        if placement.rotationDegrees != 0 { turned += 1 }
                        if name == "Idle" {
                            idleFrames += 1
                            #expect(abs(pointing - carry) < 1e-6, "\(label): carried at \(pointing) degrees")
                        }
                    }
                }
            }
        }
        #expect(idleFrames > 90 && turned > 1000, "idle frames \(idleFrames), turned frames \(turned)")
    }

    /// A Titan hero with nothing equipped carries the pack's own weapon scaled up, and it is turned the same way.
    @Test func theBakedTitanWeaponRendersInTheIdlePoseAndThroughTheAttack() throws {
        let renderer = SpriteRenderer.shared
        for race in HeroRace.allCases {
            for variant in 1...race.variantCount {
                let look = HeroAppearance.default(for: race)
                for animation in ["Idle", renderer.attackAnimation(race: race, variant: variant)] {
                    let count = renderer.frameCount(race: race, variant: variant, animation: animation)
                    for index in [0, count / 2, count - 1] {
                        let frame = renderer.frame(race: race, variant: variant, animation: animation, frameIndex: index,
                                                   appearance: look, loadout: SpriteLoadout(titanWeapon: true))
                        #expect(frame != nil, "\(race.artBase(variant: variant)) \(animation) \(index) with the Titan blade")
                    }
                }
            }
        }
    }

    /// Both draw paths with real art: a swapped sword (and shield) in the idle pose, where the weapon is drawn in front and
    /// the fist over it, and through the attack, where the weapon takes the pack's own layer. The bow packs also get the
    /// Elven Recurve, whose string is drawn after the arrow while one is nocked.
    @Test func aSwappedWeaponRendersInTheIdlePoseAndThroughTheAttack() throws {
        let renderer = SpriteRenderer.shared
        let catalog = ModularAssetCatalog.shared
        for race in HeroRace.allCases {
            for variant in 1...race.variantCount {
                let look = HeroAppearance.default(for: race)
                let pack = race.artBase(variant: variant)
                let weaponIDs = catalog.anchors(pack: pack)?.weaponAnchor == "bow" ? ["weapon.forest_ranger", "weapon.shard"] : ["weapon.shard"]
                for weaponID in weaponIDs {
                    // The item has to be one this pack can hold, or the swapped path is silently skipped.
                    #expect(catalog.gearItem(id: weaponID)?.supportedPacks.contains(pack) == true, "\(weaponID) on \(pack)")
                    let loadout = SpriteLoadout(weaponID: weaponID, shieldID: "shield.crux")
                    for animation in ["Idle", renderer.attackAnimation(race: race, variant: variant)] {
                        let count = renderer.frameCount(race: race, variant: variant, animation: animation)
                        for index in [0, count / 2, count - 1] {
                            let frame = renderer.frame(race: race, variant: variant, animation: animation, frameIndex: index,
                                                       appearance: look, loadout: loadout)
                            #expect(frame != nil, "\(pack) \(animation) \(index) with \(weaponID)")
                        }
                    }
                }
            }
        }
    }
}

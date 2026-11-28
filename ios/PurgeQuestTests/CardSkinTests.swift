import Testing
import Foundation
@testable import PurgeQuest

@Suite struct CardSkinTests {

    private let width = 340.0
    private let height = 460.0
    private let band = EdgeParticles.bandWidth

    private func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool { abs(a - b) < tolerance }

    /// True when a particle sits in the left or right band, never over the photo.
    private func inBand(_ p: EdgeParticle) -> Bool { p.x <= band || p.x >= width - band }

    // MARK: Skin kinds

    @Test func everyFamilyGetsASkinAndTheSixAreDistinct() {
        let kinds = MonsterFamily.allCases.map { FamilySkinKind(family: $0) }
        #expect(kinds.count == 6)
        #expect(Set(kinds).count == 6, "six families, six different skins")
        #expect(Set(kinds) == Set(FamilySkinKind.allCases))
    }

    @Test func theKillSwitchShipsWithAllSixOn() {
        #expect(FamilySkinKind.enabled == Set(FamilySkinKind.allCases))
        for family in MonsterFamily.allCases {
            #expect(FamilySkinKind.active(for: family) == FamilySkinKind(family: family))
        }
    }

    @Test func budgetsAndRimStayWithinTheDesign() {
        for kind in FamilySkinKind.allCases { #expect(kind.particleBudget <= 24) }
        #expect(FamilySkinKind.behemoths.particleBudget == 0, "weight, not drift")
        #expect(FamilySkinKind.behemoths.extraRim == 4)
        for kind in FamilySkinKind.allCases where kind != .behemoths { #expect(kind.extraRim == 2) }
        for kind in FamilySkinKind.allCases {
            #expect(kind.extraRim + 4 + 8 > EdgeParticles.bandWidth,
                    "card padding 8 + rim 4 + extra: the photo starts clear of the 10 pt bands")
            #expect(kind.extraRim <= 4, "a rim wider than 8 pt would crowd the photo")
        }
    }

    @Test func nameplateTonesDifferByFamilyWithoutDimmingTheText() {
        let tones = FamilySkinKind.allCases.map(\.nameplateTone)
        for i in tones.indices {
            for j in tones.indices where j > i { #expect(tones[i] != tones[j], "each family sounds different") }
        }
        for tone in tones {
            #expect(tone.tracking >= -0.5 && tone.tracking <= 2.0)
            #expect(tone.glow >= 0)
        }
        #expect(FamilySkinKind.phantoms.nameplateTone.glow > 0, "ethereal by glow, never by transparent text")
        #expect(FamilySkinKind.relics.nameplateTone.smallCapsEyebrow)
    }

    // MARK: Seeded geometry

    @Test func seededGeometryIsDeterministicAndInRange() {
        let a = SeededGeometry(key: "IMG_0001")
        let b = SeededGeometry(key: "IMG_0001")
        for i in -5..<200 {
            #expect(a.value(i) == b.value(i))
            #expect(a.value(i) >= 0 && a.value(i) < 1)
        }
    }

    @Test func seededGeometryDiffersAcrossKeysAndIndices() {
        let a = SeededGeometry(key: "IMG_0001")
        let b = SeededGeometry(key: "IMG_0002")
        #expect(a.value(0) != b.value(0))
        let first = (0..<20).map { a.value($0) }
        #expect(Set(first).count == 20, "twenty indices, twenty different numbers")
    }

    // MARK: Edge particles

    @Test func everyParticleOfEverySkinStaysInTheSideBandsAtAnyTime() {
        var failures: [String] = []
        for kind in FamilySkinKind.allCases {
            for key in ["a", "photo-123", "IMG_0001/L0/001"] {
                let seed = SeededGeometry(key: key)
                var t = 0.0
                while t < 40 {
                    let particles = EdgeParticles.ambient(kind: kind, seed: seed, time: t, width: width, height: height)
                    if particles.count > kind.particleBudget { failures.append("\(kind) \(key) t=\(t): \(particles.count) over budget") }
                    for p in particles {
                        if !inBand(p) { failures.append("\(kind) \(key) t=\(t): x=\(p.x) is over the photo") }
                        if p.y < 0 || p.y > height { failures.append("\(kind) \(key) t=\(t): y=\(p.y) off the card") }
                        if p.alpha < 0 || p.alpha > 1 { failures.append("\(kind) \(key) t=\(t): alpha=\(p.alpha)") }
                    }
                    t += 0.37
                }
            }
        }
        #expect(failures.isEmpty, "\(failures.prefix(3))")
    }

    @Test func behemothsAndDragonsHaveNoAmbientParticles() {
        let seed = SeededGeometry(key: "k")
        for kind in [FamilySkinKind.behemoths, .dragons] {
            #expect(EdgeParticles.ambient(kind: kind, seed: seed, time: 3.3, width: width, height: height).isEmpty)
        }
    }

    @Test func ambientMotesMoveWithTimeAndAreDeterministic() {
        let seed = SeededGeometry(key: "k")
        for kind in [FamilySkinKind.undead, .relics, .phantoms] {
            let now = EdgeParticles.ambient(kind: kind, seed: seed, time: 1, width: width, height: height)
            let again = EdgeParticles.ambient(kind: kind, seed: seed, time: 1, width: width, height: height)
            let later = EdgeParticles.ambient(kind: kind, seed: seed, time: 5, width: width, height: height)
            #expect(!now.isEmpty)
            #expect(now == again, "same card, same moment, same picture")
            #expect(now != later, "and it drifts")
        }
    }

    @Test func glitchBlocksOnlyFlickAndChangeEachCycle() {
        let seed = SeededGeometry(key: "k")
        let first = EdgeParticles.ambient(kind: .glitch, seed: seed, time: 0.02, width: width, height: height)
        let quiet = EdgeParticles.ambient(kind: .glitch, seed: seed, time: 0.5, width: width, height: height)
        let second = EdgeParticles.ambient(kind: .glitch, seed: seed, time: GlitchTiming.cycle + 0.02, width: width, height: height)
        #expect(!first.isEmpty && first.count <= 6)
        #expect(quiet.isEmpty, "ninety milliseconds in every 1.8 seconds, no more")
        #expect(!second.isEmpty)
        #expect(first != second, "a new flick is a new arrangement")
        #expect(GlitchTiming.isFlicking(time: 0.02))
        #expect(!GlitchTiming.isFlicking(time: 0.5))
    }

    @Test func glitchJitterIsOneGlyphInEveryThirdCycle() {
        let seed = SeededGeometry(key: "k")
        for k in 0..<9 {
            let t = Double(k) * GlitchTiming.cycle + 0.02
            let glyph = GlitchTiming.jitterGlyph(time: t, nameLength: 12, seed: seed)
            if k % 3 == 0 {
                #expect(glyph != nil, "cycle \(k) jitters one glyph")
                #expect((glyph ?? -1) >= 0 && (glyph ?? 99) < 12, "inside the name")
            } else {
                #expect(glyph == nil, "cycle \(k) is quiet")
            }
        }
        #expect(GlitchTiming.jitterGlyph(time: 0.5, nameLength: 12, seed: seed) == nil, "only inside a flick")
        #expect(GlitchTiming.jitterGlyph(time: 0.02, nameLength: 0, seed: seed) == nil, "and never on an empty name")
    }

    @Test func dragonFlakesFollowTheLiftAndStayInTheBands() {
        let seed = SeededGeometry(key: "k")
        #expect(EdgeParticles.dragDriven(kind: .dragons, lift: 0, seed: seed, width: width, height: height).isEmpty)
        let flakes = EdgeParticles.dragDriven(kind: .dragons, lift: 1, seed: seed, width: width, height: height)
        #expect(flakes.count == 5)
        for p in flakes { #expect(inBand(p) && p.alpha >= 0 && p.alpha <= 1 && p.y >= 0 && p.y <= height) }
        for kind in FamilySkinKind.allCases where kind != .dragons {
            #expect(EdgeParticles.dragDriven(kind: kind, lift: 1, seed: seed, width: width, height: height).isEmpty)
        }
    }

    @Test func stoneChipsFlyOutwardAndNeverReachThePhoto() {
        let seed = SeededGeometry(key: "k")
        #expect(EdgeParticles.chips(kind: .behemoths, progress: 0, seed: seed, width: width, height: height).isEmpty)
        for progress in [0.25, 0.5, 1.0] {
            let chips = EdgeParticles.chips(kind: .behemoths, progress: progress, seed: seed, width: width, height: height)
            #expect(chips.count == 5)
            for p in chips { #expect(inBand(p) && p.alpha >= 0 && p.alpha <= 1 && p.y <= height) }
        }
        #expect(EdgeParticles.chips(kind: .undead, progress: 1, seed: seed, width: width, height: height).isEmpty)
    }

    // MARK: Drag-driven pieces

    @Test func pressureCracksStartPastSixtyPercent() {
        #expect(SkinDrag.pressureCracks(strength: 0) == 0)
        #expect(SkinDrag.pressureCracks(strength: 0.6) == 0)
        #expect(close(SkinDrag.pressureCracks(strength: 0.8), 0.5))
        #expect(SkinDrag.pressureCracks(strength: 1) == 1)
        #expect(SkinDrag.pressureCracks(strength: 3) == 1, "clamped")
    }

    @Test func ghostsTrailBehindTheDragAndFadeWithTheLift() {
        #expect(SkinDrag.ghosts(dx: -80, dy: 10, lift: 0).isEmpty)
        let ghosts = SkinDrag.ghosts(dx: -80, dy: 10, lift: 1)
        #expect(ghosts.count == 2)
        #expect(ghosts[0].dx > 0, "the ghost of a card dragged left trails to the right")
        #expect(ghosts[1].alpha < ghosts[0].alpha)
        #expect(ghosts[1].dx > ghosts[0].dx, "the second ghost trails further back")
        #expect(SkinDrag.ghosts(dx: -80, dy: 10, lift: 0.5)[0].alpha < ghosts[0].alpha)
    }

    // MARK: Combo

    @Test func comboTierBoundariesMatchTheDesign() {
        #expect(ComboTier(tenths: 10).intensity == 0)
        #expect(!ComboTier(tenths: 14).isHot)
        #expect(ComboTier(tenths: 15).isHot)
        #expect(ComboTier(tenths: 15).hasInnerLine)
        #expect(!ComboTier(tenths: 14).hasInnerLine)
        #expect(!ComboTier(tenths: 19).isMax)
        #expect(ComboTier(tenths: 20).isMax)
        #expect(close(ComboTier(tenths: 20).intensity, 1))
        #expect(close(ComboTier(tenths: 15).intensity, 0.5))
    }

    @Test func comboTierClampsOutOfRangeValues() {
        #expect(ComboTier(tenths: 3).tenths == 10)
        #expect(ComboTier(tenths: 99).tenths == 20)
    }

    @Test func theComboGlowRisesWithTheMultiplierAndIsBounded() {
        #expect(ComboTier(tenths: 10).glowAlpha == 0)
        var last = 0.0
        for tenths in 10...20 {
            let glow = ComboTier(tenths: tenths).glowAlpha
            #expect(glow >= last, "never dims as the multiplier climbs")
            #expect(glow <= 0.4)
            last = glow
        }
    }

    @Test func aCueSaysWhetherTheMultiplierRoseFellOrStayed() {
        #expect(ComboCue.between(beforeTenths: 12, afterTenths: 13) == .raised)
        #expect(ComboCue.between(beforeTenths: 15, afterTenths: 13) == .cooled, "a keep takes 12%")
        #expect(ComboCue.between(beforeTenths: 20, afterTenths: 20) == .none, "capped at x2.0, nothing to announce")
        #expect(ComboCue.between(beforeTenths: 10, afterTenths: 10) == .none, "and a keep at the floor changes nothing")
    }
}

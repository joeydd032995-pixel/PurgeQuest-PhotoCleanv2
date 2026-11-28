//
//  CardSkin.swift
//  PurgeQuest
//
//  The numbers behind the combat card's family skins and combo cues (design:
//  docs/superpowers/specs/2026-11-27-combat-card-depth-design.md, sections 5 and 6). Which skin a monster gets,
//  where every particle is at a given moment, how the glitch flickers, how far the cracks and ghosts have come, and
//  what the combo multiplier means to the rim. Views draw what this decides and decide nothing. Foundation only, so
//  the Linux harness checks it, above all the one promise the skins make: **no particle is ever over the photo**.
//  Every position here is inside the two 10 pt bands at the card's left and right edges, outside the frame.
//

import Foundation

/// How a family's nameplate sounds, in typography and glow only. It never lowers the text's contrast: the colours
/// stay the theme's text colours.
nonisolated struct NameplateTone: Equatable {
    enum Weight: Equatable { case light, regular, semibold, bold, heavy }

    var weight: Weight
    /// Extra letter spacing for the monster's name, in points.
    var tracking: Double
    /// The family line above the "why" text is set in small capitals (Archive Relics: quiet, archival).
    var smallCapsEyebrow: Bool
    /// An inner glow behind the name, in points; 0 for none (Video Phantoms are ethereal by glow, never by transparent text).
    var glow: Double
}

/// The six skins, one per monster family. `nil` where a skin is wanted means today's plain frame.
nonisolated enum FamilySkinKind: String, CaseIterable, Equatable {
    case dragons
    case undead
    case relics
    case behemoths
    case phantoms
    case glitch

    /// The kill switch. Shipping with all six on; a skin that tunes badly is removed from this set and its family
    /// falls back to the plain frame, without touching the others.
    static let enabled: Set<FamilySkinKind> = Set(FamilySkinKind.allCases)

    init(family: MonsterFamily) {
        switch family {
        case .duplicateDragons: self = .dragons
        case .clutterUndead:    self = .undead
        case .archiveRelics:    self = .relics
        case .storageBehemoths: self = .behemoths
        case .videoPhantoms:    self = .phantoms
        case .glitchborn:       self = .glitch
        }
    }

    /// The skin to draw for a family, or nil when its kill switch is off.
    static func active(for family: MonsterFamily) -> FamilySkinKind? {
        let kind = FamilySkinKind(family: family)
        return enabled.contains(kind) ? kind : nil
    }

    /// Extra rim width in points on top of the plain frame's 4: every skin gets 2 so its treatment has room to read
    /// (the first tour's 4 pt rim showed hairlines almost nobody could see), and the Storage Behemoths' frame is
    /// heavier still. The photo starts at least 14 pt in from the card's edge, clear of the 10 pt side bands.
    var extraRim: Double { self == .behemoths ? 4 : 2 }

    /// The most particles this skin shows at once (the design's cap is 24 for any skin).
    var particleBudget: Int {
        switch self {
        case .dragons:   return 5
        case .undead:    return 12
        case .relics:    return 10
        case .behemoths: return 0
        case .phantoms:  return 8
        case .glitch:    return 6
        }
    }

    /// Whether the edge layer needs a clock. The others follow the drag only, or nothing.
    var isAmbient: Bool {
        switch self {
        case .undead, .relics, .phantoms, .glitch: return true
        case .dragons, .behemoths:                 return false
        }
    }

    var nameplateTone: NameplateTone {
        switch self {
        case .dragons:   return NameplateTone(weight: .bold, tracking: 1.2, smallCapsEyebrow: false, glow: 0)
        case .undead:    return NameplateTone(weight: .light, tracking: -0.2, smallCapsEyebrow: false, glow: 0)
        case .relics:    return NameplateTone(weight: .regular, tracking: 0.4, smallCapsEyebrow: true, glow: 0)
        case .behemoths: return NameplateTone(weight: .heavy, tracking: 1.6, smallCapsEyebrow: false, glow: 0)
        case .phantoms:  return NameplateTone(weight: .regular, tracking: 0.6, smallCapsEyebrow: false, glow: 3)
        case .glitch:    return NameplateTone(weight: .semibold, tracking: 0, smallCapsEyebrow: false, glow: 0)
        }
    }
}

/// Deterministic pseudo-random numbers from a key (an item's id), so a card looks the same every time it is drawn.
/// FNV-1a to turn the key into a seed and splitmix64 to turn a seed and an index into a number. Not `Hasher`, which
/// is randomised per process.
nonisolated struct SeededGeometry: Equatable {
    let seed: UInt64

    init(key: String) {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        seed = hash
    }

    /// A number in 0 up to but not including 1, the same every time for the same key and index.
    func value(_ index: Int) -> Double {
        var z = seed &+ UInt64(truncatingIfNeeded: index) &* 0x9E3779B97F4A7C15
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        z = z ^ (z >> 31)
        return Double(z >> 11) / 9007199254740992.0
    }
}

nonisolated struct EdgeParticle: Equatable {
    var x: Double
    var y: Double
    var radius: Double
    var alpha: Double
}

/// The flicker of the Glitchborn skin: ninety milliseconds in every 1.8 seconds.
nonisolated enum GlitchTiming {
    static let cycle: Double = 1.8
    /// 90 ms of 1.8 s.
    static let flickShare: Double = 0.05

    static func isFlicking(time: Double) -> Bool {
        let cycles = time / cycle
        return cycles - floor(cycles) < flickShare
    }

    /// Which glyph of the name jitters in this flick, or nil. Only every third flick, only one glyph.
    static func jitterGlyph(time: Double, nameLength: Int, seed: SeededGeometry) -> Int? {
        guard nameLength > 0, isFlicking(time: time) else { return nil }
        let cycleIndex = Int(floor(time / cycle))
        guard ((cycleIndex % 3) + 3) % 3 == 0 else { return nil }
        let index = Int(seed.value(cycleIndex &* 31 &+ 7) * Double(nameLength))
        return min(index, nameLength - 1)
    }
}

/// Where each skin's particles are. Every x is inside the left or right band, never over the photo; the tests walk
/// every skin through forty seconds to prove it.
nonisolated enum EdgeParticles {
    /// The width of the band at each side of the card, in points. The photo starts at least 12 pt in.
    static let bandWidth: Double = 10

    /// Particles that drift with time: motes, dust, wisps, glitch blocks. Empty for the skins that have none.
    static func ambient(kind: FamilySkinKind, seed: SeededGeometry, time: Double, width: Double, height: Double) -> [EdgeParticle] {
        switch kind {
        case .dragons, .behemoths:
            return []
        case .glitch:
            return glitchBlocks(seed: seed, time: time, width: width, height: height)
        case .undead:
            return motes(count: kind.particleBudget, seed: seed, time: time, width: width, height: height,
                         speed: 0.06, rising: true, maxAlpha: 0.35, minRadius: 1.0, maxRadius: 2.2)
        case .relics:
            return motes(count: kind.particleBudget, seed: seed, time: time, width: width, height: height,
                         speed: 0.03, rising: false, maxAlpha: 0.30, minRadius: 0.8, maxRadius: 1.8)
        case .phantoms:
            return motes(count: kind.particleBudget, seed: seed, time: time, width: width, height: height,
                         speed: 0.08, rising: true, maxAlpha: 0.25, minRadius: 2.0, maxRadius: 3.5)
        }
    }

    /// The Duplicate Dragons' scale flakes, which come off the frame as the card is dragged: no clock, only the lift.
    static func dragDriven(kind: FamilySkinKind, lift: Double, seed: SeededGeometry, width: Double, height: Double) -> [EdgeParticle] {
        guard kind == .dragons, lift > 0 else { return [] }
        let amount = min(1, lift)
        var result: [EdgeParticle] = []
        for i in 0..<kind.particleBudget {
            let radius = 1.2
            let across = radius + (bandWidth - 2 * radius) * seed.value(i * 3 + 500)
            let x = i.isMultiple(of: 2) ? across : width - across
            let y = min(height, height * (0.1 + 0.8 * seed.value(i * 3 + 501)) + amount * 28)
            result.append(EdgeParticle(x: x, y: y, radius: radius, alpha: min(1, 0.6 * amount)))
        }
        return result
    }

    /// The Storage Behemoths' stone chips, thrown outward as the card is committed. `progress` is 0 to 1.
    static func chips(kind: FamilySkinKind, progress: Double, seed: SeededGeometry, width: Double, height: Double) -> [EdgeParticle] {
        guard kind == .behemoths, progress > 0 else { return [] }
        let p = min(1, progress)
        var result: [EdgeParticle] = []
        for i in 0..<5 {
            let radius = 2.2
            let across = radius + (bandWidth - 2 * radius) * seed.value(i * 3 + 700)
            let outward = p * 22
            let x = i.isMultiple(of: 2) ? across - outward : width - across + outward
            let y = min(height, height * (0.25 + 0.5 * seed.value(i * 3 + 701)) + p * p * 30)
            result.append(EdgeParticle(x: x, y: y, radius: radius, alpha: max(0, 1 - p)))
        }
        return result
    }

    private static func fract(_ value: Double) -> Double { value - floor(value) }

    /// Slow motes that rise (or fall) through the bands and fade in and out.
    private static func motes(count: Int, seed: SeededGeometry, time: Double, width: Double, height: Double,
                              speed: Double, rising: Bool, maxAlpha: Double, minRadius: Double, maxRadius: Double) -> [EdgeParticle] {
        var result: [EdgeParticle] = []
        for i in 0..<count {
            let radius = minRadius + (maxRadius - minRadius) * seed.value(i * 4 + 3)
            let across = radius + (bandWidth - 2 * radius) * seed.value(i * 4)
            let x = i.isMultiple(of: 2) ? across : width - across
            let phase = fract(seed.value(i * 4 + 1) + time * speed)
            let y = height * (rising ? 1 - phase : phase)
            let alpha = max(0, min(1, maxAlpha * sin(Double.pi * phase)))
            result.append(EdgeParticle(x: x, y: y, radius: radius, alpha: alpha))
        }
        return result
    }

    /// Small square blocks that appear for one flick and re-arrange for the next.
    private static func glitchBlocks(seed: SeededGeometry, time: Double, width: Double, height: Double) -> [EdgeParticle] {
        guard GlitchTiming.isFlicking(time: time) else { return [] }
        let cycleIndex = Int(floor(time / GlitchTiming.cycle))
        var result: [EdgeParticle] = []
        for i in 0..<FamilySkinKind.glitch.particleBudget {
            let base = cycleIndex &* 97 &+ i &* 5 &+ 1000
            let half = 1.5 + 2.0 * seed.value(base)
            let across = half + (bandWidth - 2 * half) * seed.value(base &+ 1)
            let x = i.isMultiple(of: 2) ? across : width - across
            let y = height * seed.value(base &+ 2)
            result.append(EdgeParticle(x: x, y: y, radius: half, alpha: 0.55))
        }
        return result
    }
}

nonisolated struct SkinGhost: Equatable {
    var dx: Double
    var dy: Double
    var alpha: Double
}

/// The parts of a skin that follow the drag instead of a clock.
nonisolated enum SkinDrag {
    /// How far the Storage Behemoths' pressure cracks have grown: nothing up to 60% of the drag, full at 100%.
    static func pressureCracks(strength: Double) -> Double {
        min(1, max(0, (strength - 0.6) / 0.4))
    }

    /// The Video Phantoms' two after-images of the frame, trailing behind the drag and fading with the lift.
    static func ghosts(dx: Double, dy: Double, lift: Double) -> [SkinGhost] {
        let amount = min(1, max(0, lift))
        guard amount > 0 else { return [] }
        return [
            SkinGhost(dx: -0.10 * dx, dy: -0.10 * dy, alpha: 0.15 * amount),
            SkinGhost(dx: -0.20 * dx, dy: -0.20 * dy, alpha: 0.08 * amount)
        ]
    }
}

/// What the combo multiplier means to the card's rim. `tenths` is `ComboMultiplier.tenths`: 10 is x1.0, 20 is x2.0.
nonisolated struct ComboTier: Equatable {
    let tenths: Int

    init(tenths: Int) {
        self.tenths = min(20, max(10, tenths))
    }

    /// 0 at x1.0, 1 at x2.0.
    var intensity: Double { Double(tenths - 10) / 10 }
    var isHot: Bool { tenths >= 15 }
    var isMax: Bool { tenths >= 20 }
    /// A second, thin line inside the rim from x1.5.
    var hasInnerLine: Bool { isHot }
    /// The steady brass glow of the rim: none at x1.0, rising to a peak at x2.0.
    var glowAlpha: Double { isMax ? 0.4 : 0.35 * intensity }
}

/// What the last decision did to the multiplier, for the next card to show. A keep that takes 12% is `.cooled`; at the
/// cap, or at the floor, nothing changed and nothing is announced.
nonisolated enum ComboCue: Equatable {
    case none
    case raised
    case cooled

    static func between(beforeTenths: Int, afterTenths: Int) -> ComboCue {
        if afterTenths > beforeTenths { return .raised }
        if afterTenths < beforeTenths { return .cooled }
        return .none
    }
}

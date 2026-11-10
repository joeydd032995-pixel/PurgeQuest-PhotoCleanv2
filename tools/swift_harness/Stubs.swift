// Minimal stand-ins for app types that live in SwiftUI/SwiftData files, so the pure-Foundation
// model/logic sources and their Swift Testing suites can compile on a Linux toolchain.
import Foundation

struct Color: Equatable {
    static let questAmber = Color(), gemEmerald = Color(), xpViolet = Color()
    static let combatCrimson = Color(), videoSapphire = Color(), questAmberDeep = Color()
    // Bestiary family and rarity tints (MonsterFamily.accentColor, MonsterRarity.frameColor).
    static let behemothIndigo = Color(), dragonCoral = Color(), glitchRose = Color(), dungeonAsh = Color()
}

enum HeroClass: String { case paladinHoly, hunter, priestDivine, roguePoison, mageIce, paladinUnholy, shamanEarth }

enum CharacterArchetype: String, CaseIterable, Codable { case knight, magician }

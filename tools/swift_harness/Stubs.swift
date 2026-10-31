// Minimal stand-ins for app types that live in SwiftUI/SwiftData files, so the pure-Foundation
// model/logic sources and their Swift Testing suites can compile on a Linux toolchain.
import Foundation

struct Color: Equatable {
    static let questAmber = Color(), gemEmerald = Color(), xpViolet = Color()
    static let combatCrimson = Color(), videoSapphire = Color(), questAmberDeep = Color()
}

enum HeroClass: String { case paladinHoly, hunter, priestDivine, roguePoison, mageIce, paladinUnholy, shamanEarth }

enum CharacterArchetype: String, CaseIterable, Codable { case knight, magician }

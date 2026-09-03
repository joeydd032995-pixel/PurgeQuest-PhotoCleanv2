//
//  MonsterType.swift
//  PurgeQuest
//

import SwiftUI

enum MediaKind: String, Codable, Sendable {
    case photo
    case video
}

enum MonsterType: String, CaseIterable, Codable, Sendable {
    // Photo monsters
    case duplicateDragon
    case blurBeast
    case screenshotSpecter
    case lowQualityLich
    case ancientArchive
    case darkWraith
    // Video monsters
    case videoVampire
    case longTakeLeviathan
    case shakyGhost
    case boringBlooper
    case memoryHogMinotaur
    case timelapsePhantom
    case corruptedCodec

    var displayName: String {
        switch self {
        case .duplicateDragon:    return "Duplicate Dragon"
        case .blurBeast:          return "Blur Beast"
        case .screenshotSpecter:  return "Screenshot Specter"
        case .lowQualityLich:     return "Low-Quality Lich"
        case .ancientArchive:     return "Ancient Archive"
        case .darkWraith:         return "Dark Wraith"
        case .videoVampire:       return "Video Vampire"
        case .longTakeLeviathan:  return "LongTake Leviathan"
        case .shakyGhost:         return "Shaky Ghost"
        case .boringBlooper:      return "Boring Blooper"
        case .memoryHogMinotaur:  return "Memory Hog Minotaur"
        case .timelapsePhantom:   return "Timelapse Phantom"
        case .corruptedCodec:     return "Corrupted Codec"
        }
    }

    var symbol: String {
        switch self {
        case .duplicateDragon:   return "square.on.square"
        case .blurBeast:         return "drop.halffull"
        case .screenshotSpecter: return "rectangle.dashed"
        case .lowQualityLich:    return "minus.magnifyingglass"
        case .ancientArchive:    return "hourglass"
        case .darkWraith:        return "moon.stars.fill"
        case .videoVampire:      return "play.rectangle.fill"
        case .longTakeLeviathan: return "film.stack"
        case .shakyGhost:        return "waveform.path.ecg"
        case .boringBlooper:     return "rectangle.compress.vertical"
        case .memoryHogMinotaur: return "externaldrive.fill"
        case .timelapsePhantom:  return "timelapse"
        case .corruptedCodec:    return "exclamationmark.triangle.fill"
        }
    }

    var kind: MediaKind {
        switch self {
        case .duplicateDragon, .blurBeast, .screenshotSpecter, .lowQualityLich, .ancientArchive, .darkWraith:
            return .photo
        default:
            return .video
        }
    }

    var hp: Int {
        switch self {
        case .longTakeLeviathan, .memoryHogMinotaur: return 3
        case .ancientArchive, .duplicateDragon, .videoVampire: return 2
        default: return 1
        }
    }

    /// Elite monsters are the high-HP "bosses" (Leviathan, Minotaur, Dragon, Ancient
    /// Archive, Video Vampire) — the toughest foes a Purge Knight is rewarded for slaying.
    var isElite: Bool { hp >= 2 }

    var xpReward: Int {
        switch self {
        case .longTakeLeviathan: return 80
        case .memoryHogMinotaur: return 70
        case .ancientArchive:    return 60
        case .duplicateDragon:   return 45
        case .videoVampire:      return 50
        case .timelapsePhantom:  return 45
        case .shakyGhost:        return 35
        case .blurBeast:         return 30
        case .screenshotSpecter: return 25
        case .lowQualityLich:    return 30
        case .darkWraith:        return 35
        case .boringBlooper:     return 25
        case .corruptedCodec:    return 40
        }
    }

    var attackDamage: Int {
        switch self {
        case .longTakeLeviathan, .memoryHogMinotaur: return 18
        case .duplicateDragon, .videoVampire, .ancientArchive: return 12
        default: return 8
        }
    }

    var accentColor: Color {
        switch kind {
        case .photo: return .questAmber
        case .video: return .videoSapphire
        }
    }

    var flavor: String {
        switch self {
        case .duplicateDragon:   return "Twin scales gleam. Slay one, the other vanishes."
        case .blurBeast:         return "A smear of motion from a hand long forgotten."
        case .screenshotSpecter: return "Phantoms of UIs you no longer recall."
        case .lowQualityLich:    return "Drains your storage drop by drop."
        case .ancientArchive:    return "A relic of seasons past. Worth precious XP."
        case .darkWraith:        return "Lurks in shadows where the light didn't reach."
        case .videoVampire:      return "Feeds on your gigabytes, frame by frame."
        case .longTakeLeviathan: return "An endless take. Massive HP. Massive loot."
        case .shakyGhost:        return "Trembles erratically. Strike before it slips away."
        case .boringBlooper:     return "Five seconds you'll never get back."
        case .memoryHogMinotaur: return "A behemoth of bloated bytes."
        case .timelapsePhantom:  return "Captured an entire afternoon. Probably."
        case .corruptedCodec:    return "Fragmented frames. A glitch in the dungeon."
        }
    }
}

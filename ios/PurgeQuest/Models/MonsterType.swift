//
//  MonsterType.swift
//  PurgeQuest
//
//  The full bestiary roster. Every monster belongs to a family, carries a
//  rarity that frames its plaque, and knows the typical library signal that
//  summons it — so classification stays explainable end to end.
//

import SwiftUI

enum MediaKind: String, Codable, Sendable {
    case photo
    case video
}

enum MonsterType: String, CaseIterable, Codable, Sendable {
    // MARK: Duplicate Dragons (stage 1)
    case perfectPairWyrmling
    case duplicateDragon
    case burstHydra
    case cloneChimera
    case screenshotTwin
    case downloadDrake
    case albumEcho
    case hoardHydra

    // MARK: Clutter Undead (existing + stage 2)
    case blurBeast
    case screenshotSpecter
    case lowQualityLich
    case darkWraith
    case thumbGoblin
    case livePhotoLycan

    // MARK: Archive Relics (existing)
    case ancientArchive

    // MARK: Storage Behemoths (existing + stage 2)
    case memoryHogMinotaur
    case longTakeLeviathan
    case panoramaColossus
    case fourKKraken
    case gigabyteGorgon

    // MARK: Video Phantoms (existing + stage 2)
    case videoVampire
    case shakyGhost
    case boringBlooper
    case timelapsePhantom
    case pocketPoltergeist
    case screenRecordingShade

    // MARK: Glitchborn (existing; stage 4 expands this family)
    case corruptedCodec

    var displayName: String {
        switch self {
        case .perfectPairWyrmling: return "Perfect Pair Wyrmling"
        case .duplicateDragon:     return "Duplicate Dragon"
        case .burstHydra:          return "Burst Hydra"
        case .cloneChimera:        return "Clone Chimera"
        case .screenshotTwin:      return "Screenshot Twin"
        case .downloadDrake:       return "Download Drake"
        case .albumEcho:           return "Album Echo"
        case .hoardHydra:          return "Hoard Hydra"
        case .blurBeast:           return "Blur Beast"
        case .screenshotSpecter:   return "Screenshot Specter"
        case .lowQualityLich:      return "Low-Quality Lich"
        case .darkWraith:          return "Dark Wraith"
        case .thumbGoblin:         return "Thumb Goblin"
        case .livePhotoLycan:      return "Live Photo Lycan"
        case .ancientArchive:      return "Ancient Archive"
        case .memoryHogMinotaur:   return "Memory Hog Minotaur"
        case .longTakeLeviathan:   return "LongTake Leviathan"
        case .panoramaColossus:    return "Panorama Colossus"
        case .fourKKraken:         return "4K Kraken"
        case .gigabyteGorgon:      return "Gigabyte Gorgon"
        case .videoVampire:        return "Video Vampire"
        case .shakyGhost:          return "Shaky Ghost"
        case .boringBlooper:       return "Boring Blooper"
        case .timelapsePhantom:    return "Timelapse Phantom"
        case .pocketPoltergeist:   return "Pocket Poltergeist"
        case .screenRecordingShade:return "Screen Recording Shade"
        case .corruptedCodec:      return "Corrupted Codec"
        }
    }

    var symbol: String {
        switch self {
        case .perfectPairWyrmling: return "rectangle.fill.on.rectangle.fill"
        case .duplicateDragon:     return "square.on.square"
        case .burstHydra:          return "square.grid.3x3.fill"
        case .cloneChimera:        return "square.and.pencil"
        case .screenshotTwin:      return "rectangle.on.rectangle"
        case .downloadDrake:       return "arrow.down.circle.fill"
        case .albumEcho:           return "square.stack.3d.down.right.fill"
        case .hoardHydra:          return "square.stack.3d.up.fill"
        case .blurBeast:           return "drop.halffull"
        case .screenshotSpecter:   return "rectangle.dashed"
        case .lowQualityLich:      return "minus.magnifyingglass"
        case .darkWraith:          return "moon.stars.fill"
        case .thumbGoblin:         return "photo.fill"
        case .livePhotoLycan:      return "livephoto"
        case .ancientArchive:      return "hourglass"
        case .memoryHogMinotaur:   return "externaldrive.fill"
        case .longTakeLeviathan:   return "film.stack"
        case .panoramaColossus:    return "arrow.left.and.right"
        case .fourKKraken:         return "4k.tv"
        case .gigabyteGorgon:      return "sdcard.fill"
        case .videoVampire:        return "play.rectangle.fill"
        case .shakyGhost:          return "waveform.path.ecg"
        case .boringBlooper:       return "rectangle.compress.vertical"
        case .timelapsePhantom:    return "timelapse"
        case .pocketPoltergeist:   return "timer"
        case .screenRecordingShade:return "record.circle"
        case .corruptedCodec:      return "exclamationmark.triangle.fill"
        }
    }

    var kind: MediaKind {
        switch self {
        case .perfectPairWyrmling, .duplicateDragon, .burstHydra, .cloneChimera,
             .screenshotTwin, .downloadDrake, .albumEcho, .hoardHydra,
             .blurBeast, .screenshotSpecter, .lowQualityLich, .darkWraith,
             .thumbGoblin, .livePhotoLycan, .ancientArchive, .panoramaColossus:
            return .photo
        default:
            return .video
        }
    }

    var family: MonsterFamily {
        switch self {
        case .perfectPairWyrmling, .duplicateDragon, .burstHydra, .cloneChimera,
             .screenshotTwin, .downloadDrake, .albumEcho, .hoardHydra:
            return .duplicateDragons
        case .blurBeast, .screenshotSpecter, .lowQualityLich, .darkWraith,
             .thumbGoblin, .livePhotoLycan:
            return .clutterUndead
        case .ancientArchive:
            return .archiveRelics
        case .memoryHogMinotaur, .longTakeLeviathan, .panoramaColossus,
             .fourKKraken, .gigabyteGorgon:
            return .storageBehemoths
        case .videoVampire, .shakyGhost, .boringBlooper, .timelapsePhantom,
             .pocketPoltergeist, .screenRecordingShade:
            return .videoPhantoms
        case .corruptedCodec:
            return .glitchborn
        }
    }

    var rarity: MonsterRarity {
        switch self {
        case .duplicateDragon, .gigabyteGorgon:              return .legendary
        case .hoardHydra, .fourKKraken, .longTakeLeviathan,
             .memoryHogMinotaur, .corruptedCodec:            return .elite
        case .burstHydra, .cloneChimera, .ancientArchive,
             .panoramaColossus, .videoVampire:               return .rare
        case .screenshotTwin, .downloadDrake, .albumEcho, .screenshotSpecter,
             .darkWraith, .livePhotoLycan, .timelapsePhantom,
             .screenRecordingShade:                          return .uncommon
        case .perfectPairWyrmling, .blurBeast, .lowQualityLich,
             .thumbGoblin, .shakyGhost, .boringBlooper,
             .pocketPoltergeist:                             return .common
        }
    }

    var hp: Int {
        switch self {
        case .duplicateDragon, .gigabyteGorgon, .longTakeLeviathan, .memoryHogMinotaur: return 3
        case .hoardHydra, .fourKKraken, .burstHydra, .cloneChimera,
             .ancientArchive, .videoVampire, .panoramaColossus, .corruptedCodec:        return 2
        default: return 1
        }
    }

    /// Elite monsters are the high-HP "bosses" — the toughest foes a Purge
    /// Knight is rewarded for slaying.
    var isElite: Bool { hp >= 2 }

    var xpReward: Int {
        switch self {
        case .gigabyteGorgon:      return 100
        case .longTakeLeviathan:   return 80
        case .hoardHydra:          return 75
        case .fourKKraken:         return 70
        case .memoryHogMinotaur:   return 70
        case .duplicateDragon:     return 60
        case .ancientArchive:      return 60
        case .burstHydra:          return 55
        case .cloneChimera:        return 55
        case .videoVampire:        return 50
        case .panoramaColossus:    return 50
        case .timelapsePhantom:    return 45
        case .screenRecordingShade:return 40
        case .corruptedCodec:      return 40
        case .albumEcho:           return 35
        case .shakyGhost:          return 35
        case .livePhotoLycan:      return 35
        case .darkWraith:          return 35
        case .screenshotTwin:      return 30
        case .downloadDrake:       return 30
        case .blurBeast:           return 30
        case .lowQualityLich:      return 30
        case .boringBlooper:       return 25
        case .perfectPairWyrmling: return 25
        case .screenshotSpecter:   return 25
        case .thumbGoblin:         return 20
        case .pocketPoltergeist:   return 20
        }
    }

    var attackDamage: Int {
        switch self {
        case .longTakeLeviathan, .memoryHogMinotaur, .gigabyteGorgon: return 18
        case .duplicateDragon, .videoVampire, .ancientArchive:        return 12
        case .hoardHydra, .fourKKraken:                               return 14
        case .burstHydra, .cloneChimera, .panoramaColossus,
             .screenRecordingShade, .corruptedCodec:                  return 10
        default:                                                       return 8
        }
    }

    var accentColor: Color { family.accentColor }

    /// Typical signal that summons this monster — shown in the bestiary as
    /// the canonical "why" even before a specific encounter.
    var signalDescription: String {
        switch self {
        case .perfectPairWyrmling: return "Two files with identical content"
        case .duplicateDragon:     return "A reliable visually identical group"
        case .burstHydra:          return "A short burst of near-identical frames"
        case .cloneChimera:        return "Near-identical copies with crops or edits"
        case .screenshotTwin:      return "A screenshot saved more than once"
        case .downloadDrake:       return "The same image downloaded repeatedly"
        case .albumEcho:           return "The same capture saved on different days"
        case .hoardHydra:          return "A hoard of six or more copies"
        case .blurBeast:           return "Out-of-focus captures"
        case .screenshotSpecter:   return "Screenshots of interfaces long gone"
        case .lowQualityLich:      return "Oddly proportioned saves from elsewhere"
        case .darkWraith:          return "Near-black frames where light never arrived"
        case .thumbGoblin:         return "Tiny thumbnails posing as real photos"
        case .livePhotoLycan:      return "Live Photos and their paired motion files"
        case .ancientArchive:      return "Captures from years past"
        case .memoryHogMinotaur:   return "Files over 500 MB"
        case .longTakeLeviathan:   return "Recordings over two minutes"
        case .panoramaColossus:    return "Extremely wide panoramas"
        case .fourKKraken:         return "Ultra-high-resolution 4K recordings"
        case .gigabyteGorgon:      return "Any single file over 1 GB"
        case .videoVampire:        return "Videos draining 100 MB or more"
        case .shakyGhost:          return "Unsteady handheld footage"
        case .boringBlooper:       return "Clips under five seconds"
        case .timelapsePhantom:    return "Timelapses and slow-motion captures"
        case .pocketPoltergeist:   return "Barely-a-moment or near-black videos"
        case .screenRecordingShade:return "Screen recordings of forgotten sessions"
        case .corruptedCodec:      return "Media that could not be fully loaded"
        }
    }

    /// Review guidance shown beside the decision — separating "potentially
    /// removable" from "review carefully" in plain language.
    var reviewGuidance: String {
        switch self {
        case .ancientArchive:      return "A memory awaits judgment. Look before you let go."
        case .corruptedCodec:      return "Could not be fully loaded. Confirm it's replaceable first."
        case .cloneChimera:        return "An edited copy may be the only version with your changes."
        case .livePhotoLycan:      return "Slaying the photo also removes its paired motion."
        case .albumEcho:           return "One echo may be the copy you actually kept."
        case .duplicateDragon, .hoardHydra, .burstHydra, .perfectPairWyrmling:
            return "Keep the best copy — the star is only a suggestion."
        case .screenshotTwin, .downloadDrake: return "Keep whichever copy opens fastest."
        case .blurBeast:           return "Some blurry shots are the only ones of a moment."
        case .darkWraith:          return "Check for hidden details before striking."
        case .thumbGoblin:         return "Tiny files are already cheap to keep."
        case .panoramaColossus:    return "Wide scenes are rare — weigh the space against the view."
        case .fourKKraken, .gigabyteGorgon, .memoryHogMinotaur:
            return "Huge loot for the bravest purge. Confirm it plays nowhere else."
        case .longTakeLeviathan:   return "Skim the whole take before cutting."
        case .videoVampire:        return "Large, but perhaps a keeper. Judge frame by frame."
        case .shakyGhost:          return "Shaky now, but the only angle you have?"
        case .boringBlooper:       return "Short clips cost little space."
        case .timelapsePhantom:    return "Long captures compress whole afternoons."
        case .pocketPoltergeist:   return "Moments this short rarely return value."
        case .screenRecordingShade:return "Recordings often hold passwords or personal data."
        case .screenshotSpecter:   return "Old screenshots can hold codes or conversations."
        case .lowQualityLich:      return "Saved-from-elsewhere media rarely returns."
        }
    }

    /// Families whose members always deserve the careful-review flag:
    /// old memories are never junk, and broken media is never auto-deleted.
    var defaultsToCarefulReview: Bool {
        family == .archiveRelics || family == .glitchborn
    }

    /// Short bestiary lore line.
    var lore: String {
        switch self {
        case .perfectPairWyrmling: return "Hatched from a single file that slipped the nest twice. Small, but a sign the Hoard is near."
        case .duplicateDragon:     return "Twin scales gleam. Slay one, the other vanishes. First true dragon of the Hoard."
        case .burstHydra:          return "Many heads raised in the same heartbeat. Cut one, three more grin back."
        case .cloneChimera:        return "Stitched from copies and crops. No two faces match, yet all are one."
        case .screenshotTwin:      return "Twins born of the same glowing rectangle. One guards a code you forgot to keep."
        case .downloadDrake:       return "Follows links home, dropping the same scales at every doorstep."
        case .albumEcho:           return "A memory that returned in another season, wearing the same face."
        case .hoardHydra:          return "The Hoard's elder. Six heads or more, each convinced it is the original."
        case .blurBeast:           return "A smear of motion from a hand long forgotten."
        case .screenshotSpecter:   return "Phantoms of UIs you no longer recall."
        case .lowQualityLich:      return "Drains your storage drop by drop."
        case .darkWraith:          return "Lurks in shadows where the light didn't reach."
        case .thumbGoblin:         return "Sneaks into your gallery disguised as a full-size photo."
        case .livePhotoLycan:      return "By day a still image; the motion file howls beneath it."
        case .ancientArchive:      return "A relic of seasons past. Worth precious XP — and a second look."
        case .memoryHogMinotaur:   return "A behemoth of bloated bytes."
        case .longTakeLeviathan:   return "An endless take. Massive HP. Massive loot."
        case .panoramaColossus:    return "Spans the whole horizon and most of your storage."
        case .fourKKraken:         return "Four thousand tentacles, each sharper than the last."
        case .gigabyteGorgon:      return "A single gaze turns a gigabyte to stone."
        case .videoVampire:        return "Feeds on your gigabytes, frame by frame."
        case .shakyGhost:          return "Trembles erratically. Strike before it slips away."
        case .boringBlooper:       return "Five seconds you'll never get back."
        case .timelapsePhantom:    return "Captured an entire afternoon. Probably."
        case .pocketPoltergeist:   return "Escaped a pocket mid-step. Half a second of chaos."
        case .screenRecordingShade:return "It watched everything you did. It remembers."
        case .corruptedCodec:      return "Fragmented frames. A glitch in the dungeon."
        }
    }

    /// Title earned in the bestiary once the monster is encountered.
    var unlockableTitle: String {
        switch self {
        case .perfectPairWyrmling: return "Egg Cracker"
        case .duplicateDragon:     return "Dragonsbane"
        case .burstHydra:          return "Burst Cutter"
        case .cloneChimera:        return "Original Keeper"
        case .screenshotTwin:      return "Twin Resolver"
        case .downloadDrake:       return "Link Breaker"
        case .albumEcho:           return "Echo Chaser"
        case .hoardHydra:          return "Hoard Breaker"
        case .blurBeast:           return "Focus Finder"
        case .screenshotSpecter:   return "Screen Sweeper"
        case .lowQualityLich:      return "Quality Warden"
        case .darkWraith:          return "Lightbringer"
        case .thumbGoblin:         return "Goblin Bouncer"
        case .livePhotoLycan:      return "Stillness Keeper"
        case .ancientArchive:      return "The Archivist"
        case .memoryHogMinotaur:   return "Maze Liberator"
        case .longTakeLeviathan:   return "Harbor Cutter"
        case .panoramaColossus:    return "Horizon Tamer"
        case .fourKKraken:         return "Depth Charger"
        case .gigabyteGorgon:      return "Gorgon Stiller"
        case .videoVampire:        return "Stake Bearer"
        case .shakyGhost:          return "Steady Hand"
        case .boringBlooper:       return "Reel Trimmer"
        case .timelapsePhantom:    return "Time Bender"
        case .pocketPoltergeist:   return "Pocket Warden"
        case .screenRecordingShade:return "Shadow Auditor"
        case .corruptedCodec:      return "Glitch Healer"
        }
    }

    var flavor: String { lore }
}

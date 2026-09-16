//
//  MonsterFamily.swift
//  PurgeQuest
//
//  The six recognizable families that organize the bestiary. Families group
//  monsters by the kind of library signal that summons them, keeping variety
//  high while classifier logic stays modular and explainable.
//

import SwiftUI

enum MonsterFamily: String, Codable, CaseIterable, Sendable {
    case clutterUndead
    case archiveRelics
    case storageBehemoths
    case duplicateDragons
    case videoPhantoms
    case glitchborn

    var displayName: String {
        switch self {
        case .clutterUndead:     return "Clutter Undead"
        case .archiveRelics:     return "Archive Relics"
        case .storageBehemoths:  return "Storage Behemoths"
        case .duplicateDragons:  return "Duplicate Dragons"
        case .videoPhantoms:     return "Video Phantoms"
        case .glitchborn:        return "Glitchborn"
        }
    }

    var symbol: String {
        switch self {
        case .clutterUndead:     return "trash.stack.fill"
        case .archiveRelics:     return "hourglass"
        case .storageBehemoths:  return "externaldrive.fill"
        case .duplicateDragons:  return "square.on.square"
        case .videoPhantoms:     return "play.rectangle.fill"
        case .glitchborn:        return "exclamationmark.triangle.fill"
        }
    }

    /// One-line family intro shown on the Bestiary grid.
    var tagline: String {
        switch self {
        case .clutterUndead:     return "Everyday disposable media"
        case .archiveRelics:     return "Old and forgotten captures"
        case .storageBehemoths:  return "Massive space consumers"
        case .duplicateDragons:  return "Repeated and near-identical items"
        case .videoPhantoms:     return "Low-value video"
        case .glitchborn:        return "Broken and suspicious media"
        }
    }

    /// Derived from the existing dungeon palette — no new hues.
    var accentColor: Color {
        switch self {
        case .clutterUndead:     return .questAmber
        case .archiveRelics:     return .xpViolet
        case .storageBehemoths:  return .gemEmerald
        case .duplicateDragons:  return .combatCrimson
        case .videoPhantoms:     return .videoSapphire
        case .glitchborn:        return .combatCrimsonDeep
        }
    }
}

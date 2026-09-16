//
//  MonsterClassification.swift
//  PurgeQuest
//
//  Separates detected fact from game interpretation. Every classification
//  carries the machine-readable reasons that summoned the monster so each
//  encounter can answer "Why did this appear?" in plain language, and flags
//  which items deserve careful review instead of a quick purge.
//

import Foundation

/// Explainable signals a monster can be summoned by. The raw cases are facts;
/// `factText` is the plain-language sentence shown on encounter cards and in
/// the bestiary. New rollout stages append cases without re-architecting.
enum ClassificationReason: String, Codable, Sendable, CaseIterable {
    // Duplicate Dragons
    case exactBinaryMatch
    case nearDuplicateCluster
    case burstGroup
    case editedVariant
    case repeatedCapture

    // Clutter Undead / metadata
    case screenshotCapture
    case tinyResolution
    case extremeAspect
    case livePhotoPair
    case screenRecording
    case lowQuality

    // Storage Behemoths
    case resourceSize
    case videoDuration
    case ultraHighResolution

    // Archive Relics
    case oldCapture

    // Video Phantoms
    case veryShortVideo
    case darkFrames
    case loopVideo
    case highFrameRate

    // Glitchborn
    case brokenMetadata

    // Fallback
    case noStrongSignal

    var factText: String {
        switch self {
        case .exactBinaryMatch:    return "Identical file content to another capture"
        case .nearDuplicateCluster:return "Nearly identical to another capture"
        case .burstGroup:          return "Captured seconds apart in the same burst"
        case .editedVariant:       return "Looks like a cropped or edited copy of another capture"
        case .repeatedCapture:     return "Saved more than once on different days"
        case .screenshotCapture:   return "Taken as a screenshot"
        case .tinyResolution:      return "Very small resolution for a modern camera"
        case .extremeAspect:       return "Far wider than tall, like a panorama"
        case .livePhotoPair:       return "A Live Photo with a paired motion file"
        case .screenRecording:     return "Recorded from the screen"
        case .lowQuality:          return "Unusual proportions, likely saved from elsewhere"
        case .resourceSize:        return "Takes up a very large amount of storage"
        case .videoDuration:       return "An unusually long recording"
        case .ultraHighResolution: return "Recorded in ultra-high resolution"
        case .oldCapture:          return "Captured years ago"
        case .veryShortVideo:      return "Barely a moment of video"
        case .darkFrames:          return "Captured in near darkness"
        case .loopVideo, .highFrameRate: return "A looping or slow-motion clip"
        case .brokenMetadata:      return "Could not be fully loaded"
        case .noStrongSignal:      return "No strong signals — a routine gallery wanderer"
        }
    }
}

/// The full verdict for one library asset: which monster it summons, why,
/// and how confident the dungeon is. Family and rarity mirror the monster
/// type so callers can style cards without re-deriving anything.
struct MonsterClassification: Equatable, Sendable {
    let monsterType: MonsterType
    let family: MonsterFamily
    let rarity: MonsterRarity
    let confidence: Double
    let reasons: [ClassificationReason]
    let estimatedBytes: Int64?
    let relatedAssetIdentifiers: [String]
    let requiresCarefulReview: Bool

    init(
        monsterType: MonsterType,
        confidence: Double,
        reasons: [ClassificationReason],
        estimatedBytes: Int64? = nil,
        relatedAssetIdentifiers: [String] = [],
        requiresCarefulReview: Bool = false
    ) {
        self.monsterType = monsterType
        self.family = monsterType.family
        self.rarity = monsterType.rarity
        self.confidence = confidence
        self.reasons = reasons
        self.estimatedBytes = estimatedBytes
        self.relatedAssetIdentifiers = relatedAssetIdentifiers
        self.requiresCarefulReview = requiresCarefulReview
    }

    /// Number of duplicate companions (0 for solo monsters).
    var groupSize: Int { relatedAssetIdentifiers.count }

    /// True when this asset belongs to a multi-copy duplicate group.
    var isGrouped: Bool { groupSize > 0 }

    /// Plain-language "Why did this appear?" line for encounter cards.
    var whyText: String {
        guard !reasons.isEmpty else { return ClassificationReason.noStrongSignal.factText }
        let facts = reasons.map(\.factText).joined(separator: " · ")
        guard isGrouped else { return facts }
        let companionCopy = groupSize == 1 ? "1 companion copy" : "\(groupSize) companion copies"
        return "\(facts) — \(companionCopy) await judgment together"
    }

    /// Short bestiary line separating "potentially removable" from
    /// "review carefully" in the player's voice.
    var reviewNote: String {
        requiresCarefulReview
            ? "Review carefully before deciding."
            : "Potentially removable."
    }
}

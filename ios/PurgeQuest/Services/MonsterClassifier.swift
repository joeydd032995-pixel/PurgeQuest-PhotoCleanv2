//
//  MonsterClassifier.swift
//  PurgeQuest
//
//  Explanation-first classifier (rollout stages 1–5). Duplicate clusters are
//  resolved first — they carry the clearest "why" — then metadata rules and
//  deep-signal rules (sampled frames, on-device Vision) run for solo assets.
//  Every verdict records its reasons so cards and the bestiary can answer
//  "Why did this appear?".
//
//  Photo rules run from the most specific fact to the least: what the item is
//  (broken, a code, a Live Photo, a screenshot, a document, a panorama, a
//  thumbnail), then what is wrong with it (saved from elsewhere, out of
//  focus, dark), and only then how old it is. Age is true of every photo in
//  an old library, and dives are dealt oldest first, so an age rule placed
//  ahead of the defects would hide them behind "Ancient Archive" for years of
//  photos. An old photo with a defect keeps the careful-review flag and says
//  both things.
//
//  Pure over MediaItem + MediaFingerprint: UIImage and PHAsset work happens
//  upstream (PhotoLibraryService / MediaFingerprinter), which keeps the rules
//  fully unit-testable.
//

import Foundation

/// Result of classifying a fetched library batch.
struct ClassifiedLibrary: Sendable {
    /// Verdicts keyed by asset identifier.
    let classifications: [String: MonsterClassification]
    /// Duplicate clusters found in the batch (stage 1).
    let clusters: [DuplicateCluster]
    /// Cluster representative asset ID → recommended survivor asset ID.
    let recommendedSurvivorIDs: [String: String]
}

enum MonsterClassifier {

    // Metadata thresholds. Cheap, high-impact, low false positives.
    static let panoramaAspect: Double = 2.5
    static let thumbGoblinLongEdge: Int = 640
    // The blur, dark, tall-download and dense-text lines are defined once, in PhotoRules, where the Linux
    // harness tests them. They are restated here so the rest of the app and its tests keep one name.
    static let lowQualityAspect: Double = PhotoRules.tallAspect
    static let blurSharpness: Double = ThumbnailAnalysis.blurLine
    static let darkLuminance: Double = PhotoRules.darkLuminance
    static let archiveYears: Int = 3

    static let gigabyte: Int64 = 1_000_000_000
    static let halfGigabyte: Int64 = 500_000_000
    static let hundredMegabyte: Int64 = 100_000_000

    // Stage 5 thresholds: on-device text density (documents photographed
    // instead of kept). Measured by VisionAnalysisService.
    static let denseTextCharacters = PhotoRules.denseTextCharacters
    static let denseTextRegions = PhotoRules.denseTextRegions

    // Stage 3: a motionless clip must at least outlive a blooper to summon
    // the Framed Phantom.
    static let staticVideoMinimumDuration: Double = 3

    // Ordinary clips (no other signal) split into three Wraiths by length.
    static let mistWraithMaxDuration: Double = 20
    static let tatterWraithMaxDuration: Double = 60

    static func classify(items: [MediaItem], fingerprints: [MediaFingerprint], now: Date = Date()) -> ClassifiedLibrary {
        // A repeated identifier keeps its first entry rather than trapping.
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let fpByID = Dictionary(fingerprints.map { ($0.assetID, $0) }, uniquingKeysWith: { first, _ in first })
        let clusters = DuplicateDetectionEngine.findClusters(in: fingerprints)

        var classifications: [String: MonsterClassification] = [:]
        var survivors: [String: String] = [:]
        var groupedIDs = Set<String>()

        // MARK: Duplicate clusters (stage 1)

        for cluster in clusters {
            let members = cluster.memberIDs.compactMap { byID[$0] }
            guard let oldest = members.first else { continue }
            groupedIDs.formUnion(cluster.memberIDs)

            let memberFPs = cluster.memberIDs.compactMap { fpByID[$0] }
            if let survivor = DuplicateDetectionEngine.recommendedSurvivor(in: memberFPs) {
                survivors[oldest.id] = survivor
            }

            let related = Array(cluster.memberIDs.dropFirst())
            let type = monsterType(for: cluster, members: memberFPs)
            let reasons = reasons(for: cluster, type: type)
            let bytes = oldest.estimatedBytes

            classifications[oldest.id] = MonsterClassification(
                monsterType: type,
                confidence: cluster.kind == .exact ? 0.98 : 0.88,
                reasons: reasons,
                estimatedBytes: bytes,
                relatedAssetIdentifiers: related,
                requiresCarefulReview: type.defaultsToCarefulReview || type == .cloneChimera
            )
        }

        // MARK: Metadata rules for solo assets (stage 2)

        for item in items where !groupedIDs.contains(item.id) {
            classifications[item.id] = classifySolo(item, now: now)
        }

        return ClassifiedLibrary(
            classifications: classifications,
            clusters: clusters,
            recommendedSurvivorIDs: survivors
        )
    }

    // MARK: - Solo rules

    static func classifySolo(_ item: MediaItem, now: Date = Date()) -> MonsterClassification {
        item.kind == .video ? classifyVideo(item) : classifyPhoto(item, now: now)
    }

    private static func classifyPhoto(_ item: MediaItem, now: Date) -> MonsterClassification {
        let bytes = item.estimatedBytes

        // Glitchborn first (stage 4): empty or unloadable media is never
        // auto-deletable.
        if bytes <= 0 || item.pixelWidth <= 0 || item.pixelHeight <= 0 {
            return MonsterClassification(
                monsterType: .staticHusk, confidence: 0.9,
                reasons: [.emptyResource], estimatedBytes: bytes,
                requiresCarefulReview: true
            )
        }
        if item.loadFailed {
            return MonsterClassification(
                monsterType: .nullPortrait, confidence: 0.85,
                reasons: [.renderFailed], estimatedBytes: bytes,
                requiresCarefulReview: true
            )
        }
        // Stage 5: an embedded code is always review material — it may be a
        // ticket, key, or one-time link.
        if let vision = item.visionSignals, vision.hasBarcode {
            return MonsterClassification(
                monsterType: .sigilSpecter, confidence: 0.9,
                reasons: [.embeddedCode], estimatedBytes: bytes,
                requiresCarefulReview: true
            )
        }
        // Live Photo with paired motion file — the everyday iPhone capture.
        if item.isLivePhoto {
            return MonsterClassification(
                monsterType: .livePhotoLycan, confidence: 0.85,
                reasons: [.livePhotoPair], estimatedBytes: bytes,
                requiresCarefulReview: MonsterType.livePhotoLycan.defaultsToCarefulReview
            )
        }
        // Screenshots — the subtype flag is the canonical signal.
        if item.isScreenshot {
            return MonsterClassification(
                monsterType: .screenshotSpecter, confidence: 0.95,
                reasons: [.screenshotCapture], estimatedBytes: bytes
            )
        }
        // Stage 5: dense text — a document or note photographed instead of kept.
        if let vision = item.visionSignals,
           PhotoRules.isDenseText(characters: vision.characterCount, regions: vision.regionCount) {
            return MonsterClassification(
                monsterType: .tomeWraith, confidence: 0.8,
                reasons: [.denseText], estimatedBytes: bytes
            )
        }
        // Panoramas: Photos' own flag (which also covers a vertical sweep), or an extremely wide frame.
        if item.isPanorama {
            return MonsterClassification(
                monsterType: .panoramaColossus, confidence: 0.9,
                reasons: [.panoramaCapture], estimatedBytes: bytes
            )
        }
        if Double(item.pixelWidth) / Double(max(1, item.pixelHeight)) >= panoramaAspect {
            return MonsterClassification(
                monsterType: .panoramaColossus, confidence: 0.8,
                reasons: [.extremeAspect], estimatedBytes: bytes
            )
        }
        // Tiny resolution posing as a real photo.
        if max(item.pixelWidth, item.pixelHeight) < thumbGoblinLongEdge {
            return MonsterClassification(
                monsterType: .thumbGoblin, confidence: 0.85,
                reasons: [.tinyResolution], estimatedBytes: bytes
            )
        }
        // From here on a verdict about a defect also says when the photo is old, and an old photo is
        // always reviewed carefully: a soft print from years ago may be the only one of its moment.
        let isOld = isArchiveAge(item.creationDate, now: now)
        func defect(_ type: MonsterType, _ reason: ClassificationReason) -> MonsterClassification {
            MonsterClassification(
                monsterType: type, confidence: 0.7,
                reasons: isOld ? [reason, .oldCapture] : [reason], estimatedBytes: bytes,
                requiresCarefulReview: isOld
            )
        }
        // Tall narrow and small — media saved from elsewhere. A phone's own 16:9 portrait photo or a
        // vertical panorama is just as narrow but several times larger, so it is left alone.
        if PhotoRules.isTallDownload(width: item.pixelWidth, height: item.pixelHeight) {
            return defect(.lowQualityLich, .lowQuality)
        }
        // Cheap thumbnail measurements (ThumbnailAnalysis): focus, then exposure.
        if PhotoRules.isBlurry(focus: item.sharpness) {
            return defect(.blurBeast, .outOfFocus)
        }
        if PhotoRules.isDark(luminance: item.luminance, highlight: item.highlightLuminance) {
            return defect(.darkWraith, .darkFrames)
        }
        // Ancient Archive — an old memory with nothing wrong with it, always handled gently.
        if isOld {
            return MonsterClassification(
                monsterType: .ancientArchive, confidence: 0.9,
                reasons: [.oldCapture], estimatedBytes: bytes,
                requiresCarefulReview: true
            )
        }
        // No strong signal — routine gallery wanderer.
        return MonsterClassification(
            monsterType: .blurBeast, confidence: 0.4,
            reasons: [.noStrongSignal], estimatedBytes: bytes
        )
    }

    /// True when a capture is at least `archiveYears` old.
    static func isArchiveAge(_ date: Date?, now: Date) -> Bool {
        guard let date, let years = Calendar.current.dateComponents([.year], from: date, to: now).year else { return false }
        return years >= archiveYears
    }

    private static func classifyVideo(_ item: MediaItem) -> MonsterClassification {
        let bytes = item.estimatedBytes
        let duration = item.durationSeconds

        // Glitchborn first: media whose metadata is broken.
        if duration <= 0 {
            return MonsterClassification(
                monsterType: .corruptedCodec, confidence: 0.9,
                reasons: [.brokenMetadata], estimatedBytes: bytes,
                requiresCarefulReview: true
            )
        }
        // Stage 4: empty files and unloadable renders are never auto-deletable.
        if bytes <= 0 {
            return MonsterClassification(
                monsterType: .staticHusk, confidence: 0.9,
                reasons: [.emptyResource], estimatedBytes: bytes,
                requiresCarefulReview: true
            )
        }
        if item.loadFailed {
            return MonsterClassification(
                monsterType: .corruptedCodec, confidence: 0.85,
                reasons: [.renderFailed], estimatedBytes: bytes,
                requiresCarefulReview: true
            )
        }
        // Storage Behemoths by size, then resolution, then duration.
        if bytes >= gigabyte {
            return MonsterClassification(
                monsterType: .gigabyteGorgon, confidence: 0.95,
                reasons: [.resourceSize], estimatedBytes: bytes
            )
        }
        if bytes >= halfGigabyte {
            return MonsterClassification(
                monsterType: .memoryHogMinotaur, confidence: 0.9,
                reasons: [.resourceSize], estimatedBytes: bytes
            )
        }
        if max(item.pixelWidth, item.pixelHeight) >= 3840 {
            return MonsterClassification(
                monsterType: .fourKKraken, confidence: 0.85,
                reasons: [.ultraHighResolution], estimatedBytes: bytes
            )
        }
        if duration > 120 {
            return MonsterClassification(
                monsterType: .longTakeLeviathan, confidence: 0.85,
                reasons: [.videoDuration], estimatedBytes: bytes
            )
        }
        if item.isScreenRecording {
            return MonsterClassification(
                monsterType: .screenRecordingShade, confidence: 0.85,
                reasons: [.screenRecording], estimatedBytes: bytes
            )
        }
        // Captures that bend time: a time-lapse, slow motion, or a loop. Each says which it is.
        if let bent = timeBendingReason(item) {
            return MonsterClassification(
                monsterType: .timelapsePhantom, confidence: 0.85,
                reasons: [bent], estimatedBytes: bytes
            )
        }
        // Stage 3: sampled-frame signals refine the phantoms.
        if let frames = item.frameSignals {
            if frames.isFlickering {
                return MonsterClassification(
                    monsterType: .flickerWraith, confidence: 0.8,
                    reasons: [.flickeringFrames], estimatedBytes: bytes
                )
            }
            if duration >= staticVideoMinimumDuration && frames.isStatic {
                return MonsterClassification(
                    monsterType: .framedPhantom, confidence: 0.8,
                    reasons: [.staticFrames], estimatedBytes: bytes
                )
            }
            if frames.isDark {
                return MonsterClassification(
                    monsterType: .pocketPoltergeist, confidence: 0.7,
                    reasons: [.darkFrames], estimatedBytes: bytes
                )
            }
            if frames.isErratic {
                return MonsterClassification(
                    monsterType: .shakyGhost, confidence: 0.7,
                    reasons: [.erraticMotion], estimatedBytes: bytes
                )
            }
        }
        // Video Phantoms: barely-a-moment or near-black clips.
        if duration < 2 {
            return MonsterClassification(
                monsterType: .pocketPoltergeist, confidence: 0.85,
                reasons: [.veryShortVideo], estimatedBytes: bytes
            )
        }
        if PhotoRules.isDark(luminance: item.luminance, highlight: item.highlightLuminance) {
            return MonsterClassification(
                monsterType: .pocketPoltergeist, confidence: 0.6,
                reasons: [.darkFrames], estimatedBytes: bytes
            )
        }
        if duration < 5 {
            return MonsterClassification(
                monsterType: .boringBlooper, confidence: 0.8,
                reasons: [.veryShortVideo], estimatedBytes: bytes
            )
        }
        if bytes >= hundredMegabyte {
            return MonsterClassification(
                monsterType: .videoVampire, confidence: 0.8,
                reasons: [.resourceSize], estimatedBytes: bytes
            )
        }
        // No strong signal — an ordinary clip becomes one of the three Wraiths by
        // length. The Shaky Ghost is still summoned by erratic sampled frames.
        let wraith: MonsterType
        if duration < mistWraithMaxDuration {
            wraith = .mistWraith
        } else if duration < tatterWraithMaxDuration {
            wraith = .tatterWraith
        } else {
            wraith = .voidWraith
        }
        return MonsterClassification(
            monsterType: wraith, confidence: 0.4,
            reasons: [.noStrongSignal], estimatedBytes: bytes
        )
    }

    /// Why a clip is a Timelapse Phantom, if it is one.
    private static func timeBendingReason(_ item: MediaItem) -> ClassificationReason? {
        if item.isTimelapse { return .timelapse }
        if item.isHighFrameRate { return .highFrameRate }
        if item.isLooping { return .loopVideo }
        return nil
    }

    // MARK: - Cluster monster mapping

    /// Which dragon a cluster summons, in priority order.
    static func monsterType(for cluster: DuplicateCluster, members: [MediaFingerprint]) -> MonsterType {
        let count = cluster.memberIDs.count

        if count >= DuplicateDetectionEngine.hoardSize { return .hoardHydra }
        if cluster.kind == .exact && count == 2 { return .perfectPairWyrmling }
        if cluster.kind == .burst { return .burstHydra }
        if cluster.kind == .edited { return .cloneChimera }
        if !members.isEmpty && members.allSatisfy(\.isScreenshot) { return .screenshotTwin }

        let dates = members.compactMap(\.creationDate).sorted()
        if dates.count >= 2, let span = dates.last?.timeIntervalSince(dates.first ?? .distantPast), span > DuplicateDetectionEngine.echoSpan {
            return .albumEcho
        }
        // The same file saved repeatedly within one day — a download echo.
        let dims = Set(members.map { "\($0.pixelWidth)x\($0.pixelHeight)" })
        if dims.count == 1,
           dates.count >= 2,
           let span = dates.last?.timeIntervalSince(dates.first ?? .distantPast),
           span <= DuplicateDetectionEngine.sameDaySpan {
            return .downloadDrake
        }
        return .duplicateDragon
    }

    private static func reasons(for cluster: DuplicateCluster, type: MonsterType) -> [ClassificationReason] {
        var reasons: [ClassificationReason]
        switch cluster.kind {
        case .exact:  reasons = [.exactBinaryMatch]
        case .burst:  reasons = [.burstGroup]
        case .edited: reasons = [.editedVariant]
        case .near:   reasons = [.nearDuplicateCluster]
        }
        // The same capture turning up again weeks later.
        if type == .albumEcho { reasons.append(.repeatedCapture) }
        return reasons
    }
}

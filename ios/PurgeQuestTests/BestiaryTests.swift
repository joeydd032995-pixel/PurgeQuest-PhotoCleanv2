//
//  BestiaryTests.swift
//  PurgeQuest
//
//  Tests for the bestiary expansion: roster sanity, rarity ordering, the
//  two-stage duplicate pipeline, metadata classification rules, survivor
//  ranking, dungeon theme thresholds, and encounter stat aggregation.
//

import Testing
import SwiftData
import Foundation
import UIKit
@testable import PurgeQuest

@MainActor
struct BestiaryExpansionTests {

    // MARK: - Helpers

    private func makeItem(
        id: String,
        kind: MediaKind = .photo,
        daysAgo: Int = 1,
        width: Int = 4000,
        height: Int = 3000,
        bytes: Int64 = 2_000_000,
        duration: Double = 0,
        favorite: Bool = false,
        isScreenshot: Bool = false,
        hasEdits: Bool = false,
        isScreenRecording: Bool = false,
        isLivePhoto: Bool = false,
        isLooping: Bool = false,
        isHighFrameRate: Bool = false,
        sharpness: Double? = 60,
        luminance: Double? = 0.5
    ) -> MediaItem {
        MediaItem(
            id: id,
            kind: kind,
            creationDate: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()),
            pixelWidth: width,
            pixelHeight: height,
            durationSeconds: duration,
            estimatedBytes: bytes,
            isFavorite: favorite,
            playbackStyle: 1,
            isScreenshot: isScreenshot,
            hasEdits: hasEdits,
            isScreenRecording: isScreenRecording,
            isLivePhoto: isLivePhoto,
            isLooping: isLooping,
            isHighFrameRate: isHighFrameRate,
            sharpness: sharpness,
            luminance: luminance
        )
    }

    private func makeFingerprint(
        from item: MediaItem,
        dHash: UInt64? = nil,
        contentHash: String? = nil
    ) -> MediaFingerprint {
        MediaFingerprint(
            assetID: item.id,
            byteSize: item.estimatedBytes,
            pixelWidth: item.pixelWidth,
            pixelHeight: item.pixelHeight,
            durationSeconds: item.durationSeconds,
            creationDate: item.creationDate,
            isFavorite: item.isFavorite,
            isScreenshot: item.isScreenshot,
            hasEdits: item.hasEdits,
            isScreenRecording: item.isScreenRecording,
            dHash: dHash,
            sharpness: item.sharpness,
            contentHash: contentHash
        )
    }

    private func classify(_ items: [MediaItem], fingerprints: [MediaFingerprint]) -> [String: MonsterClassification] {
        MonsterClassifier.classify(items: items, fingerprints: fingerprints).classifications
    }

    // MARK: - Roster

    @Test func rosterHasSixFamiliesAndCompleteMetadata() {
        #expect(MonsterType.allCases.count == 33)
        #expect(MonsterFamily.allCases.count == 6)
        for type in MonsterType.allCases {
            #expect(!type.lore.isEmpty)
            #expect(!type.unlockableTitle.isEmpty)
            #expect(!type.signalDescription.isEmpty)
            #expect(!type.reviewGuidance.isEmpty)
            #expect(type.xpReward > 0)
            #expect(type.hp >= 1)
        }
    }

    @Test func existingMonsterRawValuesSurvive() {
        // Saves, quests, and records reference these raw values.
        #expect(MonsterType(rawValue: "duplicateDragon") == .duplicateDragon)
        #expect(MonsterType(rawValue: "corruptedCodec") == .corruptedCodec)
        #expect(MonsterType(rawValue: "ancientArchive") == .ancientArchive)
    }

    @Test func legacyMonstersAreRehomedIntoFamilies() {
        #expect(MonsterType.blurBeast.family == .clutterUndead)
        #expect(MonsterType.screenshotSpecter.family == .clutterUndead)
        #expect(MonsterType.lowQualityLich.family == .clutterUndead)
        #expect(MonsterType.darkWraith.family == .clutterUndead)
        #expect(MonsterType.ancientArchive.family == .archiveRelics)
        #expect(MonsterType.videoVampire.family == .videoPhantoms)
        #expect(MonsterType.shakyGhost.family == .videoPhantoms)
        #expect(MonsterType.boringBlooper.family == .videoPhantoms)
        #expect(MonsterType.timelapsePhantom.family == .videoPhantoms)
        #expect(MonsterType.longTakeLeviathan.family == .storageBehemoths)
        #expect(MonsterType.memoryHogMinotaur.family == .storageBehemoths)
        #expect(MonsterType.corruptedCodec.family == .glitchborn)
        #expect(MonsterType.duplicateDragon.family == .duplicateDragons)
    }

    @Test func rarityOrdersCorrectly() {
        #expect(MonsterRarity.common < MonsterRarity.uncommon)
        #expect(MonsterRarity.uncommon < MonsterRarity.rare)
        #expect(MonsterRarity.rare < MonsterRarity.elite)
        #expect(MonsterRarity.elite < MonsterRarity.legendary)
        #expect(MonsterRarity.legendary > MonsterRarity.common)
        #expect(MonsterRarity.legendary.hasCrownBadge)
        #expect(!MonsterRarity.common.hasCrownBadge)
    }

    // MARK: - Duplicate pipeline (stage 1)

    @Test func hammingDistanceCountsBitDifferences() {
        #expect(DuplicateDetectionEngine.hammingDistance(0, 0) == 0)
        #expect(DuplicateDetectionEngine.hammingDistance(0, UInt64.max) == 64)
        #expect(DuplicateDetectionEngine.hammingDistance(0b1010, 0b0110) == 2)
    }

    @Test func exactPairFormsWyrmlingWithSurvivorSuggestion() {
        let a = makeItem(id: "a", favorite: false)
        let b = makeItem(id: "b", bytes: 2_000_001, favorite: true)
        let fps = [
            makeFingerprint(from: a, contentHash: "abc123"),
            makeFingerprint(from: b, contentHash: "abc123")
        ]
        let result = classify([a, b], fingerprints: fps)
        let ca = result["a"]
        #expect(ca?.monsterType == .perfectPairWyrmling)
        #expect(ca?.family == .duplicateDragons)
        #expect(ca?.isGrouped == true)
        #expect(ca?.relatedAssetIdentifiers == ["b"])
        // Survivor recommendation: the favorite wins, but nothing is pre-decided.
        let library = MonsterClassifier.classify(items: [a, b], fingerprints: fps)
        #expect(library.recommendedSurvivorIDs.values.first == "b")
    }

    @Test func burstWindowFormsBurstHydra() {
        let base = UInt64(0b1111_0000_1111_0000)
        let items = (0..<3).map { i in
            makeItem(id: "burst\(i)", bytes: Int64(3_000_000 + i * 7_777))
        }
        // Same dHash, captures seconds apart.
        let fps = items.enumerated().map { i, item in
            makeFingerprint(from: item, dHash: base).withCreationOffset(TimeInterval(i))
        }
        let result = classify(items, fingerprints: fps)
        #expect(result[items[0].id]?.monsterType == .burstHydra)
    }

    @Test func editedVariantFormsCloneChimera() {
        let a = makeItem(id: "orig", bytes: 4_000_000)
        let b = makeItem(id: "edited", width: 3000, height: 2000, bytes: 3_500_000)
        let fps = [
            makeFingerprint(from: a, dHash: 0xFF00FF00FF00FF00).withCreationOffset(0),
            makeFingerprint(from: b, dHash: 0xFF00FF00FF00FF00).withCreationOffset(60)
        ]
        let result = classify([a, b], fingerprints: fps)
        #expect(result["orig"]?.monsterType == .cloneChimera)
        #expect(result["orig"]?.requiresCarefulReview == true)
    }

    @Test func echoAcrossWeeksFormsAlbumEcho() {
        let a = makeItem(id: "old", daysAgo: 60, bytes: 5_000_000)
        let b = makeItem(id: "new", daysAgo: 5, bytes: 5_000_100)
        let fps = [
            makeFingerprint(from: a, dHash: 0x0F0F0F0F0F0F0F0F),
            makeFingerprint(from: b, dHash: 0x0F0F0F0F0F0F0F0F)
        ]
        let result = classify([a, b], fingerprints: fps)
        #expect(result["old"]?.monsterType == .albumEcho)
    }

    @Test func sixCopiesFormHoardHydra() {
        let base = UInt64(0xAAAA_5555_AAAA_5555)
        let items = (0..<6).map { i in makeItem(id: "hoard\(i)", bytes: Int64(6_000_000 + i * 9_999)) }
        let fps = items.enumerated().map { i, item in
            makeFingerprint(from: item, dHash: base).withCreationOffset(TimeInterval(i * 86_400))
        }
        let result = classify(items, fingerprints: fps)
        #expect(result[items[0].id]?.monsterType == .hoardHydra)
    }

    @Test func screenshotClusterFormsScreenshotTwin() {
        let items = (0..<2).map { i in
            makeItem(id: "shot\(i)", daysAgo: 3, bytes: Int64(400_000 + i * 1_234), isScreenshot: true)
        }
        let fps = items.enumerated().map { i, item in
            makeFingerprint(from: item, dHash: 0x1234_5678_9ABC_DEF0).withCreationOffset(TimeInterval(i * 86_400))
        }
        let result = classify(items, fingerprints: fps)
        #expect(result[items[0].id]?.monsterType == .screenshotTwin)
    }

    @Test func sameFileSavedWithinADayFormsDownloadDrake() {
        let a = makeItem(id: "d1", daysAgo: 1, bytes: 8_000_000)
        let b = makeItem(id: "d2", daysAgo: 1, bytes: 8_000_500)
        let fps = [
            makeFingerprint(from: a, dHash: 0x00FF_00FF_00FF_00FF).withCreationOffset(0),
            makeFingerprint(from: b, dHash: 0x00FF_00FF_00FF_00FF).withCreationOffset(3600)
        ]
        let result = classify([a, b], fingerprints: fps)
        #expect(result["d1"]?.monsterType == .downloadDrake)
    }

    @Test func survivorRankingPrefersFavoriteThenSharpness() {
        let plain = makeItem(id: "plain")
        let fav = makeItem(id: "fav", bytes: 1, favorite: true)
        let fps = [makeFingerprint(from: plain), makeFingerprint(from: fav)]
        #expect(DuplicateDetectionEngine.recommendedSurvivor(in: fps) == "fav")

        let soft = makeItem(id: "soft", sharpness: 5)
        let crisp = makeItem(id: "crisp", sharpness: 90)
        #expect(DuplicateDetectionEngine.recommendedSurvivor(in: [makeFingerprint(from: soft), makeFingerprint(from: crisp)]) == "crisp")
    }

    // MARK: - Metadata rules (stage 2)

    @Test func screenshotFlagSummonsSpecter() {
        let item = makeItem(id: "s", isScreenshot: true)
        #expect(classify([item], fingerprints: [makeFingerprint(from: item)])["s"]?.monsterType == .screenshotSpecter)
    }

    @Test func livePhotoSummonsLycan() {
        let item = makeItem(id: "lp", isLivePhoto: true)
        let c = classify([item], fingerprints: [makeFingerprint(from: item)])["lp"]
        #expect(c?.monsterType == .livePhotoLycan)
        #expect(c?.requiresCarefulReview == false)
    }

    @Test func tinyImageSummonsThumbGoblin() {
        let item = makeItem(id: "t", width: 400, height: 300)
        #expect(classify([item], fingerprints: [makeFingerprint(from: item)])["t"]?.monsterType == .thumbGoblin)
    }

    @Test func wideRatioSummonsPanoramaColossus() {
        let item = makeItem(id: "p", width: 10_000, height: 3_000)
        #expect(classify([item], fingerprints: [makeFingerprint(from: item)])["p"]?.monsterType == .panoramaColossus)
    }

    @Test func tallNarrowImageSummonsLowQualityLich() {
        let item = makeItem(id: "n", width: 1_000, height: 3_000)
        #expect(classify([item], fingerprints: [makeFingerprint(from: item)])["n"]?.monsterType == .lowQualityLich)
    }

    @Test func blurryImageSummonsBlurBeast() {
        let item = makeItem(id: "bl", sharpness: 3)
        #expect(classify([item], fingerprints: [makeFingerprint(from: item)])["bl"]?.monsterType == .blurBeast)
    }

    @Test func darkImageSummonsDarkWraith() {
        let item = makeItem(id: "dk", luminance: 0.1)
        #expect(classify([item], fingerprints: [makeFingerprint(from: item)])["dk"]?.monsterType == .darkWraith)
    }

    @Test func oldPhotoSummonsAncientArchiveWithCarefulReview() {
        let item = makeItem(id: "old", daysAgo: 4 * 365)
        let c = classify([item], fingerprints: [makeFingerprint(from: item)])["old"]
        #expect(c?.monsterType == .ancientArchive)
        #expect(c?.requiresCarefulReview == true)
        #expect(c?.reasons.contains(.oldCapture) == true)
    }

    @Test func gigabyteVideoSummonsGorgon() {
        let item = makeItem(id: "g", kind: .video, bytes: 1_200_000_000, duration: 300)
        #expect(classify([item], fingerprints: [makeFingerprint(from: item)])["g"]?.monsterType == .gigabyteGorgon)
    }

    @Test func halfGigabyteVideoSummonsMinotaur() {
        let item = makeItem(id: "m", kind: .video, bytes: 600_000_000, duration: 90)
        #expect(classify([item], fingerprints: [makeFingerprint(from: item)])["m"]?.monsterType == .memoryHogMinotaur)
    }

    @Test func fourKVideoSummonsKraken() {
        let item = makeItem(id: "k", kind: .video, width: 3840, height: 2160, bytes: 80_000_000, duration: 60)
        #expect(classify([item], fingerprints: [makeFingerprint(from: item)])["k"]?.monsterType == .fourKKraken)
    }

    @Test func longVideoSummonsLeviathan() {
        let item = makeItem(id: "l", kind: .video, bytes: 40_000_000, duration: 200)
        #expect(classify([item], fingerprints: [makeFingerprint(from: item)])["l"]?.monsterType == .longTakeLeviathan)
    }

    @Test func screenRecordingSummonsShade() {
        let item = makeItem(id: "sr", kind: .video, bytes: 20_000_000, duration: 30, isScreenRecording: true)
        #expect(classify([item], fingerprints: [makeFingerprint(from: item)])["sr"]?.monsterType == .screenRecordingShade)
    }

    @Test func loopingVideoSummonsTimelapsePhantom() {
        let item = makeItem(id: "tl", kind: .video, bytes: 20_000_000, duration: 30, isLooping: true)
        #expect(classify([item], fingerprints: [makeFingerprint(from: item)])["tl"]?.monsterType == .timelapsePhantom)
    }

    @Test func brokenVideoSummonsCorruptedCodecWithCarefulReview() {
        let item = makeItem(id: "cc", kind: .video, bytes: 10_000_000, duration: 0)
        let c = classify([item], fingerprints: [makeFingerprint(from: item)])["cc"]
        #expect(c?.monsterType == .corruptedCodec)
        #expect(c?.requiresCarefulReview == true)
    }

    @Test func veryShortVideoSummonsPocketPoltergeist() {
        let item = makeItem(id: "pp", kind: .video, bytes: 5_000_000, duration: 1.2)
        #expect(classify([item], fingerprints: [makeFingerprint(from: item)])["pp"]?.monsterType == .pocketPoltergeist)
    }

    @Test func blooperUnderFiveSecondsSummonsBoringBlooper() {
        let item = makeItem(id: "bb", kind: .video, bytes: 5_000_000, duration: 3.5)
        #expect(classify([item], fingerprints: [makeFingerprint(from: item)])["bb"]?.monsterType == .boringBlooper)
    }

    @Test func largeVideoSummonsVideoVampire() {
        let item = makeItem(id: "vv", kind: .video, bytes: 150_000_000, duration: 30)
        #expect(classify([item], fingerprints: [makeFingerprint(from: item)])["vv"]?.monsterType == .videoVampire)
    }

    @Test func carefulReviewFlagsFollowFamilies() {
        #expect(MonsterType.ancientArchive.defaultsToCarefulReview)
        #expect(MonsterType.corruptedCodec.defaultsToCarefulReview)
        #expect(MonsterType.nullPortrait.defaultsToCarefulReview)
        #expect(MonsterType.staticHusk.defaultsToCarefulReview)
        #expect(MonsterType.sigilSpecter.defaultsToCarefulReview)
        #expect(!MonsterType.screenshotSpecter.defaultsToCarefulReview)
        #expect(!MonsterType.tomeWraith.defaultsToCarefulReview)
        #expect(!MonsterType.blurBeast.defaultsToCarefulReview)
    }

    // MARK: - Stages 3–5: deep signals

    @Test func stageThreeToFiveMonstersLandInFamilies() {
        #expect(MonsterType.framedPhantom.family == .videoPhantoms)
        #expect(MonsterType.flickerWraith.family == .videoPhantoms)
        #expect(MonsterType.nullPortrait.family == .glitchborn)
        #expect(MonsterType.staticHusk.family == .glitchborn)
        #expect(MonsterType.tomeWraith.family == .clutterUndead)
        #expect(MonsterType.sigilSpecter.family == .clutterUndead)
    }

    @Test func staticFootageSummonsFramedPhantom() {
        var item = makeItem(id: "fp", kind: .video, bytes: 5_000_000, duration: 10)
        item.frameSignals = VideoFrameSignals.evaluate(luminances: [0.5, 0.501, 0.502])
        let c = classify([item], fingerprints: [makeFingerprint(from: item)])["fp"]
        #expect(c?.monsterType == .framedPhantom)
        #expect(c?.reasons.contains(.staticFrames) == true)
    }

    @Test func flickeringFootageSummonsFlickerWraith() {
        var item = makeItem(id: "fw", kind: .video, bytes: 5_000_000, duration: 10)
        item.frameSignals = VideoFrameSignals.evaluate(luminances: [0.2, 0.9, 0.15])
        let c = classify([item], fingerprints: [makeFingerprint(from: item)])["fw"]
        #expect(c?.monsterType == .flickerWraith)
        #expect(c?.reasons.contains(.flickeringFrames) == true)
    }

    @Test func erraticMotionUpgradesShakyGhost() {
        var item = makeItem(id: "em", kind: .video, bytes: 5_000_000, duration: 10)
        item.frameSignals = VideoFrameSignals.evaluate(luminances: [0.3, 0.5, 0.35])
        let c = classify([item], fingerprints: [makeFingerprint(from: item)])["em"]
        #expect(c?.monsterType == .shakyGhost)
        #expect(c?.reasons.contains(.erraticMotion) == true)
    }

    @Test func darkSampledFramesSummonsPocketPoltergeist() {
        var item = makeItem(id: "df", kind: .video, bytes: 5_000_000, duration: 10)
        item.frameSignals = VideoFrameSignals.evaluate(luminances: [0.05, 0.09, 0.03])
        let c = classify([item], fingerprints: [makeFingerprint(from: item)])["df"]
        #expect(c?.monsterType == .pocketPoltergeist)
        #expect(c?.reasons.contains(.darkFrames) == true)
    }

    @Test func frameSignalEvaluationIsPureAndSafe() {
        #expect(VideoFrameSignals.evaluate(luminances: []) == nil)
        let single = VideoFrameSignals.evaluate(luminances: [0.5])
        #expect(single?.frameCount == 1)
        #expect(single?.meanMotion == 0)
        let dark = VideoFrameSignals.evaluate(luminances: [0.05, 0.1])
        #expect(dark?.darkFrameRatio == 1.0)
        // Non-finite luminances are filtered, not propagated.
        let dirty = VideoFrameSignals.evaluate(luminances: [0.5, .nan])
        #expect(dirty?.frameCount == 1)
    }

    @Test func failedRenderPhotoSummonsNullPortrait() {
        var item = makeItem(id: "np")
        item.loadFailed = true
        let c = classify([item], fingerprints: [makeFingerprint(from: item)])["np"]
        #expect(c?.monsterType == .nullPortrait)
        #expect(c?.requiresCarefulReview == true)
        #expect(c?.reasons.contains(.renderFailed) == true)
    }

    @Test func emptyFileSummonsStaticHusk() {
        let item = makeItem(id: "sh", bytes: 0)
        let c = classify([item], fingerprints: [makeFingerprint(from: item)])["sh"]
        #expect(c?.monsterType == .staticHusk)
        #expect(c?.requiresCarefulReview == true)
        #expect(c?.reasons.contains(.emptyResource) == true)
    }

    @Test func failedRenderVideoSummonsCorruptedCodec() {
        var item = makeItem(id: "cv", kind: .video, bytes: 10_000_000, duration: 30)
        item.loadFailed = true
        let c = classify([item], fingerprints: [makeFingerprint(from: item)])["cv"]
        #expect(c?.monsterType == .corruptedCodec)
        #expect(c?.reasons.contains(.renderFailed) == true)
    }

    @Test func barcodePhotoSummonsSigilSpecterWithCarefulReview() {
        var item = makeItem(id: "qr")
        item.visionSignals = VisionTextSignals(characterCount: 0, regionCount: 0, hasBarcode: true)
        let c = classify([item], fingerprints: [makeFingerprint(from: item)])["qr"]
        #expect(c?.monsterType == .sigilSpecter)
        #expect(c?.requiresCarefulReview == true)
        #expect(c?.reasons.contains(.embeddedCode) == true)
    }

    @Test func embeddedCodeOutranksScreenshotFlag() {
        var item = makeItem(id: "qs", isScreenshot: true)
        item.visionSignals = VisionTextSignals(characterCount: 0, regionCount: 0, hasBarcode: true)
        #expect(classify([item], fingerprints: [makeFingerprint(from: item)])["qs"]?.monsterType == .sigilSpecter)
    }

    @Test func denseTextPhotoSummonsTomeWraith() {
        var item = makeItem(id: "tw")
        item.visionSignals = VisionTextSignals(characterCount: 500, regionCount: 8, hasBarcode: false)
        let c = classify([item], fingerprints: [makeFingerprint(from: item)])["tw"]
        #expect(c?.monsterType == .tomeWraith)
        #expect(c?.reasons.contains(.denseText) == true)
    }

    @Test func sparseTextPhotoFallsThroughToMetadataRules() {
        var item = makeItem(id: "sp")
        item.visionSignals = VisionTextSignals(characterCount: 40, regionCount: 2, hasBarcode: false)
        #expect(classify([item], fingerprints: [makeFingerprint(from: item)])["sp"]?.monsterType != .tomeWraith)
    }

    @Test func unloadablePhotosAlsoSummonGlitchAbyss() {
        let items = (0..<10).map { i -> MediaItem in
            var item = makeItem(id: "gl\(i)")
            item.loadFailed = true
            return item
        }
        #expect(DungeonThemeEngine.theme(for: DungeonThemeEngine.composition(for: items)) == .glitchAbyss)
    }

    // MARK: - Why lines

    @Test func whyTextComposesReasonsAndCompanions() {
        let item = makeItem(id: "w", isScreenshot: true)
        let c = classify([item], fingerprints: [makeFingerprint(from: item)])["w"]
        #expect(c?.whyText.contains("screenshot") == true)

        var grouped = MonsterClassification(
            monsterType: .duplicateDragon, confidence: 0.9,
            reasons: [.nearDuplicateCluster], estimatedBytes: 100,
            relatedAssetIdentifiers: ["x", "y", "z"]
        )
        #expect(grouped.whyText.contains("3 companion copies"))
        grouped = MonsterClassification(
            monsterType: .perfectPairWyrmling, confidence: 0.9,
            reasons: [.exactBinaryMatch], estimatedBytes: 100,
            relatedAssetIdentifiers: ["x"]
        )
        #expect(grouped.whyText.contains("1 companion copy"))
    }

    // MARK: - Dungeon themes

    @Test func themeThresholdsPickExpectedDungeons() {
        func items(_ count: Int, _ build: (Int) -> MediaItem) -> [MediaItem] {
            (0..<count).map(build)
        }
        // Screenshot-heavy → Clutter Catacombs
        let shots = items(10) { makeItem(id: "s\($0)", isScreenshot: true) }
        #expect(DungeonThemeEngine.theme(for: DungeonThemeEngine.composition(for: shots)) == .clutterCatacombs)

        // Old-heavy → Archive Depths
        let old = items(10) { makeItem(id: "o\($0)", daysAgo: 4 * 365) }
        #expect(DungeonThemeEngine.theme(for: DungeonThemeEngine.composition(for: old)) == .archiveDepths)

        // Large-file-heavy → Vault of Excess
        let large = items(10) { makeItem(id: "L\($0)", kind: .video, bytes: 200_000_000, duration: 60) }
        #expect(DungeonThemeEngine.theme(for: DungeonThemeEngine.composition(for: large)) == .vaultOfExcess)

        // Video-heavy → Phantom Theater
        let videos = items(10) { makeItem(id: "v\($0)", kind: .video, bytes: 10_000_000, duration: 20) }
        #expect(DungeonThemeEngine.theme(for: DungeonThemeEngine.composition(for: videos)) == .phantomTheater)

        // Broken videos → Glitch Abyss
        let broken = items(10) { makeItem(id: "b\($0)", kind: .video, bytes: 1_000_000, duration: 0) }
        #expect(DungeonThemeEngine.theme(for: DungeonThemeEngine.composition(for: broken)) == .glitchAbyss)

        // Duplicate share above threshold → Dragon's Hoard
        var comp = DungeonThemeEngine.composition(for: items(20) { makeItem(id: "m\($0)") })
        comp.duplicateShare = 0.2
        #expect(DungeonThemeEngine.theme(for: comp) == .dragonsHoard)

        // Mixed, nothing dominant → Wild Gallery
        let mixed = items(20) { i in
            makeItem(id: "x\(i)", kind: i % 2 == 0 ? .photo : .video, daysAgo: 30, duration: 20)
        }
        #expect(DungeonThemeEngine.theme(for: DungeonThemeEngine.composition(for: mixed)) == .wildGallery)

        // Tiny batch → always Wild Gallery
        #expect(DungeonThemeEngine.theme(for: DungeonThemeEngine.composition(for: [shots[0]])) == .wildGallery)
    }

    @Test func themedWeightingMatchesEmphasizedFamily() {
        #expect(DungeonThemeEngine.isThemed(makeItem(id: "a", isScreenshot: true), theme: .clutterCatacombs))
        #expect(!DungeonThemeEngine.isThemed(makeItem(id: "b"), theme: .dragonsHoard))
        #expect(DungeonTheme.wildGallery.emphasizedFamily == nil)
    }

    // MARK: - Encounter stats

    @Test func sightingStatsAggregateFromSpareAndDeleteLogs() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MonsterSightingRecord.self, SparedMediaRecord.self, DeletedMediaRecord.self,
            configurations: configuration
        )
        let context = ModelContext(container)

        let item = makeItem(id: "stat1")
        BestiaryService.recordEncounters(for: [item, item], context: context)
        context.insert(SparedMediaRecord(assetIdentifier: "sp1", monsterType: .blurBeast))
        context.insert(DeletedMediaRecord(assetIdentifier: "del1", mediaKind: .photo, monsterType: .blurBeast, fileSizeBytes: 1_048_576))
        try context.save()

        let stats = BestiaryService.stats(for: .blurBeast, context: context)
        #expect(stats.encountered == 2)
        #expect(stats.spared == 1)
        #expect(stats.slain == 1)
        #expect(stats.bytesReclaimed == 1_048_576)
        #expect(stats.isDiscovered)

        let untouched = BestiaryService.stats(for: .gigabyteGorgon, context: context)
        #expect(!untouched.isDiscovered)
    }

    // MARK: - dHash

    @Test func dHashIsDeterministicForIdenticalImages() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        let image = renderer.image { ctx in
            UIColor.gray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 32, height: 64))
        }
        let h1 = MediaFingerprinter.dHash(image: image)
        let h2 = MediaFingerprinter.dHash(image: image)
        #expect(h1 != nil)
        #expect(h1 == h2)
    }
}

private extension MediaFingerprint {
    /// Rebuilds the fingerprint with a shifted creation date (burst testing).
    func withCreationOffset(_ offset: TimeInterval) -> MediaFingerprint {
        MediaFingerprint(
            assetID: assetID, byteSize: byteSize,
            pixelWidth: pixelWidth, pixelHeight: pixelHeight,
            durationSeconds: durationSeconds,
            creationDate: creationDate.map { $0.addingTimeInterval(offset) },
            isFavorite: isFavorite, isScreenshot: isScreenshot,
            hasEdits: hasEdits, isScreenRecording: isScreenRecording,
            dHash: dHash, sharpness: sharpness, contentHash: contentHash
        )
    }
}

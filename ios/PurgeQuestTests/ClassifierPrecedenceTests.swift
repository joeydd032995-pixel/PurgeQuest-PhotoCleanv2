//
//  ClassifierPrecedenceTests.swift
//  PurgeQuestTests
//
//  What the classifier says when more than one rule could fire, and the promises it keeps for every
//  input: a defect is not hidden behind the photo's age, anything fragile is flagged for careful
//  review, and the verdict never depends on the order of the batch.
//
//  Foundation only, so this runs in Xcode and in the Linux harness.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct ClassifierPrecedenceTests {

    private static let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private static let day: TimeInterval = 86_400
    private static let longAgo = now.addingTimeInterval(-6 * 365 * day)
    private static let lastMonth = now.addingTimeInterval(-30 * day)

    private func photo(
        capturedAt: Date? = ClassifierPrecedenceTests.lastMonth, width: Int = 4000, height: Int = 3000,
        bytes: Int64 = 2_000_000, sharpness: Double? = 60, luminance: Double? = 0.5, highlight: Double? = nil,
        screenshot: Bool = false, livePhoto: Bool = false, panorama: Bool = false,
        vision: VisionTextSignals? = nil, loadFailed: Bool = false
    ) -> MediaItem {
        var item = MediaItem(
            id: "p", kind: .photo, creationDate: capturedAt, pixelWidth: width, pixelHeight: height,
            durationSeconds: 0, estimatedBytes: bytes, isFavorite: false, playbackStyle: 1,
            isScreenshot: screenshot, isLivePhoto: livePhoto, isPanorama: panorama,
            sharpness: sharpness, luminance: luminance, highlightLuminance: highlight
        )
        item.visionSignals = vision
        item.loadFailed = loadFailed
        return item
    }

    private func clip(
        duration: Double = 30, bytes: Int64 = 20_000_000, width: Int = 1920, height: Int = 1080,
        screenRecording: Bool = false, looping: Bool = false, slowMotion: Bool = false, timelapse: Bool = false,
        luminances: [Double]? = nil, luminance: Double? = 0.5, loadFailed: Bool = false
    ) -> MediaItem {
        var item = MediaItem(
            id: "c", kind: .video, creationDate: ClassifierPrecedenceTests.lastMonth, pixelWidth: width, pixelHeight: height,
            durationSeconds: duration, estimatedBytes: bytes, isFavorite: false, playbackStyle: 4,
            isScreenRecording: screenRecording, isLooping: looping, isHighFrameRate: slowMotion,
            isTimelapse: timelapse, luminance: luminance
        )
        if let luminances { item.frameSignals = VideoFrameSignals.evaluate(luminances: luminances) }
        item.loadFailed = loadFailed
        return item
    }

    private func verdict(_ item: MediaItem) -> MonsterClassification {
        MonsterClassifier.classifySolo(item, now: Self.now)
    }

    // MARK: - A defect is not hidden behind age

    @Test func anOldBlurryPhotoIsABlurBeastThatSaysItIsOld() {
        let v = verdict(photo(capturedAt: Self.longAgo, sharpness: 20))
        #expect(v.monsterType == .blurBeast)
        #expect(v.reasons == [.outOfFocus, .oldCapture])
        #expect(v.whyText == "Looks out of focus · Captured years ago")
        // Old photos are always reviewed carefully, whatever else is true of them.
        #expect(v.requiresCarefulReview)
    }

    @Test func anOldDarkFrameAndAnOldDownloadKeepTheirDefectToo() {
        let dark = verdict(photo(capturedAt: Self.longAgo, luminance: 0.05, highlight: 0.1))
        #expect(dark.monsterType == .darkWraith)
        #expect(dark.reasons == [.darkFrames, .oldCapture])
        #expect(dark.requiresCarefulReview)

        let download = verdict(photo(capturedAt: Self.longAgo, width: 1_080, height: 1_920))
        #expect(download.monsterType == .lowQualityLich)
        #expect(download.reasons == [.lowQuality, .oldCapture])
        #expect(download.requiresCarefulReview)
    }

    @Test func theSameDefectsOnARecentPhotoAreNotFlaggedForCarefulReview() {
        let blurry = verdict(photo(sharpness: 20))
        #expect(blurry.monsterType == .blurBeast)
        #expect(blurry.reasons == [.outOfFocus])
        #expect(!blurry.requiresCarefulReview)
        #expect(!verdict(photo(luminance: 0.05, highlight: 0.1)).requiresCarefulReview)
        #expect(!verdict(photo(width: 1_080, height: 1_920)).requiresCarefulReview)
    }

    @Test func anOldPhotoWithNothingWrongIsStillAnAncientArchive() {
        let v = verdict(photo(capturedAt: Self.longAgo))
        #expect(v.monsterType == .ancientArchive)
        #expect(v.reasons == [.oldCapture])
        #expect(v.requiresCarefulReview)
        // A photo nobody could judge for focus (a clear sky) is not a defect either.
        #expect(verdict(photo(capturedAt: Self.longAgo, sharpness: nil)).monsterType == .ancientArchive)
    }

    @Test func theArchiveLineIsThreeFullYears() {
        let calendar = Calendar.current
        let threeYears = calendar.date(byAdding: .year, value: -3, to: Self.now)!
        #expect(MonsterClassifier.isArchiveAge(threeYears, now: Self.now))
        #expect(!MonsterClassifier.isArchiveAge(threeYears.addingTimeInterval(Self.day), now: Self.now))
        #expect(!MonsterClassifier.isArchiveAge(nil, now: Self.now))
        // A capture dated after "now" (a wrong clock) is not ancient.
        #expect(!MonsterClassifier.isArchiveAge(Self.now.addingTimeInterval(400 * Self.day), now: Self.now))
    }

    // MARK: - What a photo is comes before what is wrong with it

    @Test func whatAPhotoIsOutranksAMeasuredDefect() {
        // Each of these is also blurry, dark and old; the more specific fact still names it.
        func cluttered(_ build: (inout MediaItem) -> Void, screenshot: Bool = false, livePhoto: Bool = false,
                       panorama: Bool = false, width: Int = 4000, height: Int = 3000) -> MonsterType {
            var item = photo(capturedAt: Self.longAgo, width: width, height: height, sharpness: 5,
                             luminance: 0.05, highlight: 0.1, screenshot: screenshot, livePhoto: livePhoto, panorama: panorama)
            build(&item)
            return verdict(item).monsterType
        }
        #expect(cluttered({ _ in }, screenshot: true) == .screenshotSpecter)
        #expect(cluttered({ _ in }, livePhoto: true) == .livePhotoLycan)
        #expect(cluttered({ _ in }, panorama: true) == .panoramaColossus)
        #expect(cluttered({ _ in }, width: 400, height: 300) == .thumbGoblin)
        #expect(cluttered({ $0.visionSignals = VisionTextSignals(characterCount: 400, regionCount: 6, hasBarcode: false) }) == .tomeWraith)
        #expect(cluttered({ $0.visionSignals = VisionTextSignals(characterCount: 0, regionCount: 0, hasBarcode: true) }) == .sigilSpecter)
        #expect(cluttered({ $0.loadFailed = true }) == .nullPortrait)
    }

    @Test func aCodeOutranksEverythingButBrokenMedia() {
        let code = VisionTextSignals(characterCount: 900, regionCount: 12, hasBarcode: true)
        // A screenshot of a ticket, a Live Photo of one, a page of text with a QR code in the corner.
        #expect(verdict(photo(screenshot: true, vision: code)).monsterType == .sigilSpecter)
        #expect(verdict(photo(livePhoto: true, vision: code)).monsterType == .sigilSpecter)
        #expect(verdict(photo(vision: code)).monsterType == .sigilSpecter)
        // Broken media is named first: there is nothing to scan in a file that will not load.
        #expect(verdict(photo(bytes: 0, vision: code)).monsterType == .staticHusk)
        #expect(verdict(photo(vision: code, loadFailed: true)).monsterType == .nullPortrait)
    }

    @Test func betweenDefectsTheOrderIsProportionsThenFocusThenExposure() {
        #expect(verdict(photo(width: 1_080, height: 1_920, sharpness: 5, luminance: 0.05, highlight: 0.1)).monsterType == .lowQualityLich)
        #expect(verdict(photo(sharpness: 5, luminance: 0.05, highlight: 0.1)).monsterType == .blurBeast)
        #expect(verdict(photo(sharpness: 90, luminance: 0.05, highlight: 0.1)).monsterType == .darkWraith)
    }

    // MARK: - Videos

    @Test func sizeOutranksEveryOtherVideoFact() {
        // A screen recording, a time-lapse and a strobing clip are all storage monsters first when huge.
        #expect(verdict(clip(bytes: 1_200_000_000, screenRecording: true)).monsterType == .gigabyteGorgon)
        #expect(verdict(clip(bytes: 600_000_000, timelapse: true)).monsterType == .memoryHogMinotaur)
        #expect(verdict(clip(bytes: 600_000_000, luminances: [0.2, 0.9, 0.15])).monsterType == .memoryHogMinotaur)
    }

    @Test func aBrokenVideoIsNeverCalledAnythingElse() {
        // No duration, whatever the size or flags say.
        let v = verdict(clip(duration: 0, bytes: 1_200_000_000, screenRecording: true, timelapse: true))
        #expect(v.monsterType == .corruptedCodec)
        #expect(v.requiresCarefulReview)
        #expect(verdict(clip(loadFailed: true)).monsterType == .corruptedCodec)
        #expect(verdict(clip(bytes: 0)).monsterType == .staticHusk)
    }

    @Test func theVideoThresholdsSitExactlyWhereTheyAreDocumented() {
        #expect(verdict(clip(bytes: MonsterClassifier.gigabyte)).monsterType == .gigabyteGorgon)
        #expect(verdict(clip(bytes: MonsterClassifier.gigabyte - 1)).monsterType == .memoryHogMinotaur)
        #expect(verdict(clip(bytes: MonsterClassifier.halfGigabyte)).monsterType == .memoryHogMinotaur)
        #expect(verdict(clip(bytes: MonsterClassifier.halfGigabyte - 1)).monsterType == .videoVampire)
        #expect(verdict(clip(bytes: MonsterClassifier.hundredMegabyte)).monsterType == .videoVampire)
        #expect(verdict(clip(bytes: MonsterClassifier.hundredMegabyte - 1)).monsterType == .tatterWraith)

        #expect(verdict(clip(duration: 120)).monsterType != .longTakeLeviathan)
        #expect(verdict(clip(duration: 120.5)).monsterType == .longTakeLeviathan)
        #expect(verdict(clip(width: 3_840, height: 2_160)).monsterType == .fourKKraken)
        #expect(verdict(clip(width: 2_160, height: 3_840)).monsterType == .fourKKraken)   // portrait 4K
        #expect(verdict(clip(width: 3_839, height: 2_160)).monsterType != .fourKKraken)

        #expect(verdict(clip(duration: 1.9)).monsterType == .pocketPoltergeist)
        #expect(verdict(clip(duration: 2)).monsterType == .boringBlooper)
        #expect(verdict(clip(duration: 4.9)).monsterType == .boringBlooper)
        #expect(verdict(clip(duration: 5)).monsterType == .mistWraith)
        #expect(verdict(clip(duration: 19.9)).monsterType == .mistWraith)
        #expect(verdict(clip(duration: 20)).monsterType == .tatterWraith)
        #expect(verdict(clip(duration: 59.9)).monsterType == .tatterWraith)
        #expect(verdict(clip(duration: 60)).monsterType == .voidWraith)
    }

    @Test func aMotionlessClipMustOutliveABlooperToBeAFramedPhantom() {
        let still = [0.5, 0.501, 0.502]
        #expect(verdict(clip(duration: 2.5, luminances: still)).monsterType == .boringBlooper)
        #expect(verdict(clip(duration: 3, luminances: still)).monsterType == .framedPhantom)
    }

    // MARK: - Promises that hold for every input

    /// A grid over every signal the classifier reads. Small enough to run in milliseconds, wide enough
    /// that each rule fires alone and against the others.
    private func everyKindOfItem() -> [MediaItem] {
        var items: [MediaItem] = []
        let dates: [Date?] = [nil, Self.lastMonth, Self.longAgo]
        let codes: [VisionTextSignals?] = [
            nil,
            VisionTextSignals(characterCount: 400, regionCount: 6, hasBarcode: false),
            VisionTextSignals(characterCount: 0, regionCount: 0, hasBarcode: true)
        ]
        for date in dates {
            for (width, height) in [(4000, 3000), (400, 300), (1_080, 1_920), (10_000, 3_000), (0, 0)] {
                for bytes in [Int64(0), 2_000_000] {
                    for sharpness in [Double?.none, 5, 90] {
                        for luminance in [0.05, 0.5] {
                            for flags in 0..<8 {
                                for vision in codes {
                                    items.append(photo(
                                        capturedAt: date, width: width, height: height, bytes: bytes,
                                        sharpness: sharpness, luminance: luminance, highlight: luminance < 0.1 ? 0.1 : nil,
                                        screenshot: flags & 1 != 0, livePhoto: flags & 2 != 0, panorama: flags & 4 != 0,
                                        vision: vision, loadFailed: flags == 7
                                    ))
                                }
                            }
                        }
                    }
                }
            }
        }
        let frames: [[Double]?] = [nil, [0.5, 0.501, 0.502], [0.2, 0.9, 0.15], [0.3, 0.5, 0.35], [0.02, 0.03, 0.02]]
        for duration in [0, 1.2, 3.5, 10, 45, 90, 200] {
            for bytes in [Int64(0), 20_000_000, 150_000_000, 600_000_000, 1_200_000_000] {
                for (width, height) in [(1920, 1080), (3840, 2160)] {
                    for flags in 0..<16 {
                        for luminances in frames {
                            items.append(clip(
                                duration: duration, bytes: bytes, width: width, height: height,
                                screenRecording: flags & 1 != 0, looping: flags & 2 != 0,
                                slowMotion: flags & 4 != 0, timelapse: flags & 8 != 0,
                                luminances: luminances, loadFailed: flags == 15
                            ))
                        }
                    }
                }
            }
        }
        return items
    }

    @Test func everyVerdictHasAReasonAndAnHonestConfidence() {
        for item in everyKindOfItem() {
            let v = verdict(item)
            #expect(!v.reasons.isEmpty)
            #expect(v.confidence > 0 && v.confidence <= 1)
            #expect(v.estimatedBytes == item.estimatedBytes)
            // Only the fallback is a guess, and it says so.
            #expect((v.reasons == [.noStrongSignal]) == (v.confidence < 0.5), "\(v.monsterType) \(v.reasons) at \(v.confidence)")
        }
    }

    @Test func fragileMonstersAreAlwaysFlaggedForCarefulReview() {
        for item in everyKindOfItem() {
            let v = verdict(item)
            if v.monsterType.defaultsToCarefulReview {
                #expect(v.requiresCarefulReview, "\(v.monsterType) summoned without the careful-review flag")
            }
            // An old photo is reviewed carefully under every name it can be given, except the ones
            // that say what it is rather than how it looks (a screenshot stays a screenshot).
            if item.kind == .photo, v.reasons.contains(.oldCapture) {
                #expect(v.requiresCarefulReview, "\(v.monsterType) is old but not flagged")
            }
        }
    }

    @Test func aPhotoIsNeverGivenAVideoMonsterNorAVideoAPhotoMonster() {
        for item in everyKindOfItem() {
            let monster = verdict(item).monsterType
            // The Static Husk is the one monster of both kinds: an empty file is empty either way.
            if monster == .staticHusk { continue }
            #expect(monster.kind == item.kind, "\(item.kind) classified as \(monster)")
        }
    }

    @Test func theVerdictDoesNotDependOnWhereTheItemSitsInTheBatch() {
        // Solo items only: no fingerprints, so nothing clusters.
        let sample = Array(everyKindOfItem().enumerated().filter { $0.offset % 97 == 0 }.map(\.element).prefix(40))
        var items: [MediaItem] = []
        for (index, item) in sample.enumerated() {
            var copy = MediaItem(
                id: "item\(index)", kind: item.kind, creationDate: item.creationDate, pixelWidth: item.pixelWidth,
                pixelHeight: item.pixelHeight, durationSeconds: item.durationSeconds, estimatedBytes: item.estimatedBytes,
                isFavorite: false, playbackStyle: item.playbackStyle,
                isScreenshot: item.isScreenshot, isScreenRecording: item.isScreenRecording, isLivePhoto: item.isLivePhoto,
                isLooping: item.isLooping, isHighFrameRate: item.isHighFrameRate, isTimelapse: item.isTimelapse,
                isPanorama: item.isPanorama, sharpness: item.sharpness, luminance: item.luminance,
                highlightLuminance: item.highlightLuminance
            )
            copy.loadFailed = item.loadFailed
            copy.frameSignals = item.frameSignals
            copy.visionSignals = item.visionSignals
            items.append(copy)
        }
        let forward = MonsterClassifier.classify(items: items, fingerprints: [], now: Self.now).classifications
        let backward = MonsterClassifier.classify(items: items.reversed(), fingerprints: [], now: Self.now).classifications
        #expect(forward.count == items.count)
        #expect(forward == backward)
        for item in items {
            #expect(forward[item.id] == MonsterClassifier.classifySolo(item, now: Self.now))
        }
    }
}

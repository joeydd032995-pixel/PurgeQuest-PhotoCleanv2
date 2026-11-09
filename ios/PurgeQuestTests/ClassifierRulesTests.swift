//
//  ClassifierRulesTests.swift
//  PurgeQuestTests
//
//  The photo-quality decisions as MonsterClassifier applies them: where the blur and dark lines sit,
//  what a tall picture or a busy street scene is called, and which copy a duplicate group suggests
//  keeping. PhotoRules and ThumbnailAnalysis are tested on their own in ThumbnailAnalysisTests; these
//  pin that the classifier actually uses them.
//
//  Foundation only, so they run in Xcode and in a Linux harness that stubs UIKit.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct ClassifierRulesTests {

    /// A lone, undated photo: no archive rule, no duplicate cluster. Everything else is neutral.
    private func photo(
        width: Int = 4000, height: Int = 3000, sharpness: Double? = 60,
        luminance: Double? = 0.5, highlight: Double? = nil, vision: VisionTextSignals? = nil
    ) -> MediaItem {
        var item = MediaItem(
            id: "p", kind: .photo, creationDate: nil, pixelWidth: width, pixelHeight: height,
            durationSeconds: 0, estimatedBytes: 2_000_000, isFavorite: false, playbackStyle: 1,
            isScreenshot: false, isScreenRecording: false, isLivePhoto: false,
            isLooping: false, sharpness: sharpness, luminance: luminance, highlightLuminance: highlight
        )
        item.visionSignals = vision
        return item
    }

    private func clip(luminance: Double?, highlight: Double?) -> MediaItem {
        MediaItem(
            id: "c", kind: .video, creationDate: nil, pixelWidth: 1920, pixelHeight: 1080,
            durationSeconds: 30, estimatedBytes: 20_000_000, isFavorite: false, playbackStyle: 1,
            isScreenshot: false, isScreenRecording: false, isLivePhoto: false,
            isLooping: false, sharpness: nil, luminance: luminance, highlightLuminance: highlight
        )
    }

    private func verdict(_ item: MediaItem) -> MonsterClassification { MonsterClassifier.classifySolo(item) }

    // MARK: - Blur

    @Test func theClassifiersBlurLineIsTheMetricsOwn() {
        #expect(MonsterClassifier.blurSharpness == ThumbnailAnalysis.blurLine)
        #expect(MonsterClassifier.darkLuminance == PhotoRules.darkLuminance)
    }

    @Test func aSoftPhotoIsABlurBeastForBlur() {
        let v = verdict(photo(sharpness: 40))
        #expect(v.monsterType == .blurBeast)
        #expect(v.reasons == [.lowQuality])
    }

    @Test func aPhotoAtTheLineOrAboveIsNotCalledBlurry() {
        #expect(verdict(photo(sharpness: MonsterClassifier.blurSharpness)).reasons == [.noStrongSignal])
        #expect(verdict(photo(sharpness: 90)).reasons == [.noStrongSignal])
    }

    @Test func aPhotoNobodyCouldJudgeIsNotCalledBlurry() {
        // A clear sky or a black frame has no focus score at all; that is not blur.
        #expect(verdict(photo(sharpness: nil)).reasons == [.noStrongSignal])
    }

    // MARK: - Dark

    @Test func aDeadFrameIsADarkWraith() {
        #expect(verdict(photo(luminance: 0.05, highlight: 0.1)).monsterType == .darkWraith)
        // Measured without highlights (older items, fixtures): the mean alone decides, as it always did.
        #expect(verdict(photo(luminance: 0.1, highlight: nil)).monsterType == .darkWraith)
    }

    @Test func aNightSceneWithLightsIsNotADarkWraith() {
        let v = verdict(photo(luminance: 0.08, highlight: 0.9))
        #expect(v.monsterType != .darkWraith)
        #expect(v.reasons == [.noStrongSignal])
    }

    @Test func aClipFromTheSameNightIsNotAPocketPoltergeist() {
        #expect(MonsterClassifier.classifySolo(clip(luminance: 0.05, highlight: 0.1)).monsterType == .pocketPoltergeist)
        #expect(MonsterClassifier.classifySolo(clip(luminance: 0.05, highlight: 0.9)).monsterType != .pocketPoltergeist)
    }

    // MARK: - Tall pictures

    @Test func aStoryFrameIsLowQualityButAPhonesOwnPortraitPhotoIsNot() {
        #expect(verdict(photo(width: 1_080, height: 1_920)).monsterType == .lowQualityLich)
        #expect(verdict(photo(width: 1_000, height: 3_000)).monsterType == .lowQualityLich)
        // 16:9 portrait from the phone's camera (9 MP) and a vertical panorama: as narrow, several times larger.
        #expect(verdict(photo(width: 2_268, height: 4_032)).monsterType != .lowQualityLich)
        #expect(verdict(photo(width: 2_400, height: 8_000)).monsterType != .lowQualityLich)
    }

    // MARK: - Text

    @Test func aStreetOfSignsIsNotADocumentButAReceiptIs() {
        let street = VisionTextSignals(characterCount: 35, regionCount: 9, hasBarcode: false)
        let receipt = VisionTextSignals(characterCount: 90, regionCount: 7, hasBarcode: false)
        let page = VisionTextSignals(characterCount: 420, regionCount: 2, hasBarcode: false)
        #expect(verdict(photo(vision: street)).monsterType != .tomeWraith)
        #expect(verdict(photo(vision: receipt)).monsterType == .tomeWraith)
        #expect(verdict(photo(vision: page)).monsterType == .tomeWraith)
    }

    // MARK: - Hardening

    @Test func aRepeatedIdentifierDoesNotTrapTheClassifier() {
        let a = photo()
        let b = photo(sharpness: 10)
        let fingerprint = MediaFingerprint(
            assetID: "p", byteSize: 2_000_000, pixelWidth: 4000, pixelHeight: 3000, durationSeconds: 0,
            creationDate: nil, isFavorite: false, isScreenshot: false, hasEdits: false, isScreenRecording: false,
            dHash: nil, sharpness: nil, contentHash: nil
        )
        let library = MonsterClassifier.classify(items: [a, b], fingerprints: [fingerprint, fingerprint])
        #expect(library.classifications["p"] != nil)
    }

    // MARK: - Which copy to keep

    private func copy(_ id: String, sharpness: Double?, pixels: Int = 4000, favorite: Bool = false) -> MediaFingerprint {
        MediaFingerprint(
            assetID: id, byteSize: 2_000_000, pixelWidth: pixels, pixelHeight: pixels * 3 / 4, durationSeconds: 0,
            creationDate: nil, isFavorite: favorite, isScreenshot: false, hasEdits: false, isScreenRecording: false,
            dHash: nil, sharpness: sharpness, contentHash: nil
        )
    }

    @Test func theSharperCopyOfTheSameSizeIsTheSuggestedSurvivor() {
        let soft = copy("soft", sharpness: 30)
        let crisp = copy("crisp", sharpness: 80)
        #expect(DuplicateDetectionEngine.recommendedSurvivor(in: [soft, crisp]) == "crisp")
        #expect(DuplicateDetectionEngine.recommendedSurvivor(in: [crisp, soft]) == "crisp")
    }

    @Test func aFavoriteStillOutranksSharpnessAndResolutionStillCounts() {
        let favorite = copy("favorite", sharpness: 20, favorite: true)
        let crisp = copy("crisp", sharpness: 95)
        #expect(DuplicateDetectionEngine.recommendedSurvivor(in: [favorite, crisp]) == "favorite")

        let big = copy("big", sharpness: 60, pixels: 5000)
        let small = copy("small", sharpness: 60, pixels: 2000)
        #expect(DuplicateDetectionEngine.recommendedSurvivor(in: [small, big]) == "big")
    }

    // New tests go above this line.
}

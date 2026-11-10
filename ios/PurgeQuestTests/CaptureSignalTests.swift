//
//  CaptureSignalTests.swift
//  PurgeQuestTests
//
//  The capture facts PhotoLibraryService hands the classifier. A monster is only reachable on a phone
//  if the signal that summons it is one the phone actually produces: the Screen Recording Shade was
//  summoned by a file name iOS never writes, and the Timelapse Phantom never looked at time-lapses.
//
//  Foundation only, so this runs in Xcode and in the Linux harness.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct CaptureSignalTests {

    // MARK: - Screen recordings

    @Test func namesTheSystemGivesItsRecordingsAreRecognised() {
        // ReplayKit, newer iOS, and macOS.
        #expect(CaptureSignalRules.namesAScreenRecording("RPReplay_Final1699999999.MP4"))
        #expect(CaptureSignalRules.namesAScreenRecording("ScreenRecording_11-10-2026 14-00-00_1.MP4"))
        #expect(CaptureSignalRules.namesAScreenRecording("Screen Recording 2026-11-10 at 14.00.00.mov"))
        // Case and punctuation do not matter.
        #expect(CaptureSignalRules.namesAScreenRecording("screen_recording-final.mov"))
        #expect(CaptureSignalRules.namesAScreenRecording("rpreplay_final1.mp4"))
    }

    @Test func ordinaryCameraFilesAreNotRecordings() {
        for name in ["IMG_0042.MOV", "IMG_E0042.MP4", "trim.5F2A9C1B.MOV", "Screenshot 2026-11-10.png",
                     "screen.mov", "recording.m4v", "my-replay.mp4", ""] {
            #expect(!CaptureSignalRules.namesAScreenRecording(name), "\(name) is not a screen recording")
        }
    }

    @Test func theOldRuleMissedEveryNameIOSWrites() {
        // What the app used to do: look for the words with a space between them. Kept here so the
        // reason for the rule stays visible; only the macOS name ever matched.
        func oldRule(_ name: String) -> Bool { name.lowercased().contains("screen recording") }
        #expect(!oldRule("RPReplay_Final1699999999.MP4"))
        #expect(!oldRule("ScreenRecording_11-10-2026 14-00-00_1.MP4"))
        #expect(oldRule("Screen Recording 2026-11-10 at 14.00.00.mov"))
    }

    @Test func thePhotosFlagAloneIsEnoughAndSoIsTheNameAlone() {
        #expect(CaptureSignalRules.isScreenRecording(flagged: true, filenames: ["IMG_0042.MOV"]))
        #expect(CaptureSignalRules.isScreenRecording(flagged: true, filenames: []))
        #expect(CaptureSignalRules.isScreenRecording(flagged: false, filenames: ["IMG_0042.MOV", "RPReplay_Final1.MP4"]))
        #expect(!CaptureSignalRules.isScreenRecording(flagged: false, filenames: ["IMG_0042.MOV"]))
        #expect(!CaptureSignalRules.isScreenRecording(flagged: false, filenames: []))
    }

    // MARK: - Every capture fact reaches the classifier

    private func clip(_ signals: CaptureSignals) -> MediaItem {
        MediaItem(
            id: "clip", kind: .video, creationDate: nil, pixelWidth: 1920, pixelHeight: 1080,
            durationSeconds: 30, estimatedBytes: 20_000_000, isFavorite: false, playbackStyle: 4,
            isScreenshot: signals.isScreenshot, hasEdits: signals.hasEdits,
            isScreenRecording: signals.isScreenRecording, isLivePhoto: signals.isLivePhoto,
            isLooping: signals.isLooping, isHighFrameRate: signals.isHighFrameRate,
            isTimelapse: signals.isTimelapse, isPanorama: signals.isPanorama
        )
    }

    private func photo(_ signals: CaptureSignals, width: Int = 4000, height: Int = 3000) -> MediaItem {
        MediaItem(
            id: "photo", kind: .photo, creationDate: nil, pixelWidth: width, pixelHeight: height,
            durationSeconds: 0, estimatedBytes: 2_000_000, isFavorite: false, playbackStyle: 1,
            isScreenshot: signals.isScreenshot, hasEdits: signals.hasEdits,
            isScreenRecording: signals.isScreenRecording, isLivePhoto: signals.isLivePhoto,
            isLooping: signals.isLooping, isHighFrameRate: signals.isHighFrameRate,
            isTimelapse: signals.isTimelapse, isPanorama: signals.isPanorama,
            sharpness: 60, luminance: 0.5
        )
    }

    @Test func aRecordingNamedTheWayIOSNamesItSummonsTheShade() {
        var signals = CaptureSignals()
        signals.isScreenRecording = CaptureSignalRules.isScreenRecording(
            flagged: false, filenames: ["ScreenRecording_11-10-2026 14-00-00_1.MP4"])
        let verdict = MonsterClassifier.classifySolo(clip(signals))
        #expect(verdict.monsterType == .screenRecordingShade)
        #expect(verdict.reasons == [.screenRecording])
    }

    @Test func aTimeLapseSummonsTheTimelapsePhantomAndSaysSo() {
        var signals = CaptureSignals()
        signals.isTimelapse = true
        let verdict = MonsterClassifier.classifySolo(clip(signals))
        #expect(verdict.monsterType == .timelapsePhantom)
        #expect(verdict.reasons == [.timelapse])
        #expect(verdict.whyText == "A time-lapse capture")
    }

    @Test func slowMotionAndLoopsStillSummonItEachWithItsOwnReason() {
        var slow = CaptureSignals()
        slow.isHighFrameRate = true
        #expect(MonsterClassifier.classifySolo(clip(slow)).monsterType == .timelapsePhantom)
        #expect(MonsterClassifier.classifySolo(clip(slow)).reasons == [.highFrameRate])

        var loop = CaptureSignals()
        loop.isLooping = true
        #expect(MonsterClassifier.classifySolo(clip(loop)).monsterType == .timelapsePhantom)
        #expect(MonsterClassifier.classifySolo(clip(loop)).reasons == [.loopVideo])

        // An ordinary clip with none of the three is not one.
        #expect(MonsterClassifier.classifySolo(clip(CaptureSignals())).monsterType != .timelapsePhantom)
    }

    @Test func aVerticalPanoramaIsAColossusByPhotosOwnFlag() {
        var signals = CaptureSignals()
        signals.isPanorama = true
        // A vertical sweep: taller than wide, so the width rule alone never saw it.
        let vertical = MonsterClassifier.classifySolo(photo(signals, width: 3_000, height: 11_000))
        #expect(vertical.monsterType == .panoramaColossus)
        #expect(vertical.reasons == [.panoramaCapture])
        #expect(MonsterClassifier.classifySolo(photo(CaptureSignals(), width: 3_000, height: 11_000)).monsterType != .panoramaColossus)

        // A wide frame without the flag (a stitched import) still is one, for its shape.
        let wide = MonsterClassifier.classifySolo(photo(CaptureSignals(), width: 10_000, height: 3_000))
        #expect(wide.monsterType == .panoramaColossus)
        #expect(wide.reasons == [.extremeAspect])
    }

    @Test func noReasonSharesItsSentenceWithAnother() {
        // Each reason is a different fact; two that read the same would hide which one fired. The two
        // "could not be fully loaded" reasons are the one deliberate pair.
        var seen: [String: ClassificationReason] = [:]
        for reason in ClassificationReason.allCases {
            if let twin = seen[reason.factText] {
                #expect(Set([reason, twin]) == [.brokenMetadata, .renderFailed], "\(reason) and \(twin) read the same")
            }
            seen[reason.factText] = reason
        }
    }
}

//
//  VideoFrameSignalTests.swift
//  PurgeQuestTests
//
//  What three sampled frames say about a clip. "Motionless" must mean the picture holds still, not
//  that it stays equally bright: a pan across an evenly lit room keeps its average brightness and was
//  being called a slideshow, which kept ordinary clips from ever reaching the Video Vampire, the
//  Boring Blooper and the Wraiths.
//
//  Foundation only, so this runs in Xcode and in the Linux harness.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct VideoFrameSignalTests {

    private static let side = 16

    /// Vertical stripes, `phase` cells along. Every phase has the same average brightness.
    private func stripes(phase: Int, low: Double = 0.2, high: Double = 0.8) -> [Double] {
        var grid = [Double](repeating: 0, count: Self.side * Self.side)
        for y in 0..<Self.side {
            for x in 0..<Self.side {
                grid[y * Self.side + x] = ((x + phase) / 4) % 2 == 0 ? low : high
            }
        }
        return grid
    }

    private func flat(_ value: Double) -> [Double] {
        [Double](repeating: value, count: Self.side * Self.side)
    }

    private func clip(frames: [[Double]], duration: Double = 30, bytes: Int64 = 20_000_000) -> MediaItem {
        var item = MediaItem(
            id: "clip", kind: .video, creationDate: nil, pixelWidth: 1920, pixelHeight: 1080,
            durationSeconds: duration, estimatedBytes: bytes, isFavorite: false, playbackStyle: 4,
            luminance: 0.5
        )
        item.frameSignals = VideoFrameSignals.evaluate(frames: frames)
        return item
    }

    // MARK: - Stillness is about the picture

    @Test func theSameFrameThreeTimesIsMotionless() throws {
        let still = try #require(VideoFrameSignals.evaluate(frames: [stripes(phase: 0), stripes(phase: 0), stripes(phase: 0)]))
        #expect(still.meanFrameDifference == 0)
        #expect(still.isStatic)
    }

    @Test func aPictureThatMovesButStaysAsBrightIsNotMotionless() throws {
        // The stripes slide sideways: every frame is half dark and half light, so the averages agree
        // to the last digit while half the picture changes.
        let frames = [stripes(phase: 0), stripes(phase: 4), stripes(phase: 0)]
        let moving = try #require(VideoFrameSignals.evaluate(frames: frames))
        #expect(moving.meanMotion < 1e-9)
        #expect(moving.meanFrameDifference > 0.5)
        #expect(!moving.isStatic)

        // Judged by brightness alone, as it used to be, the same clip reads as a slideshow.
        let means = frames.map { $0.reduce(0, +) / Double($0.count) }
        let byBrightness = try #require(VideoFrameSignals.evaluate(luminances: means))
        #expect(byBrightness.isStatic)
    }

    @Test func aSmallMovementInOneCornerStaysUnderTheLine() throws {
        // A tripod shot where only a few cells change a little: still a framed, motionless clip.
        var second = stripes(phase: 0)
        for cell in 0..<8 { second[cell] += 0.1 }
        let signals = try #require(VideoFrameSignals.evaluate(frames: [stripes(phase: 0), second, stripes(phase: 0)]))
        #expect(signals.meanFrameDifference > 0)
        #expect(signals.meanFrameDifference <= VideoFrameSignals.staticMotionThreshold)
        #expect(signals.isStatic)
    }

    @Test func comparingFramesNeverCallsMoreClipsMotionlessThanComparingBrightnessDid() throws {
        // The frame difference is at least the difference of the averages, so with one threshold the
        // new rule's motionless clips are a subset of the old rule's.
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        func next() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 11) / Double(1 << 53)
        }
        var stillByFrames = 0
        var stillByBrightness = 0
        for trial in 0..<400 {
            let base = (0..<Self.side * Self.side).map { _ in next() }
            // Mostly small perturbations, so both rules have clips on each side of the line.
            let wobble = trial % 4 == 0 ? 0.5 : 0.02
            let frames = (0..<3).map { _ in base.map { min(1, max(0, $0 + (next() - 0.5) * wobble)) } }
            let byFrames = try #require(VideoFrameSignals.evaluate(frames: frames))
            let byBrightness = try #require(VideoFrameSignals.evaluate(luminances: frames.map { $0.reduce(0, +) / Double($0.count) }))
            #expect(byFrames.meanFrameDifference >= byFrames.meanMotion - 1e-12)
            if byFrames.isStatic {
                stillByFrames += 1
                #expect(byBrightness.isStatic, "frames call it motionless but brightness did not")
            }
            if byBrightness.isStatic { stillByBrightness += 1 }
        }
        #expect(stillByFrames > 0, "the trials never produced a motionless clip, so the comparison proved nothing")
        #expect(stillByFrames < stillByBrightness, "the trials never separated the two rules")
    }

    // MARK: - Brightness signals are unchanged

    @Test func brightnessSignalsAreTheSameWhicheverWayTheFramesArrive() throws {
        let frames = [flat(0.2), flat(0.9), flat(0.15)]
        let fromFrames = try #require(VideoFrameSignals.evaluate(frames: frames))
        let fromMeans = try #require(VideoFrameSignals.evaluate(luminances: [0.2, 0.9, 0.15]))
        #expect(abs(fromFrames.averageLuminance - fromMeans.averageLuminance) < 1e-12)
        #expect(abs(fromFrames.meanMotion - fromMeans.meanMotion) < 1e-12)
        #expect(abs(fromFrames.maxLuminanceSwing - fromMeans.maxLuminanceSwing) < 1e-12)
        #expect(fromFrames.darkFrameCount == fromMeans.darkFrameCount)
        #expect(fromFrames.isFlickering && fromMeans.isFlickering)
        // For flat frames the two measures of change coincide.
        #expect(abs(fromFrames.meanFrameDifference - fromFrames.meanMotion) < 1e-12)
    }

    @Test func framesOfTheWrongSizeOrWithBadValuesAreLeftOut() throws {
        #expect(VideoFrameSignals.evaluate(frames: []) == nil)
        #expect(VideoFrameSignals.evaluate(frames: [[]]) == nil)
        var broken = flat(0.5)
        broken[3] = .nan
        let signals = try #require(VideoFrameSignals.evaluate(frames: [flat(0.5), [0.1, 0.2], broken, flat(0.5)]))
        #expect(signals.frameCount == 2)
        #expect(signals.isStatic)
        // One usable frame says nothing about movement.
        let single = try #require(VideoFrameSignals.evaluate(frames: [flat(0.5)]))
        #expect(!single.isStatic)
    }

    // MARK: - What the classifier now calls a steady, moving clip

    @Test func aSteadyClipThatMovesReachesTheRulesBelowTheFramedPhantom() {
        let moving = [stripes(phase: 0), stripes(phase: 4), stripes(phase: 0)]
        #expect(MonsterClassifier.classifySolo(clip(frames: moving)).monsterType == .tatterWraith)
        #expect(MonsterClassifier.classifySolo(clip(frames: moving, duration: 10)).monsterType == .mistWraith)
        #expect(MonsterClassifier.classifySolo(clip(frames: moving, duration: 3.5)).monsterType == .boringBlooper)
        #expect(MonsterClassifier.classifySolo(clip(frames: moving, bytes: 150_000_000)).monsterType == .videoVampire)
    }

    @Test func aClipWhoseFramesReallyHoldStillIsStillAFramedPhantom() {
        let still = [stripes(phase: 0), stripes(phase: 0), stripes(phase: 0)]
        let verdict = MonsterClassifier.classifySolo(clip(frames: still))
        #expect(verdict.monsterType == .framedPhantom)
        #expect(verdict.reasons == [.staticFrames])
        // Even a large one: a slideshow is named for what it is before its size.
        #expect(MonsterClassifier.classifySolo(clip(frames: still, bytes: 150_000_000)).monsterType == .framedPhantom)
    }
}

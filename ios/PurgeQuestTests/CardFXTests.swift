import Testing
import Foundation
@testable import PurgeQuest

@Suite struct CardFXTests {

    private func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool { abs(a - b) < tolerance }

    // MARK: Gate

    @Test func reduceMotionOrLowPowerMakesEveryEffectAStill() {
        #expect(FXGate(reduceMotion: false, lowPowerMode: false) == .live)
        #expect(FXGate(reduceMotion: true, lowPowerMode: false) == .still)
        #expect(FXGate(reduceMotion: false, lowPowerMode: true) == .still)
        #expect(FXGate(reduceMotion: true, lowPowerMode: true) == .still)
        #expect(FXGate.still.isStill)
        #expect(!FXGate.live.isStill)
    }

    // MARK: Light

    @Test func theLightDirectionIsAUnitVectorLeaningRight() {
        let d = LightSource.direction
        #expect(close(d.x * d.x + d.y * d.y, 1))
        #expect(d.x > 0, "the torch is left of centre, so light travels right")
        #expect(d.y > 0.9, "and mostly down")
    }

    @Test func aShadowOffsetFollowsTheLightAndScalesWithDepth() {
        let shallow = LightSource.shadowOffset(depth: 2)
        let deep = LightSource.shadowOffset(depth: 10)
        #expect(close(deep.x, shallow.x * 5))
        #expect(close(deep.y, shallow.y * 5))
        #expect(deep.x > 0 && deep.y > deep.x)
        let none = LightSource.shadowOffset(depth: 0)
        #expect(none.x == 0 && none.y == 0)
    }

    @Test func theHighlightRunsFromTheLitSideAndSwingsWithTheShift() {
        let rest = LightSource.highlightPoints()
        #expect(rest.start.y < rest.end.y, "from the top, where the torch is")
        #expect(rest.start.x < rest.end.x)
        #expect(close((rest.start.x + rest.end.x) / 2, 0.5) && close((rest.start.y + rest.end.y) / 2, 0.5))
        let swung = LightSource.highlightPoints(shiftDegrees: 20)
        #expect(swung.start.x < rest.start.x, "a positive shift swings the light's start point left and down")
        #expect(swung.start.y > rest.start.y)
    }

    // MARK: Progress and arming

    @Test func progressIsSignedAndClamped() {
        #expect(close(SwipeProgress(dx: -55, dy: 0, gate: .live).signed, -0.5))
        #expect(close(SwipeProgress(dx: 55, dy: 0, gate: .live).signed, 0.5))
        #expect(SwipeProgress(dx: -900, dy: 0, gate: .live).signed == -1)
        #expect(SwipeProgress(dx: 900, dy: 0, gate: .live).signed == 1)
        #expect(close(SwipeProgress(dx: -55, dy: 0, gate: .live).strength, 0.5))
        #expect(SwipeProgress(dx: -10, dy: 0, gate: .live).side == .delete)
        #expect(SwipeProgress(dx: 10, dy: 0, gate: .live).side == .keep)
    }

    @Test func noDragIsNotArmed() {
        let p = SwipeProgress(dx: 0, dy: 0, gate: .live)
        #expect(p.armed == nil)
        #expect(p.side == nil)
        #expect(p.signed == 0)
    }

    @Test func armsAtTheThresholdAndHoldsDownToNinetyPercent() {
        var p = SwipeProgress(dx: -109, dy: 0, gate: .live)
        #expect(p.armed == nil, "109 of 110 is not there yet")
        p = SwipeProgress(dx: -110, dy: 0, gate: .live, wasArmed: p.armed)
        #expect(p.armed == .delete, "arms exactly at the threshold")
        p = SwipeProgress(dx: -100, dy: 0, gate: .live, wasArmed: p.armed)
        #expect(p.armed == .delete, "91% still holds")
        p = SwipeProgress(dx: -98, dy: 0, gate: .live, wasArmed: p.armed)
        #expect(p.armed == nil, "89% lets go")
        p = SwipeProgress(dx: -100, dy: 0, gate: .live, wasArmed: p.armed)
        #expect(p.armed == nil, "and 91% does not arm again from nothing")
    }

    @Test func aWobbleAroundTheThresholdArmsOnce() {
        var armedCount = 0
        var wasArmed: SwipeProgress.Side? = nil
        for dx in [-111.0, -109.0, -111.0, -108.0, -112.0, -107.0] {
            let p = SwipeProgress(dx: dx, dy: 0, gate: .live, wasArmed: wasArmed)
            if p.armed != nil && wasArmed == nil { armedCount += 1 }
            wasArmed = p.armed
        }
        #expect(armedCount == 1, "one detent, not six")
    }

    @Test func crossingToTheOtherSideNeedsTheFullThreshold() {
        let p = SwipeProgress(dx: 100, dy: 0, gate: .live, wasArmed: .delete)
        #expect(p.armed == nil, "armed for delete does not carry over to keep at 91%")
        let q = SwipeProgress(dx: 110, dy: 0, gate: .live, wasArmed: .delete)
        #expect(q.armed == .keep)
    }

    // MARK: Tilt

    @Test func tiltFollowsTheDragAndIsClamped() {
        #expect(close(SwipeProgress(dx: 55, dy: 0, gate: .live).tiltY, 10.0 / 3))
        #expect(SwipeProgress(dx: 165, dy: 0, gate: .live).tiltY == 10)
        #expect(SwipeProgress(dx: 5000, dy: 0, gate: .live).tiltY == 10)
        #expect(SwipeProgress(dx: -5000, dy: 0, gate: .live).tiltY == -10)
        #expect(SwipeProgress(dx: 0, dy: 220, gate: .live).tiltX == -8)
        #expect(SwipeProgress(dx: 0, dy: -220, gate: .live).tiltX == 8)
        #expect(close(SwipeProgress(dx: 165, dy: 0, gate: .live).highlightShift, 20), "the light swings 20 degrees at full tilt")
    }

    @Test func tiltIsOffUnderTheGate() {
        let p = SwipeProgress(dx: 165, dy: 220, gate: .still)
        #expect(p.tiltY == 0)
        #expect(p.tiltX == 0)
        #expect(p.highlightShift == 0)
    }

    @Test func liftGrowsWithDistanceAndSurvivesTheGate() {
        #expect(SwipeProgress(dx: 0, dy: 0, gate: .live).lift == 0)
        #expect(close(SwipeProgress(dx: 30, dy: 40, gate: .live).lift, 50.0 / 60))
        #expect(SwipeProgress(dx: 600, dy: 0, gate: .live).lift == 1)
        #expect(close(SwipeProgress(dx: 30, dy: 40, gate: .still).lift, 50.0 / 60), "never remove the sense of lift")
    }

    // MARK: Pull

    @Test func pullIsDeleteOnlyAndStartsPastTheThreshold() {
        #expect(SwipeProgress(dx: -110, dy: 0, gate: .live).pull == 0, "nothing at the line itself")
        #expect(close(SwipeProgress(dx: -120, dy: 0, gate: .live).pull, -2.5), "a quarter of the 10 pt beyond")
        #expect(SwipeProgress(dx: -400, dy: 0, gate: .live).pull == -24, "capped at 24 pt")
        #expect(SwipeProgress(dx: 200, dy: 0, gate: .live).pull == 0, "keep has no pull: the barrier holds the card")
    }

    @Test func pullIsOffUnderTheGate() {
        #expect(SwipeProgress(dx: -400, dy: 0, gate: .still).pull == 0)
    }

    // MARK: Edge overlays

    @Test func edgeOverlaysNeverExceedTheirLimits() {
        for step in 0...20 {
            let s = Double(step) / 20
            for armed in [false, true] {
                #expect(EdgeOverlay.tearWidth(strength: s, armed: armed) <= 0.34 + 1e-12)
                #expect(EdgeOverlay.barrierWidth(strength: s, armed: armed) <= 0.24 + 1e-12)
            }
            #expect(EdgeOverlay.tearAlpha(strength: s) <= 0.55 + 1e-12)
            #expect(EdgeOverlay.barrierAlpha(strength: s) <= 0.5 + 1e-12)
        }
        #expect(EdgeOverlay.tearWidth(strength: 7, armed: true) <= 0.34 + 1e-12, "out-of-range strength is clamped")
        #expect(EdgeOverlay.tearAlpha(strength: -3) == 0)
    }

    @Test func armingWidensTheTearAndTheBarrier() {
        #expect(EdgeOverlay.tearWidth(strength: 1, armed: true) > EdgeOverlay.tearWidth(strength: 1, armed: false))
        #expect(EdgeOverlay.barrierWidth(strength: 1, armed: true) > EdgeOverlay.barrierWidth(strength: 1, armed: false))
        #expect(close(EdgeOverlay.tearWidth(strength: 1, armed: true), 0.34))
        #expect(close(EdgeOverlay.barrierWidth(strength: 1, armed: true), 0.24))
    }

    @Test func nothingShowsWithoutADrag() {
        #expect(EdgeOverlay.tearWidth(strength: 0, armed: false) == 0)
        #expect(EdgeOverlay.barrierWidth(strength: 0, armed: false) == 0)
        #expect(EdgeOverlay.tearAlpha(strength: 0) == 0)
        #expect(EdgeOverlay.barrierAlpha(strength: 0) == 0)
    }

    // MARK: Edge signal (what the screen-edge overlays are told)

    @Test func theScreenEdgesAreSilentAtRest() {
        let rest = EdgeSignal(progress: SwipeProgress(dx: 0, dy: 0, gate: .live))
        #expect(rest == EdgeSignal.rest)
        #expect(rest.tearStrength == 0 && rest.barrierStrength == 0)
        #expect(!rest.tearArmed && !rest.barrierArmed)
    }

    @Test func aDeleteDragOnlyFeedsTheTearAndAKeepDragOnlyTheBarrier() {
        let deleting = EdgeSignal(progress: SwipeProgress(dx: -55, dy: 12, gate: .live))
        #expect(close(deleting.tearStrength, 0.5))
        #expect(deleting.barrierStrength == 0)
        #expect(!deleting.tearArmed && !deleting.barrierArmed)
        let keeping = EdgeSignal(progress: SwipeProgress(dx: 55, dy: -12, gate: .live))
        #expect(close(keeping.barrierStrength, 0.5))
        #expect(keeping.tearStrength == 0)
        #expect(!keeping.tearArmed && !keeping.barrierArmed)
    }

    @Test func theEdgeThatMatchesTheDragArmsAtTheLine() {
        let delete = EdgeSignal(progress: SwipeProgress(dx: -125, dy: 0, gate: .live))
        #expect(delete.tearArmed && !delete.barrierArmed)
        #expect(delete.tearStrength == 1 && delete.barrierStrength == 0)
        let keep = EdgeSignal(progress: SwipeProgress(dx: 125, dy: 0, gate: .live))
        #expect(keep.barrierArmed && !keep.tearArmed)
        #expect(keep.barrierStrength == 1 && keep.tearStrength == 0)
    }
}

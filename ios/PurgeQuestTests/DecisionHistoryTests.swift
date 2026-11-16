//
//  DecisionHistoryTests.swift
//  PurgeQuestTests
//
//  The rule behind Undo: one step, for five seconds, and a snapshot of what the decision overwrote. Pure and
//  Foundation only, so the Linux harness checks it with an injected clock (tools/swift_harness/run.sh).
//

import Testing
import Foundation
@testable import PurgeQuest

struct DecisionHistoryTests {

    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func snapshot(combo: Int = 3, tenths: Int = 13, perfect: Bool = true) -> DecisionSnapshot {
        DecisionSnapshot(combo: combo, peakCombo: 5, multiplierTenths: tenths, perfectRoom: perfect, heroHighestCombo: 9)
    }

    private func entry(_ kind: DecisionHistory.Kind = .delete, ids: [String] = ["a"], at: Date? = nil,
                       before: DecisionSnapshot? = nil, kept: [String] = []) -> DecisionHistory.Entry {
        DecisionHistory.Entry(kind: kind, itemIDs: ids, before: before ?? snapshot(), keptRecordIDs: kept, recordedAt: at ?? start)
    }

    // MARK: The window

    @Test func theWindowIsFiveSeconds() {
        #expect(DiveRules.undoWindowSeconds == 5)
    }

    @Test func nothingRecordedMeansNothingToUndo() {
        var history = DecisionHistory()
        #expect(!history.canUndo(now: start))
        #expect(history.undoLast(now: start) == nil)
    }

    @Test func theLastDecisionCanBeUndoneInsideTheWindow() {
        var history = DecisionHistory()
        history.record(entry())
        let now = start.addingTimeInterval(2)
        #expect(history.canUndo(now: now))
        #expect(history.undoLast(now: now)?.itemIDs == ["a"])
    }

    @Test func exactlyAtTheWindowIsStillUndoable() {
        var history = DecisionHistory()
        history.record(entry())
        #expect(history.canUndo(now: start.addingTimeInterval(DiveRules.undoWindowSeconds)))
    }

    @Test func oneTickAfterTheWindowIsNotUndoable() {
        var history = DecisionHistory()
        history.record(entry())
        let late = start.addingTimeInterval(DiveRules.undoWindowSeconds + 0.001)
        #expect(!history.canUndo(now: late))
        #expect(history.undoLast(now: late) == nil)
    }

    // MARK: One step only

    @Test func anUndoneDecisionCannotBeUndoneTwice() {
        var history = DecisionHistory()
        history.record(entry())
        #expect(history.undoLast(now: start) != nil)
        #expect(history.undoLast(now: start) == nil)
        #expect(!history.canUndo(now: start))
    }

    @Test func aNewDecisionReplacesWhatCouldBeUndone() {
        var history = DecisionHistory()
        history.record(entry(ids: ["first"]))
        history.record(entry(ids: ["second"], at: start.addingTimeInterval(1)))
        #expect(history.undoLast(now: start.addingTimeInterval(2))?.itemIDs == ["second"])
        // Never two steps back: the first decision is gone.
        #expect(history.undoLast(now: start.addingTimeInterval(2)) == nil)
    }

    @Test func clearingEmptiesItForANewRoom() {
        var history = DecisionHistory()
        history.record(entry())
        history.clear()
        #expect(!history.canUndo(now: start))
    }

    // MARK: What it carries

    /// The multiplier is stored in tenths and rebuilt with `ComboMultiplier(tenths:)`, so a snapshot
    /// restores the exact multiplier whatever the combo formula becomes.
    @Test func aSnapshotRestoresTheExactMultiplier() {
        var multiplier = ComboMultiplier()
        for _ in 0..<7 { multiplier.afterDeletion() }
        let before = snapshot(tenths: multiplier.tenths)
        multiplier.afterKeep()
        #expect(multiplier != ComboMultiplier(tenths: before.multiplierTenths))
        #expect(ComboMultiplier(tenths: before.multiplierTenths).tenths == 17)
    }

    @Test func aKeepRemembersTheSavedRecordsItInserted() {
        var history = DecisionHistory()
        history.record(entry(.keep, ids: ["photo"], kept: ["photo"]))
        let undone = history.undoLast(now: start)
        #expect(undone?.kind == .keep)
        #expect(undone?.keptRecordIDs == ["photo"])
    }

    @Test func aGroupCommitIsOneStepWithEveryCopy() {
        var history = DecisionHistory()
        history.record(entry(.group, ids: ["c1", "c2", "c3"], kept: ["c1"]))
        let undone = history.undoLast(now: start)
        #expect(undone?.kind == .group)
        #expect(undone?.itemIDs == ["c1", "c2", "c3"])
        #expect(undone?.keptRecordIDs == ["c1"])
    }

    @Test func aSnapshotKeepsEverythingTheDecisionOverwrote() {
        var history = DecisionHistory()
        let before = snapshot(combo: 4, tenths: 14, perfect: false)
        history.record(entry(before: before))
        let undone = history.undoLast(now: start)
        #expect(undone?.before == before)
        #expect(undone?.before.combo == 4)
        #expect(undone?.before.perfectRoom == false)
        #expect(undone?.before.heroHighestCombo == 9)
    }
}

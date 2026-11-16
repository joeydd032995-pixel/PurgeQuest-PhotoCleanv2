//
//  UndoDecisionTests.swift
//  PurgeQuestTests
//
//  Sub-plan 1.2, Task 2: undoing a decision puts back everything it changed, including the saved "kept"
//  record a keep inserts, and refuses once it should (window passed, a second step, the Room Summary).
//  These drive CombatViewModel (SwiftData), so they run in Xcode and CI only; DecisionHistoryTests holds
//  the window and one-step rule and runs in the Linux harness.
//

import Testing
import SwiftData
import Foundation
@testable import PurgeQuest

@MainActor
struct UndoDecisionTests {

    private func makeStore() throws -> (container: ModelContainer, context: ModelContext) {
        let schema = Schema([
            Hero.self, Achievement.self, CosmeticItem.self, Quest.self, DeletedMediaRecord.self,
            CombatSession.self, SparedMediaRecord.self, MediaFingerprintRecord.self, MonsterSightingRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return (container, ModelContext(container))
    }

    private func photos(_ count: Int) -> [MediaItem] {
        (0..<count).map { index in
            var item = MediaItem(
                id: "p\(index)", kind: .photo, creationDate: nil, pixelWidth: 4000, pixelHeight: 3000,
                durationSeconds: 0, estimatedBytes: 2_000_000, isFavorite: false, playbackStyle: 1
            )
            item.monsterType = .blurBeast
            return item
        }
    }

    private func start(_ room: [MediaItem], in store: (container: ModelContainer, context: ModelContext)) -> (combat: CombatViewModel, hero: Hero) {
        let hero = Hero()
        store.context.insert(hero)
        let combat = CombatViewModel()
        combat.currentRoomItems = room
        combat.phase = .fighting
        return (combat, hero)
    }

    private func keptRecords(_ context: ModelContext) throws -> [SparedMediaRecord] {
        try context.fetch(FetchDescriptor<SparedMediaRecord>())
    }

    // MARK: Keep

    @Test func keepThenUndoLeavesNoSavedRecordAndTheItemIsBackOnTop() throws {
        let store = try makeStore()
        let room = photos(4)
        let (combat, hero) = start(room, in: store)

        combat.decideSpare(room[0], hero: hero, context: store.context)
        #expect(try keptRecords(store.context).count == 1)
        #expect(combat.topItem?.id == "p1")

        #expect(combat.undoLastDecision(hero: hero, context: store.context))
        #expect(try keptRecords(store.context).isEmpty, "undoing a keep must remove its saved record")
        #expect(combat.topItem?.id == "p0")
        #expect(combat.pendingDecisions.isEmpty)
        withExtendedLifetime(store.container) {}
    }

    @Test func aKeepThatEndedThePerfectRoomGivesItBackOnUndo() throws {
        let store = try makeStore()
        let room = photos(3)
        let (combat, hero) = start(room, in: store)
        #expect(combat.perfectRoom)

        combat.decideSpare(room[0], hero: hero, context: store.context)
        #expect(!combat.perfectRoom)
        #expect(combat.undoLastDecision(hero: hero, context: store.context))
        #expect(combat.perfectRoom)
        withExtendedLifetime(store.container) {}
    }

    @Test func undoingAKeepRestoresTheStreakAndTheMultiplier() throws {
        let store = try makeStore()
        let room = photos(6)
        let (combat, hero) = start(room, in: store)
        for item in room.prefix(3) { combat.decideDelete(item, hero: hero) }
        let comboBefore = combat.combo
        let multiplierBefore = combat.comboMultiplier

        combat.decideSpare(room[3], hero: hero, context: store.context)
        #expect(combat.combo == 0)
        #expect(combat.comboMultiplier != multiplierBefore)

        #expect(combat.undoLastDecision(hero: hero, context: store.context))
        #expect(combat.combo == comboBefore)
        #expect(combat.comboMultiplier == multiplierBefore)
        withExtendedLifetime(store.container) {}
    }

    // MARK: Delete

    @Test func deleteThenUndoRestoresComboMultiplierPeakAndTheHerosBest() throws {
        let store = try makeStore()
        let room = photos(6)
        let (combat, hero) = start(room, in: store)
        for item in room.prefix(3) { combat.decideDelete(item, hero: hero) }
        let before = (combat.combo, combat.peakCombo, combat.comboMultiplier, hero.highestCombo)

        combat.decideDelete(room[3], hero: hero)
        #expect(combat.combo == before.0 + 1)
        #expect(hero.highestCombo == before.3 + 1)

        #expect(combat.undoLastDecision(hero: hero, context: store.context))
        #expect(combat.combo == before.0)
        #expect(combat.peakCombo == before.1)
        #expect(combat.comboMultiplier == before.2)
        #expect(hero.highestCombo == before.3, "the hero's best combo must not keep a streak that was undone")
        #expect(combat.pendingDecisions.count == 3)
        #expect(combat.topItem?.id == "p3")
        withExtendedLifetime(store.container) {}
    }

    // MARK: Refusals

    @Test func aDecisionCannotBeUndoneTwice() throws {
        let store = try makeStore()
        let room = photos(4)
        let (combat, hero) = start(room, in: store)
        combat.decideDelete(room[0], hero: hero)
        combat.decideDelete(room[1], hero: hero)

        #expect(combat.undoLastDecision(hero: hero, context: store.context))
        let afterOne = (combat.combo, combat.pendingDecisions.count, combat.topItem?.id)
        #expect(!combat.undoLastDecision(hero: hero, context: store.context))
        #expect(combat.combo == afterOne.0)
        #expect(combat.pendingDecisions.count == afterOne.1)
        #expect(combat.topItem?.id == afterOne.2)
        withExtendedLifetime(store.container) {}
    }

    @Test func undoIsRefusedAfterTheWindow() throws {
        let store = try makeStore()
        let room = photos(3)
        let (combat, hero) = start(room, in: store)
        combat.decideDelete(room[0], hero: hero)

        let late = Date().addingTimeInterval(DiveRules.undoWindowSeconds + 1)
        #expect(!combat.canUndo(now: late))
        #expect(!combat.undoLastDecision(hero: hero, context: store.context, now: late))
        #expect(combat.pendingDecisions.count == 1)
        withExtendedLifetime(store.container) {}
    }

    @Test func undoIsRefusedOnceTheRoomSummaryIsShowing() throws {
        let store = try makeStore()
        let room = photos(2)
        let (combat, hero) = start(room, in: store)
        combat.decideDelete(room[0], hero: hero)
        combat.decideDelete(room[1], hero: hero)
        #expect(combat.phase == .roomSummary)

        #expect(!combat.canUndo())
        #expect(!combat.undoLastDecision(hero: hero, context: store.context))
        #expect(combat.pendingDecisions.count == 2, "the summary is where a last card is flipped")
        withExtendedLifetime(store.container) {}
    }

    // MARK: Duplicate groups

    @Test func aGroupCommitUndoesAsOneStep() throws {
        let store = try makeStore()
        var members = photos(3)
        for index in members.indices { members[index].monsterType = .perfectPairWyrmling }
        let group = DuplicateGroup(representativeID: members[0].id, members: members, survivorID: members[1].id)
        let (combat, hero) = start([members[0], photos(2)[1]], in: store)

        // Delete the first copy, keep the other two.
        combat.commitGroupDecisions(group, decisions: [members[0].id: true], hero: hero, context: store.context)
        #expect(combat.pendingDecisions.count == 3)
        #expect(try keptRecords(store.context).count == 2)

        #expect(combat.undoLastDecision(hero: hero, context: store.context))
        #expect(combat.pendingDecisions.isEmpty, "every copy's decision goes in one step")
        #expect(try keptRecords(store.context).isEmpty, "and so does every saved record it inserted")
        #expect(combat.combo == 0)
        #expect(combat.topItem?.id == members[0].id)
        withExtendedLifetime(store.container) {}
    }
}

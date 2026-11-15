//
//  GlossaryAppConstantsTests.swift
//  PurgeQuestTests
//
//  The glossary says "Room: up to 20 items" and "up to five rooms". Those numbers must be the ones the dive
//  actually uses. Needs the app target (CombatViewModel), so it runs in Xcode and CI only.
//

import Testing
@testable import PurgeQuest

@MainActor
struct GlossaryAppConstantsTests {

    @Test func theGlossaryDescribesTheDiveTheGameRuns() {
        #expect(Glossary.itemsPerRoom == CombatViewModel.roomSize)
        #expect(Glossary.maxRoomsPerDive == CombatViewModel.totalRoomsPerSession)
    }
}

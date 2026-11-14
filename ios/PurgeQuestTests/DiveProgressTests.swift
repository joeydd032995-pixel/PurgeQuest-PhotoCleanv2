//
//  DiveProgressTests.swift
//  PurgeQuestTests
//
//  The room count and the room bar the HUD shows (DiveProgress.swift). Foundation only, so these run in
//  Xcode and in the Linux harness.
//

import Testing
import Foundation
@testable import PurgeQuest

struct DiveProgressTests {

    /// A dive as the view model deals it: `library` items, rooms of 20, at most 5 rooms.
    private func progress(room: Int, library: Int, remaining: Int) -> DiveProgress {
        let dealtSoFar = min(library, room * 20)
        let dealtHere = min(20, library - (room - 1) * 20)
        return DiveProgress(room: room, dealtRoomSize: dealtHere, remaining: remaining,
                            undealt: library - dealtSoFar, itemsPerRoom: 20, maxRooms: 5)
    }

    // MARK: How many rooms

    @Test func aFullLibraryRunsTheWholeFiveRooms() {
        #expect(progress(room: 1, library: 150, remaining: 20).totalRooms == 5)
        #expect(progress(room: 4, library: 150, remaining: 5).totalRooms == 5)
    }

    @Test func aSmallLibraryNeverClaimsRoomsItWillNotHave() {
        // 6 photos is one room, not "Room 1 of 5".
        #expect(progress(room: 1, library: 6, remaining: 6).totalRooms == 1)
        // 45 items: rooms of 20, 20 and 5.
        #expect(progress(room: 1, library: 45, remaining: 20).totalRooms == 3)
        #expect(progress(room: 3, library: 45, remaining: 5).totalRooms == 3)
        // Exactly two full rooms is two rooms, not three.
        #expect(progress(room: 1, library: 40, remaining: 20).totalRooms == 2)
    }

    @Test func theTotalNeverFallsBelowTheRoomBeingPlayed() {
        // After "Continue Deeper" the room counter restarts while the queue carries on.
        let deeper = DiveProgress(room: 1, dealtRoomSize: 20, remaining: 20, undealt: 0, itemsPerRoom: 20, maxRooms: 5)
        #expect(deeper.totalRooms == 1)
        for room in 1...8 {
            let p = DiveProgress(room: room, dealtRoomSize: 20, remaining: 10, undealt: 0, itemsPerRoom: 20, maxRooms: 5)
            #expect(p.totalRooms >= p.room)
        }
    }

    // MARK: The bar

    @Test func theBarFillsPastRoomsFullThisRoomByProgressAndFutureRoomsNot() {
        let p = progress(room: 2, library: 150, remaining: 12)   // 8 of 20 decided
        #expect(p.fill(ofSegment: 0) == 1)
        #expect(abs(p.fill(ofSegment: 1) - 0.4) < 1e-9)
        #expect(p.fill(ofSegment: 2) == 0)
        #expect(p.fill(ofSegment: 4) == 0)
    }

    @Test func aFreshRoomStartsEmptyAndAFinishedOneIsFull() {
        #expect(progress(room: 3, library: 150, remaining: 20).fill(ofSegment: 2) == 0)
        #expect(progress(room: 3, library: 150, remaining: 0).fill(ofSegment: 2) == 1)
    }

    @Test func nothingDealtMeansNothingFilled() {
        let empty = DiveProgress(room: 1, dealtRoomSize: 0, remaining: 0, undealt: 0, itemsPerRoom: 20, maxRooms: 5)
        #expect(empty.fill(ofSegment: 0) == 0)
    }

    @Test func theCountsAreClampedToWhatCanBeTrue() {
        let odd = DiveProgress(room: 0, dealtRoomSize: 20, remaining: 99, undealt: -5, itemsPerRoom: 20, maxRooms: 5)
        #expect(odd.room == 1)
        #expect(odd.remaining == 20, "more left than were dealt")
        #expect(odd.totalRooms == 1)
        let negative = DiveProgress(room: 1, dealtRoomSize: 20, remaining: -3, undealt: 0, itemsPerRoom: 20, maxRooms: 5)
        #expect(negative.remaining == 0)
    }

    // MARK: Words

    @Test func theSummaryNamesTheRoomAndWhatIsLeft() {
        #expect(progress(room: 2, library: 150, remaining: 12).summary == "Room 2 of 5, 12 left")
        #expect(progress(room: 1, library: 6, remaining: 1).summary == "Room 1 of 1, 1 left")
    }
}

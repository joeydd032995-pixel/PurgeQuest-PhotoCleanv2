//
//  RoomTargetingTests.swift
//  PurgeQuestTests
//
//  How a room is dealt. Before each room the dive counts what is left in four kinds of clutter and
//  fills 30-50% of the room from the biggest one; a Focused Dive names the bucket instead and fills
//  from it first. Pure Foundation, so these also run on the Linux harness (tools/swift_harness/run.sh):
//  nothing here may touch UIKit, SwiftData or Photos.
//

import Testing
import Foundation
@testable import PurgeQuest

/// A small seeded generator so every random deal below can be repeated exactly.
private struct TargetingRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@MainActor
struct RoomTargetingTests {

    // MARK: - Helpers

    /// A fixed "now" and calendar, so ages never depend on the day the tests run.
    // `nonisolated` so the helpers' default arguments below can read them without hopping to the main actor.
    nonisolated private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }()
    nonisolated private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func yearsAgo(_ n: Int) -> Date {
        Self.calendar.date(byAdding: .year, value: -n, to: Self.now)!
    }

    private func photo(sharp: Double? = 60, screenshot: Bool = false, taken: Date? = RoomTargetingTests.now) -> RoomTargetFacts {
        RoomTargetFacts(
            isVideo: false, isScreenshot: screenshot, sharpness: sharp,
            durationSeconds: 0, estimatedBytes: 3_000_000, creationDate: taken
        )
    }

    private func video(bytes: Int64 = 20_000_000, seconds: Double = 30, taken: Date? = RoomTargetingTests.now) -> RoomTargetFacts {
        RoomTargetFacts(
            isVideo: true, isScreenshot: false, sharpness: nil,
            durationSeconds: seconds, estimatedBytes: bytes, creationDate: taken
        )
    }

    private func buckets(_ facts: RoomTargetFacts) -> Set<RoomBucket> {
        RoomTargeting.buckets(for: facts, now: Self.now, calendar: Self.calendar)
    }

    /// `count` queue entries that all sit in the same buckets.
    private func rep(_ set: Set<RoomBucket>, _ count: Int) -> [Set<RoomBucket>] {
        Array(repeating: set, count: count)
    }

    private func deal(_ pool: [Set<RoomBucket>], start: Int = 0, size: Int = 20, focus: RoomBucket? = nil, seed: UInt64) -> [Int] {
        var rng = TargetingRNG(seed: seed)
        return RoomTargeting.arrangedOrder(memberships: pool, roomStart: start, roomSize: size, focus: focus, using: &rng)
    }

    /// The queue positions of the room that starts at `start`.
    private func room(_ order: [Int], start: Int = 0, size: Int = 20) -> [Int] {
        Array(order[start..<min(start + size, order.count)])
    }

    // MARK: - Which bucket an item is in

    @Test func aPhotoBelowTheClassifiersBlurLineIsBlurry() {
        #expect(buckets(photo(sharp: 8.99)) == [.blur])
        #expect(buckets(photo(sharp: 9.0)).isEmpty)
        #expect(buckets(photo(sharp: nil)).isEmpty)
    }

    @Test func aScreenshotIsAScreenshotNotBlur() {
        // The classifier names a screenshot before it ever looks at sharpness.
        #expect(buckets(photo(sharp: 2, screenshot: true)) == [.screenshots])
    }

    @Test func aVideoIsLargeByBytesOrByLength() {
        #expect(buckets(video(bytes: 100_000_001)) == [.largeVideo])
        #expect(buckets(video(bytes: 100_000_000)).isEmpty)
        #expect(buckets(video(seconds: 120.5)) == [.largeVideo])
        #expect(buckets(video(seconds: 120)).isEmpty)
        #expect(buckets(video(bytes: 500, seconds: 5)).isEmpty)
    }

    @Test func aPhotoIsOldFromThreeYears() {
        #expect(buckets(photo(taken: yearsAgo(3))) == [.old])
        #expect(buckets(photo(taken: yearsAgo(3).addingTimeInterval(86_400))).isEmpty)
        #expect(buckets(photo(taken: nil)).isEmpty)
    }

    @Test func anOldVideoIsNotAnOldPhoto() {
        #expect(buckets(video(taken: yearsAgo(5))).isEmpty)
    }

    @Test func oneItemCanSitInTwoBuckets() {
        #expect(buckets(photo(sharp: 3, taken: yearsAgo(4))) == [.blur, .old])
    }

    // MARK: - Counting and choosing

    @Test func countsTallyEveryBucketAnItemSitsIn() {
        let pool: [Set<RoomBucket>] = [[.blur], [.blur, .old], [.screenshots], []]
        #expect(RoomTargeting.counts(pool) == [.blur: 2, .old: 1, .screenshots: 1])
    }

    @Test func theLargestBucketWinsAndTiesFollowTheMenuOrder() {
        #expect(RoomTargeting.largest(in: [.old: 3, .blur: 3, .screenshots: 1]) == .blur)
        #expect(RoomTargeting.largest(in: [.old: 4, .blur: 3]) == .old)
        #expect(RoomTargeting.largest(in: [:]) == nil)
        #expect(RoomTargeting.largest(in: [.old: 0]) == nil)
    }

    // MARK: - Dealing a room

    @Test func aDefaultRoomTakesThirtyToFiftyPercentFromTheLargestBucket() {
        // 40 screenshots (the largest bucket), 10 blurry, 50 in no bucket.
        let pool = rep([.screenshots], 40) + rep([.blur], 10) + rep([], 50)
        var shares = Set<Int>()
        for seed in 0..<200 {
            let dealt = room(deal(pool, seed: UInt64(seed)))
            #expect(dealt.count == 20)
            #expect(Set(dealt).count == 20)
            let shots = dealt.filter { $0 < 40 }.count
            #expect((6...10).contains(shots))
            shares.insert(shots)
        }
        #expect(shares == Set(6...10))
    }

    @Test func defaultRoomsStayVaried() {
        // Past the bucket share the room is pure random: other buckets and plain items both show up,
        // and no two seeds deal the same room.
        let pool = rep([.screenshots], 40) + rep([.blur], 10) + rep([], 50)
        var rooms = Set<[Int]>()
        var sawBlur = false
        var sawPlain = false
        for seed in 0..<100 {
            let dealt = room(deal(pool, seed: UInt64(seed)))
            rooms.insert(dealt.sorted())
            if dealt.contains(where: { $0 >= 40 && $0 < 50 }) { sawBlur = true }
            if dealt.contains(where: { $0 >= 50 }) { sawPlain = true }
        }
        #expect(sawBlur)
        #expect(sawPlain)
        #expect(rooms.count > 90)
    }

    @Test func onlyWhatIsLeftIsCounted() {
        // 60 screenshots were already dealt, more than anything that remains. Counting them would make
        // screenshots "the largest bucket" with none left to take; what remains is blur, so blur is leaned on.
        let pool = rep([.screenshots], 60) + rep([.blur], 40) + rep([], 30)
        for seed in 0..<50 {
            let dealt = room(deal(pool, start: 60, seed: UInt64(seed)), start: 60)
            #expect(dealt.allSatisfy { $0 >= 60 })
            let blur = dealt.filter { $0 >= 60 && $0 < 100 }.count
            #expect((6...10).contains(blur))
        }
    }

    @Test func theRoomIsShuffledNotBucketFirst() {
        // Bucket picks are mixed in with the rest, so a room does not open with a run of the same thing.
        let pool = rep([.screenshots], 40) + rep([], 60)
        var openedWithBucket = 0
        var openedWithPlain = 0
        for seed in 0..<100 {
            let first = deal(pool, seed: UInt64(seed))[0]
            if first < 40 { openedWithBucket += 1 } else { openedWithPlain += 1 }
        }
        #expect(openedWithBucket > 10)
        #expect(openedWithPlain > 10)
    }

    @Test func theQuotaNeverExceedsTheBucket() {
        // Only 3 screenshots: all 3 go in and the other 17 come from the rest.
        let pool = rep([.screenshots], 3) + rep([], 97)
        for seed in 0..<30 {
            let dealt = room(deal(pool, seed: UInt64(seed)))
            #expect(dealt.filter { $0 < 3 }.count == 3)
            #expect(dealt.count == 20)
        }
    }

    @Test func aRoomMadeOfNothingButTheBucketIsStillRandom() {
        // Nothing outside the bucket to mix in: the whole room is bucket, drawn at random rather than
        // the first twenty in queue order. Position 29 is in a random 20 of 30 about two times in three.
        let pool = rep([.blur], 30)
        var lastSeen = 0
        for seed in 0..<100 {
            let dealt = room(deal(pool, seed: UInt64(seed)))
            #expect(Set(dealt).count == 20)
            if dealt.contains(29) { lastSeen += 1 }
        }
        #expect(lastSeen > 40)
    }

    @Test func aFocusedRoomFillsFromItsBucketFirst() {
        // 12 screenshots among 100: all 12 land in the first room and the other 8 places come from the rest.
        let pool = rep([.screenshots], 12) + rep([.blur], 30) + rep([], 58)
        for seed in 0..<50 {
            let dealt = room(deal(pool, focus: .screenshots, seed: UInt64(seed)))
            #expect(dealt.count == 20)
            #expect(dealt.filter { $0 < 12 }.count == 12)
        }
    }

    @Test func aFocusedRoomWithABigBucketIsAllBucket() {
        let pool = rep([.blur], 30) + rep([], 70)
        for seed in 0..<50 {
            let dealt = room(deal(pool, focus: .blur, seed: UInt64(seed)))
            #expect(dealt.allSatisfy { $0 < 30 })
        }
    }

    @Test func aFocusedDiveDrainsItsBucketRoomAfterRoom() {
        // Rooms are dealt one after another from what is left, so the chosen bucket drains first.
        var pool = rep([.blur], 30) + rep([], 70)
        var rng = TargetingRNG(seed: 1)
        var blurInRoom: [Int] = []
        for roomIndex in 0..<5 {
            let start = roomIndex * 20
            let order = RoomTargeting.arrangedOrder(memberships: pool, roomStart: start, roomSize: 20, focus: .blur, using: &rng)
            pool = order.map { pool[$0] }
            let dealt = pool[start..<(start + 20)]
            blurInRoom.append(dealt.filter { $0.contains(.blur) }.count)
        }
        #expect(blurInRoom == [20, 10, 0, 0, 0])
    }

    @Test func anEmptyBucketFallsBackToPureRandom() {
        // Nothing is in any bucket: the deal is a plain random room, not the queue's first twenty.
        let pool = rep([], 60)
        var reachedPast40 = false
        for seed in 0..<40 {
            let dealt = room(deal(pool, seed: UInt64(seed)))
            #expect(dealt.count == 20)
            #expect(Set(dealt).count == 20)
            #expect(dealt.sorted() != Array(0..<20))
            if dealt.contains(where: { $0 >= 40 }) { reachedPast40 = true }
        }
        #expect(reachedPast40)
    }

    @Test func aFocusOnAnEmptyBucketIsPureRandomNotTheLargestBucket() {
        // No old photos are left. Pure random over 40 blur and 20 plain averages about 13 blur in a room of 20
        // (1,333 over 100 rooms). Falling back to "the largest bucket, 30-50%" would hold blur near 8
        // (about 800), and focusing on the largest bucket instead would hold it at 20 (2,000).
        let pool = rep([.blur], 40) + rep([], 20)
        var totalBlur = 0
        for seed in 0..<100 {
            let dealt = room(deal(pool, focus: .old, seed: UInt64(seed)))
            #expect(dealt.count == 20)
            #expect(Set(dealt).count == 20)
            totalBlur += dealt.filter { $0 < 40 }.count
        }
        #expect(totalBlur > 1200)
        #expect(totalBlur < 1470)
    }

    @Test func aDealIsAlwaysAPermutationThatLeavesTheServedPrefixAlone() {
        let pool = rep([.old], 20) + rep([.screenshots], 15) + rep([], 15)
        for seed in 0..<50 {
            let order = deal(pool, start: 7, seed: UInt64(seed))
            #expect(order.sorted() == Array(0..<50))
            #expect(Array(order[0..<7]) == Array(0..<7))
            let rest = Array(order[27...])
            #expect(rest == rest.sorted())
        }
    }

    @Test func aShortQueueDealsWhatIsLeft() {
        let pool = rep([.blur], 3) + rep([], 2)
        let order = deal(pool, seed: 1)
        #expect(order.sorted() == [0, 1, 2, 3, 4])
    }

    @Test func degenerateInputsLeaveTheQueueAlone() {
        let pool = rep([.blur], 5)
        let same = [0, 1, 2, 3, 4]
        #expect(deal([], seed: 1) == [])
        #expect(deal(pool, start: 5, seed: 1) == same)
        #expect(deal(pool, start: 9, seed: 1) == same)
        #expect(deal(pool, start: -1, seed: 1) == same)
        #expect(deal(pool, size: 0, seed: 1) == same)
    }

    @Test func theShareStaysInTheBandForSmallRooms() {
        // 5 places: 30-50% is exactly 2. A lone place still goes to the bucket.
        let pool = rep([.screenshots], 10) + rep([], 10)
        for seed in 0..<30 {
            let five = room(deal(pool, size: 5, seed: UInt64(seed)), size: 5)
            #expect(five.filter { $0 < 10 }.count == 2)
        }
        let one = room(deal(pool, size: 1, seed: 3), size: 1)
        #expect(one.count == 1)
        #expect(one[0] < 10)
    }

    @Test func theSameSeedDealsTheSameRoomAndOtherSeedsDiffer() {
        let pool = rep([.old], 25) + rep([.blur], 25) + rep([], 50)
        #expect(deal(pool, seed: 9) == deal(pool, seed: 9))
        #expect(deal(pool, seed: 9) != deal(pool, seed: 10))
    }
}

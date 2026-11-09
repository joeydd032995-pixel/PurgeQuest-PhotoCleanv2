//
//  RoomTargeting.swift
//  PurgeQuest
//
//  Smarter room filling, still simple. Before a room is dealt, the dive counts what is left in four
//  kinds of clutter and fills 30-50% of the room from the biggest one; the rest is drawn at random
//  from outside that bucket, so default dives stay varied. A Focused Dive names the bucket instead and fills the room from it
//  first, drawing on the rest only when the bucket runs dry. A bucket with nothing left means a
//  pure random room.
//
//  Pure Foundation (no MediaItem, no SwiftData) so the Linux harness runs it.
//  RoomTargeting+MediaItem.swift is the thin bridge from a MediaItem.
//

import Foundation

/// The four kinds of clutter a room can lean toward. Declaration order is the menu order and the tie-break.
nonisolated enum RoomBucket: String, CaseIterable, Sendable {
    case blur, screenshots, largeVideo, old
}

/// The few facts about an item that decide which buckets it sits in.
nonisolated struct RoomTargetFacts: Sendable, Equatable {
    var isVideo: Bool
    var isScreenshot: Bool
    var sharpness: Double?
    var durationSeconds: Double
    var estimatedBytes: Int64
    var creationDate: Date?
}

nonisolated enum RoomTargeting {

    // MARK: - Rules

    // These restate MonsterClassifier's blur line, archive age and 100 MB, so a bucket means what the
    // game already means by it. RoomTargetingBridgeTests pins them to the classifier.
    static let blurSharpness: Double = 55.0
    static let oldPhotoYears: Int = 3
    static let largeVideoBytes: Int64 = 100_000_000
    static let longVideoSeconds: Double = 120

    /// A default dive fills this percentage of each room from the largest bucket.
    static let defaultSharePercent: ClosedRange<Int> = 30...50

    /// Which buckets an item sits in. A photo can be blurry and old at once. A screenshot is never "blur"
    /// (the classifier names a screenshot before it looks at sharpness). A video is only ever a large video.
    static func buckets(for facts: RoomTargetFacts, now: Date, calendar: Calendar = .current) -> Set<RoomBucket> {
        var result: Set<RoomBucket> = []
        if facts.isVideo {
            if facts.estimatedBytes > largeVideoBytes || facts.durationSeconds > longVideoSeconds {
                result.insert(.largeVideo)
            }
            return result
        }
        if facts.isScreenshot {
            result.insert(.screenshots)
        } else if let sharpness = facts.sharpness, sharpness < blurSharpness {
            result.insert(.blur)
        }
        if let date = facts.creationDate,
           let years = calendar.dateComponents([.year], from: date, to: now).year,
           years >= oldPhotoYears {
            result.insert(.old)
        }
        return result
    }

    // MARK: - Counting

    /// How many items sit in each bucket (an item counts in every bucket it is in). Empty buckets are left out.
    static func counts(_ memberships: [Set<RoomBucket>]) -> [RoomBucket: Int] {
        var tally: [RoomBucket: Int] = [:]
        for set in memberships {
            for bucket in set { tally[bucket, default: 0] += 1 }
        }
        return tally
    }

    /// The bucket with the most items; ties go to the first in menu order. Nil when every bucket is empty.
    static func largest(in counts: [RoomBucket: Int]) -> RoomBucket? {
        var best: RoomBucket?
        var bestCount = 0
        for bucket in RoomBucket.allCases {
            let n = counts[bucket] ?? 0
            if n > bestCount {
                best = bucket
                bestCount = n
            }
        }
        return best
    }

    // MARK: - Dealing

    /// Reorders a dive's queue so the next room's picks lead what is left. Returns a permutation of
    /// `memberships.indices`: positions before `roomStart` (already dealt) stay put, the next
    /// `min(roomSize, left)` positions are the room, and everything else follows in its original order.
    ///
    /// Default dive (no focus): count what is left, take 30-50% of the room from the largest bucket and
    /// fill the rest at random from everything outside it. Focused dive: take the whole room from that
    /// bucket, topping up from the rest only when it runs dry. A bucket with nothing left means a pure
    /// random room.
    static func arrangedOrder<R: RandomNumberGenerator>(
        memberships: [Set<RoomBucket>],
        roomStart: Int,
        roomSize: Int,
        focus: RoomBucket?,
        using rng: inout R
    ) -> [Int] {
        let everything = Array(memberships.indices)
        guard roomStart >= 0, roomStart < memberships.count, roomSize > 0 else { return everything }

        let left = Array(roomStart..<memberships.count)
        let take = min(roomSize, left.count)
        let tally = counts(Array(memberships[roomStart...]))
        let target = focus ?? largest(in: tally)

        var picks: [Int]
        if let target, (tally[target] ?? 0) > 0 {
            let quota: Int
            if focus != nil {
                quota = take
            } else {
                let low = (take * defaultSharePercent.lowerBound + 99) / 100
                let high = max(low, take * defaultSharePercent.upperBound / 100)
                quota = Int.random(in: low...high, using: &rng)
            }
            let inBucket = left.filter { memberships[$0].contains(target) }.shuffled(using: &rng)
            let outside = left.filter { !memberships[$0].contains(target) }.shuffled(using: &rng)
            let fromOutside = min(take - min(quota, inBucket.count), outside.count)
            // When there is not enough outside the bucket to fill the room, the bucket tops it up.
            let fromBucket = min(inBucket.count, take - fromOutside)
            picks = Array(inBucket.prefix(fromBucket)) + Array(outside.prefix(fromOutside))
        } else {
            picks = Array(left.shuffled(using: &rng).prefix(take))
        }

        let room = picks.shuffled(using: &rng)
        let dealt = Set(room)
        return Array(0..<roomStart) + room + left.filter { !dealt.contains($0) }
    }
}

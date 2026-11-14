//
//  DiveProgress.swift
//  PurgeQuest
//
//  Where the player is in a dive, as the HUD draws it: which room of how many, and how far through
//  the current one. Foundation only, so the Linux harness checks it (tools/swift_harness/run.sh).
//
//  The room count is the real one. A dive is at most five rooms of twenty, and a library with 45 items
//  has three, so the HUD used to say "Room 1/5" for a dive that would end after one room.
//

import Foundation

nonisolated struct DiveProgress: Equatable, Sendable {
    /// The room being played, counting from 1.
    let room: Int
    /// Rooms in this dive, counting the current one: never fewer than `room`, never more than the cap.
    let totalRooms: Int
    /// Cards dealt into the current room.
    let roomSize: Int
    /// Cards in the current room still to decide.
    let remaining: Int

    /// - Parameters:
    ///   - room: the room being played, from 1.
    ///   - dealtRoomSize: how many cards this room was dealt.
    ///   - remaining: how many of them are still to decide.
    ///   - undealt: cards in the queue that no room has been dealt yet. They decide how many rooms follow.
    ///   - itemsPerRoom: the size of a full room.
    ///   - maxRooms: the most rooms a dive runs.
    init(room: Int, dealtRoomSize: Int, remaining: Int, undealt: Int, itemsPerRoom: Int, maxRooms: Int) {
        let current = max(1, room)
        let futureRooms = itemsPerRoom > 0 ? (max(0, undealt) + itemsPerRoom - 1) / itemsPerRoom : 0
        self.room = current
        self.totalRooms = max(current, min(maxRooms, current + futureRooms))
        self.roomSize = max(0, dealtRoomSize)
        self.remaining = min(max(0, remaining), self.roomSize)
    }

    /// How full segment `index` (from 0) of the room bar is, 0...1: rooms already played are full, this
    /// room fills as its cards are decided, and rooms still to come are empty.
    func fill(ofSegment index: Int) -> Double {
        let current = room - 1
        if index < current { return 1 }
        if index > current { return 0 }
        guard roomSize > 0 else { return 0 }
        return Double(roomSize - remaining) / Double(roomSize)
    }

    /// The same facts in words, for VoiceOver: "Room 2 of 5, 12 left".
    var summary: String {
        "Room \(room) of \(totalRooms), \(remaining) left"
    }
}

//
//  BlockingCallTests.swift
//  PurgeQuestTests
//
//  Pure-Foundation tests for the helper that keeps a blocking call (Vision's synchronous `perform`) off
//  Swift concurrency's cooperative pool and bounds how long a scan waits for it. They also run on the
//  Linux harness (tools/swift_harness/run.sh), so nothing here may touch UIKit, SwiftData or Photos.
//
//  A call that must outlast its deadline blocks on a semaphore the test releases afterwards, rather than
//  sleeping for a fixed time: a test run in parallel with others can have its timer delayed, and a sleep
//  would then finish "in time" and turn a timeout test into a flaky one.
//

import Testing
import Foundation
@testable import PurgeQuest

@MainActor
struct BlockingCallTests {

    private func makeQueue() -> DispatchQueue {
        DispatchQueue(label: "BlockingCallTests", qos: .userInitiated, attributes: .concurrent)
    }

    @Test func aCallThatReturnsInTimeHandsBackItsValue() async {
        let outcome = await BlockingCall.run(on: makeQueue(), within: 30) { 6 * 7 }
        guard case .finished(let value) = outcome else {
            Issue.record("expected the call to finish, got \(outcome)")
            return
        }
        #expect(value == 42)
    }

    @Test func aCallThatIsStillBlockedAtTheDeadlineIsAbandoned() async {
        let release = DispatchSemaphore(value: 0)
        let started = Date()
        let outcome = await BlockingCall.run(on: makeQueue(), within: 0.15) {
            release.wait()
            return "late"
        }
        let waited = Date().timeIntervalSince(started)
        release.signal()

        guard case .timedOut = outcome else {
            Issue.record("expected a timeout, got \(outcome)")
            return
        }
        // The call could not have returned on its own (it was blocked until now), so the deadline is what
        // ended the wait, and it did so after the time asked for.
        #expect(waited >= 0.12, "gave up after \(waited) s, before the 0.15 s deadline")
    }

    @Test func aCallThatFinishesAfterItsDeadlineDoesNotResumeTwice() async {
        // Resuming a continuation twice is fatal, so surviving this test is the assertion: the late result is
        // delivered after the timeout already was.
        let release = DispatchSemaphore(value: 0)
        let returned = DispatchSemaphore(value: 0)
        let outcome = await BlockingCall.run(on: makeQueue(), within: 0.05) {
            defer { returned.signal() }
            release.wait()
            return 1
        }
        guard case .timedOut = outcome else {
            Issue.record("expected a timeout, got \(outcome)")
            release.signal()
            return
        }
        release.signal()
        returned.wait()
        // The work has returned; give its answer a moment to reach the (already spent) continuation.
        try? await Task.sleep(for: .milliseconds(100))
    }

    @Test func aZeroOrNegativeDeadlineTimesOutAtOnce() async {
        let release = DispatchSemaphore(value: 0)
        let zero = await BlockingCall.run(on: makeQueue(), within: 0) { release.wait(); return 1 }
        let negative = await BlockingCall.run(on: makeQueue(), within: -4) { release.wait(); return 1 }
        release.signal()
        release.signal()
        for outcome in [zero, negative] {
            if case .finished = outcome { Issue.record("a call with no time to run should have timed out") }
        }
    }

    /// The mechanism the helper exists for: the blocking work runs on the dispatch queue it was given, never
    /// inline on the thread that awaited it. On a device the awaiting thread belongs to Swift concurrency's
    /// cooperative pool, which has one thread per core; a call that parks such a thread (Vision's `perform`
    /// does) can use the pool up. The starvation itself cannot be staged on the Linux harness, because
    /// swift-corelibs-libdispatch grows its pool as threads block, so this pins the mechanism instead.
    @Test func theWorkRunsOnTheQueueItWasGiven() async {
        let key = DispatchSpecificKey<String>()
        let queue = makeQueue()
        queue.setSpecific(key: key, value: "the-queue")

        let outcome = await BlockingCall.run(on: queue, within: 30) { DispatchQueue.getSpecific(key: key) }

        guard case .finished(let ranOn) = outcome else {
            Issue.record("expected the call to finish, got \(outcome)")
            return
        }
        #expect(ranOn == "the-queue", "the work did not run on the queue it was given")
        #expect(DispatchQueue.getSpecific(key: key) == nil, "the awaiting code is not on that queue")
    }

    @Test func manyBlockingCallsAtOnceAllComeBack() async {
        let queue = makeQueue()
        let count = max(8, ProcessInfo.processInfo.activeProcessorCount * 3)
        let values = await withTaskGroup(of: Int?.self, returning: [Int].self) { group in
            for i in 0..<count {
                group.addTask {
                    let outcome = await BlockingCall.run(on: queue, within: 60) {
                        Thread.sleep(forTimeInterval: 0.05)
                        return i
                    }
                    if case .finished(let value) = outcome { return value }
                    return nil
                }
            }
            var collected: [Int] = []
            for await value in group { if let value { collected.append(value) } }
            return collected.sorted()
        }
        #expect(values == Array(0..<count))
    }

    @Test func aTripwireStaysTrippedOnceTripped() {
        let wire = BlockingCall.Tripwire()
        #expect(!wire.isTripped)
        wire.trip()
        #expect(wire.isTripped)
        wire.trip()
        #expect(wire.isTripped)
    }

    @Test func aTripwireIsSafeToShareAcrossTasks() async {
        let wire = BlockingCall.Tripwire()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<64 {
                group.addTask { if i == 37 { wire.trip() } else { _ = wire.isTripped } }
            }
        }
        #expect(wire.isTripped)
    }
}

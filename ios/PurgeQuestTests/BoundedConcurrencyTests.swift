//
//  BoundedConcurrencyTests.swift
//  PurgeQuestTests
//
//  Pure-Foundation tests for the scan's bounded-concurrency map. They also run on the Linux harness
//  (tools/swift_harness/run.sh), so nothing here may touch UIKit, SwiftData or Photos.
//

import Testing
import Foundation
@testable import PurgeQuest

/// Counts how many transforms are running at once.
private actor InFlight {
    private(set) var current = 0
    private(set) var peak = 0
    func enter() { current += 1; peak = max(peak, current) }
    func leave() { current -= 1 }
}

/// A reference type that is not Sendable, like a PHAsset or a UIImage.
private final class Opaque {
    let id: Int
    init(_ id: Int) { self.id = id }
}

@MainActor
struct BoundedConcurrencyTests {

    @Test func resultsKeepTheOrderOfTheInputsWhateverFinishesFirst() async {
        // Later inputs finish sooner, so completion order is the reverse of input order.
        let inputs = Array(0..<12)
        let out = await BoundedConcurrency.map(inputs, limit: 4) { i in
            try? await Task.sleep(for: .milliseconds((12 - i) * 4))
            return i * 10
        }
        #expect(out == inputs.map { $0 * 10 })
    }

    @Test func neverMoreThanTheLimitAtOnce() async {
        let probe = InFlight()
        for limit in [1, 2, 3, 5] {
            _ = await BoundedConcurrency.map(Array(0..<20), limit: limit) { i in
                await probe.enter()
                try? await Task.sleep(for: .milliseconds(8))
                await probe.leave()
                return i
            }
            let peak = await probe.peak
            #expect(peak <= limit, "limit \(limit), saw \(peak)")
        }
    }

    @Test func aLimitAboveOneReallyOverlapsTheWork() async {
        let probe = InFlight()
        _ = await BoundedConcurrency.map(Array(0..<16), limit: 4) { i in
            await probe.enter()
            try? await Task.sleep(for: .milliseconds(20))
            await probe.leave()
            return i
        }
        let peak = await probe.peak
        #expect(peak >= 2, "work should overlap, saw a peak of \(peak)")
    }

    @Test func aLimitOfOneIsPlainSequentialOrder() async {
        let probe = InFlight()
        let out = await BoundedConcurrency.map(Array(0..<10), limit: 1) { i in
            await probe.enter()
            await probe.leave()
            return i
        }
        let peak = await probe.peak
        #expect(out == Array(0..<10))
        #expect(peak == 1)
    }

    @Test func aNonsensicalLimitStillRuns() async {
        let zero = await BoundedConcurrency.map([1, 2, 3], limit: 0) { $0 + 1 }
        let negative = await BoundedConcurrency.map([1, 2, 3], limit: -5) { $0 + 1 }
        let huge = await BoundedConcurrency.map([1, 2, 3], limit: 100) { $0 + 1 }
        #expect(zero == [2, 3, 4] && negative == [2, 3, 4] && huge == [2, 3, 4])
    }

    @Test func noInputsMeansNoOutputs() async {
        let out = await BoundedConcurrency.map([Int](), limit: 4) { $0 }
        #expect(out.isEmpty)
    }

    @Test func itCarriesTypesThatAreNotSendable() async {
        // PhotoKit assets and images are handed in and out once; the helper must not demand Sendable.
        let inputs = (0..<9).map(Opaque.init)
        let out = await BoundedConcurrency.map(inputs, limit: 3) { Opaque($0.id * 2) }
        #expect(out.map(\.id) == (0..<9).map { $0 * 2 })
    }

    @Test func manyMoreInputsThanSlotsAllGetProcessedExactlyOnce() async {
        let seen = InFlight()   // reused as a counter: every call enters once and never leaves
        let out = await BoundedConcurrency.map(Array(0..<200), limit: 6) { i in
            await seen.enter()
            return i
        }
        let total = await seen.current
        #expect(out == Array(0..<200))
        #expect(total == 200)
    }

    // New tests go above this line.
}

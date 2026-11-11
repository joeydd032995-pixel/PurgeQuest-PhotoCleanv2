//
//  BlockingCall.swift
//  PurgeQuest
//
//  Runs a blocking, synchronous call somewhere other than Swift concurrency's cooperative thread pool,
//  and stops waiting for it after a deadline. Pure Foundation, so the Linux harness tests it.
//
//  Why it exists: Vision's `perform` is synchronous and parks its thread on a dispatch group until its own
//  work is done. A dive's scan runs several photos at once, and the cooperative pool has only as many
//  threads as the device has cores. When every one of them sits inside a Vision call, nothing else that
//  needs the pool can run. On a three-core CI runner that is exactly what stopped a dive at "Summoning
//  monsters from your library…": the main thread idle, every pool thread parked in the same wait, no
//  thread doing any Vision work. A call that blocks belongs on a dispatch queue, where the system adds
//  threads as others block. And an answer that never comes must not hold a dive hostage, so the caller is
//  told `.timedOut` and carries on without it.
//

import Foundation

nonisolated enum BlockingCall {

    /// What a deadline-bound call came to.
    nonisolated enum Outcome<Value: Sendable>: Sendable {
        case finished(Value)
        case timedOut
    }

    /// Runs `work` on `queue` and returns what it returned, or `.timedOut` if it has not returned after
    /// `seconds`. The calling task is suspended while it waits, so it never holds a cooperative thread.
    ///
    /// A call cannot be cancelled. After a timeout it keeps its dispatch thread until it returns on its own,
    /// and whatever it returns is discarded.
    static func run<Value: Sendable>(
        on queue: DispatchQueue,
        within seconds: TimeInterval,
        _ work: @escaping @Sendable () -> Value
    ) async -> Outcome<Value> {
        await withCheckedContinuation { (continuation: CheckedContinuation<Outcome<Value>, Never>) in
            let firstAnswer = FirstAnswer(continuation)
            queue.async { firstAnswer.deliver(.finished(work())) }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + max(0, seconds)) {
                firstAnswer.deliver(.timedOut)
            }
        }
    }

    /// Hands the continuation the first outcome that arrives and drops every later one, so a call that
    /// finishes after its deadline cannot resume the continuation a second time.
    private nonisolated final class FirstAnswer<Value: Sendable>: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Outcome<Value>, Never>?

        init(_ continuation: CheckedContinuation<Outcome<Value>, Never>) {
            self.continuation = continuation
        }

        func deliver(_ outcome: Outcome<Value>) {
            lock.lock()
            let waiting = continuation
            continuation = nil
            lock.unlock()
            waiting?.resume(returning: outcome)
        }
    }

    /// A flag a scan shares among its calls. Once one call has timed out the scan trips it, and the calls
    /// that have not started yet skip the service instead of each waiting out a deadline of their own.
    nonisolated final class Tripwire: @unchecked Sendable {
        private let lock = NSLock()
        private var tripped = false

        init() {}

        var isTripped: Bool {
            lock.lock()
            defer { lock.unlock() }
            return tripped
        }

        func trip() {
            lock.lock()
            tripped = true
            lock.unlock()
        }
    }
}

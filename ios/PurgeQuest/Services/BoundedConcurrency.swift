//
//  BoundedConcurrency.swift
//  PurgeQuest
//
//  Runs an async transform over a list with at most `limit` calls in flight, returning the results in
//  the order of the inputs. Pure Foundation, so the Linux harness tests it.
//
//  Why it exists: a dive's scan enriches every asset (thumbnail from PhotoKit, text and barcode
//  recognition, sampled video frames), and each step spends most of its time waiting on something
//  other than the CPU. Done one asset after another, the waits add up; done a few at a time they
//  overlap. The limit keeps memory and PhotoKit/Vision pressure bounded; it is not "as many as possible".
//

import Foundation

nonisolated enum BoundedConcurrency {

    /// Wraps a value so it can cross into a child task. The transform and its input/output types are
    /// the caller's responsibility (PhotoKit objects and UIImages are handed over once and never shared).
    private struct Box<Value>: @unchecked Sendable {
        let value: Value
    }

    /// `transform` applied to every input, at most `limit` at once (at least one). Results keep the
    /// order of `inputs` whatever order the calls finish in.
    static func map<Input, Output>(
        _ inputs: [Input],
        limit: Int,
        _ transform: @escaping @Sendable (Input) async -> Output
    ) async -> [Output] {
        guard !inputs.isEmpty else { return [] }
        let width = max(1, min(limit, inputs.count))
        var results = [Output?](repeating: nil, count: inputs.count)

        await withTaskGroup(of: (Int, Box<Output>).self) { group in
            var next = 0
            while next < width {
                let index = next
                let input = Box(value: inputs[index])
                next += 1
                group.addTask { (index, Box(value: await transform(input.value))) }
            }
            // Each finished call frees a slot for the next input.
            while let (index, output) = await group.next() {
                results[index] = output.value
                if next < inputs.count {
                    let nextIndex = next
                    let input = Box(value: inputs[nextIndex])
                    next += 1
                    group.addTask { (nextIndex, Box(value: await transform(input.value))) }
                }
            }
        }
        return results.map { $0! }
    }
}

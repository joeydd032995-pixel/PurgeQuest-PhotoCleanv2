//
//  GoldSpinner.swift
//  PurgeQuest
//
//  The ornamental loading indicator from the splash: eight tapered spokes in
//  brand gold with a bright head chasing a fading tail. Holds still when
//  Reduce Motion is on.
//

import SwiftUI

struct GoldSpinner: View {
    var size: CGFloat = 40
    var color: Color = .questAmber

    private static let spokeCount = 8
    private static let tick: TimeInterval = 0.11

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                spokes(headIndex: 0)
            } else {
                TimelineView(.periodic(from: .now, by: Self.tick)) { context in
                    spokes(headIndex: Self.headIndex(at: context.date))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Loading")
    }

    /// Which spoke is brightest at a moment in time.
    static func headIndex(at date: Date) -> Int {
        Int(date.timeIntervalSinceReferenceDate / tick) % spokeCount
    }

    /// Opacity of a spoke given how many steps behind the head it is.
    static func opacity(forSpoke index: Int, head: Int) -> Double {
        let behind = (head - index + spokeCount) % spokeCount
        return max(0.18, 1.0 - Double(behind) * 0.12)
    }

    private func spokes(headIndex: Int) -> some View {
        ZStack {
            ForEach(0..<Self.spokeCount, id: \.self) { index in
                Capsule()
                    .fill(color)
                    .frame(width: size * 0.12, height: size * 0.30)
                    .offset(y: -size * 0.33)
                    .rotationEffect(.degrees(Double(index) * 360.0 / Double(Self.spokeCount)))
                    .opacity(Self.opacity(forSpoke: index, head: headIndex))
            }
        }
    }
}

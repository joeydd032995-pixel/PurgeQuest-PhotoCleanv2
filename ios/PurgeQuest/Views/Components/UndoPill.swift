//
//  UndoPill.swift
//  PurgeQuest
//
//  The glass pill that offers to take back the last decision (sub-plan 1.2, assessment 10.2: "Glass pill
//  above the buttons for 5 s after any decision; rewinds one step"). It is drawn as an overlay by CombatView,
//  so it appears and goes without moving the card or the buttons. A thin line shrinks across the bottom of
//  the pill to show the time left; with Reduce Motion on, the line is not animated and the pill simply goes.
//

import SwiftUI

struct UndoPill: View {
    let kind: DecisionHistory.Kind
    /// How long the offer lasts, for the shrinking line.
    let seconds: TimeInterval
    let onUndo: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var remaining: CGFloat = 1

    var body: some View {
        Button(action: onUndo) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.subheadline.weight(.bold))
                Text(Wording.undo(kind))
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
            .overlay(alignment: .bottom) { timeLeftLine }
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Wording.undo(kind))
        .accessibilityHint(Wording.undoHint(kind))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: seconds)) { remaining = 0 }
        }
    }

    /// The time left, as a thin line along the bottom edge. Hidden when motion is reduced, since it would
    /// only ever be a static, meaningless bar.
    @ViewBuilder
    private var timeLeftLine: some View {
        if !reduceMotion {
            GeometryReader { proxy in
                Capsule()
                    .fill(Color.questAmber.opacity(0.85))
                    .frame(width: proxy.size.width * remaining, height: 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 2)
            .padding(.horizontal, 14)
            .padding(.bottom, 4)
            .accessibilityHidden(true)
        }
    }
}

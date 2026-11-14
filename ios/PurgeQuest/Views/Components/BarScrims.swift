//
//  BarScrims.swift
//  PurgeQuest
//
//  Fades whatever scrolls under the status bar and the tab bar back into the canvas, so the clock does
//  not sit on a gold button and the tab labels do not sit on body text (A-09 in docs/design/UI_ASSESSMENT.md).
//
//  The fade is the canvas itself, not a flat color: it draws DungeonBackgroundView again, masked to the top
//  and bottom edges, so it matches the gold pool and the vignette exactly. It is drawn over the screen's
//  content, never hit-tested, and hidden from VoiceOver. Put it on a tab's root view, not on the
//  NavigationStack, so a pushed full-screen view (the dive) is not faded at its buttons.
//

import SwiftUI

private struct BarScrims: ViewModifier {
    /// The floating tab bar and the home indicator together, measured on an iPhone 16 Pro. The safe area
    /// below a tab's content usually reports this, but the fade must not depend on it.
    private let tabBarFloor: CGFloat = 83

    func body(content: Content) -> some View {
        content.overlay {
            GeometryReader { proxy in
                // Full screen first, then masked, so the mask's edges are the screen's edges.
                DungeonBackgroundView()
                    .ignoresSafeArea()
                    .mask {
                        VStack(spacing: 0) {
                            LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                                .frame(height: proxy.safeAreaInsets.top + 12)
                            Spacer(minLength: 0)
                            LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom)
                                .frame(height: max(proxy.safeAreaInsets.bottom, tabBarFloor) + 16)
                        }
                    }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

extension View {
    /// Fades content into the canvas where it passes under the status bar and the tab bar.
    func barScrims() -> some View {
        modifier(BarScrims())
    }
}

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
//  Geometry, measured on the CI tour (iPhone 16 Pro): a `.mask` is laid out inside the safe area even when
//  the view under it reaches past it. The first version put `.ignoresSafeArea()` on the background view
//  alone, so its mask started 62 pt down: nothing was faded over the status bar, the fade began at full
//  strength with a hard edge at the safe-area line, and every screen title below it was dimmed to about
//  2.7:1 (Dark) and 2.0:1 (Light). `.ignoresSafeArea()` now wraps the masked result, so the mask and the
//  canvas share the screen's own edges.
//

import SwiftUI

private struct BarScrims: ViewModifier {
    /// The floating tab bar and the home indicator together, measured on an iPhone 16 Pro. The safe area
    /// below a tab's content usually reports this, but the fade must not depend on it.
    private let tabBarFloor: CGFloat = 83

    /// The status bar and Dynamic Island, measured on an iPhone 16 Pro (62 pt). A screen pushed from the
    /// system More list reports a larger top inset because its navigation bar counts too; the fade covers
    /// the status bar only, so it is capped here and never reaches that screen's title.
    private let statusBarCap: CGFloat = 62

    /// How far the fade runs past the status bar.
    private let feather: CGFloat = 12

    /// The share of the top scrim held at full strength. The clock sits about 24 to 40 pt down, which is
    /// inside the first 44 pt of the 74 pt scrim (0.6), so it is read on clean canvas and not on a
    /// half-faded gold button; the remainder is the soft edge.
    private let topHold: CGFloat = 0.6

    func body(content: Content) -> some View {
        content.overlay {
            GeometryReader { proxy in
                let topHeight = min(proxy.safeAreaInsets.top, statusBarCap) + feather
                let bottomHeight = max(proxy.safeAreaInsets.bottom, tabBarFloor) + 16

                DungeonBackgroundView()
                    .mask {
                        VStack(spacing: 0) {
                            LinearGradient(
                                stops: [
                                    Gradient.Stop(color: .black, location: 0),
                                    Gradient.Stop(color: .black, location: topHold),
                                    Gradient.Stop(color: .black.opacity(0), location: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: topHeight)
                            Spacer(minLength: 0)
                            LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom)
                                .frame(height: bottomHeight)
                        }
                    }
                    // After the mask, not before it: see the note at the top of this file.
                    .ignoresSafeArea()
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

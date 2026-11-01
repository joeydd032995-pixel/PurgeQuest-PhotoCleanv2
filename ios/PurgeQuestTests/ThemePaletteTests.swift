//
//  ThemePaletteTests.swift
//  PurgeQuestTests
//
//  Contrast and stability rules for the Light/Dark palettes, plus the
//  appearance setting. Foundation-only, so these also run in the Linux harness.
//

import Testing
import Foundation
@testable import PurgeQuest

struct ThemePaletteTests {

    // MARK: Contrast math

    @Test func contrastMathMatchesWCAGReferenceValues() {
        let black = ThemeRGB(hex: 0x000000)
        let white = ThemeRGB(hex: 0xFFFFFF)
        #expect(abs(black.contrast(with: white) - 21) < 0.001)
        #expect(abs(white.contrast(with: white) - 1) < 0.001)
        // #777777 on white is the textbook just-failing grey: 4.48:1.
        #expect(abs(ThemeRGB(hex: 0x777777).contrast(with: white) - 4.48) < 0.01)
        // Order must not matter.
        #expect(black.contrast(with: white) == white.contrast(with: black))
    }

    // MARK: Text on surfaces

    @Test(arguments: [false, true])
    func primaryTextClearsAAAOnEverySurface(isDark: Bool) {
        let text = ThemePalette.textPrimary.resolved(isDark: isDark)
        for background in ThemePalette.textBackgrounds {
            let ratio = text.contrast(with: background.pair.resolved(isDark: isDark))
            #expect(ratio >= 7, "textPrimary on \(background.name) is \(ratio) (dark: \(isDark))")
        }
    }

    @Test(arguments: [false, true])
    func secondaryTextClearsAAOnEverySurface(isDark: Bool) {
        let text = ThemePalette.textSecondary.resolved(isDark: isDark)
        for background in ThemePalette.textBackgrounds {
            let ratio = text.contrast(with: background.pair.resolved(isDark: isDark))
            #expect(ratio >= 4.5, "textSecondary on \(background.name) is \(ratio) (dark: \(isDark))")
        }
    }

    @Test(arguments: [false, true])
    func tertiaryHintTextStaysLegibleOnCanvasAndCards(isDark: Bool) {
        let text = ThemePalette.textTertiary.resolved(isDark: isDark)
        for background in [ThemePalette.canvas, ThemePalette.surface] {
            let ratio = text.contrast(with: background.resolved(isDark: isDark))
            #expect(ratio >= 3, "textTertiary is \(ratio) (dark: \(isDark))")
        }
    }

    // MARK: Accents

    @Test func lightAccentsAreTextSafeOnCreamSurfaces() {
        for accent in ThemePalette.textAccents {
            for background in [ThemePalette.canvas, ThemePalette.surface] {
                let ratio = accent.pair.light.contrast(with: background.light)
                #expect(ratio >= 4.5, "light \(accent.name) is \(ratio)")
            }
        }
    }

    @Test func darkAccentsKeepAtLeastTheirOriginalLegibility() {
        // The original dark accents are kept as-is; brick red is the weakest
        // (3.9:1 on cards), so the floor is 3:1. Hues added for the Bestiary
        // families must do better than that.
        let added: Set<String> = ["indigo", "coral", "rose"]
        for accent in ThemePalette.textAccents {
            for background in [ThemePalette.canvas, ThemePalette.surface] {
                let ratio = accent.pair.dark.contrast(with: background.dark)
                #expect(ratio >= (added.contains(accent.name) ? 4.5 : 3), "dark \(accent.name) is \(ratio)")
            }
        }
    }

    @Test(arguments: [false, true])
    func inkOnAccentFillsIsReadable(isDark: Bool) {
        let ink = ThemePalette.onAccent.resolved(isDark: isDark)
        for accent in ThemePalette.textAccents {
            let ratio = ink.contrast(with: accent.pair.resolved(isDark: isDark))
            #expect(ratio >= 4, "onAccent on \(accent.name) is \(ratio) (dark: \(isDark))")
        }
    }

    @Test func deepLightAccentsCarryCreamInk() {
        let ink = ThemePalette.onAccent.light
        for deep in [ThemePalette.amberDeep, ThemePalette.crimsonDeep, ThemePalette.emeraldDeep] {
            #expect(ink.contrast(with: deep.light) >= 7)
        }
    }

    // MARK: Brand gold

    @Test func goldInkIsReadableOnEveryPlateStop() {
        for stop in ThemePalette.Gold.plateStops {
            let ratio = ThemePalette.Gold.ink.contrast(with: stop.color)
            #expect(ratio >= 4.5, "gold ink at \(stop.location) is \(ratio)")
        }
    }

    @Test func plateStopsRunTopToBottomInOrder() {
        let locations = ThemePalette.Gold.plateStops.map(\.location)
        #expect(locations.first == 0 && locations.last == 1)
        #expect(locations == locations.sorted())
        let lum = ThemePalette.Gold.plateStops.map { $0.color.relativeLuminance }
        #expect(lum == lum.sorted(by: >), "the plate should darken toward the bottom edge")
    }

    @Test(arguments: [false, true])
    func wordmarkIsReadableOnTheCanvas(isDark: Bool) {
        let ratio = ThemePalette.goldTitle.resolved(isDark: isDark).contrast(with: ThemePalette.canvas.resolved(isDark: isDark))
        #expect(ratio >= 4.5, "goldTitle is \(ratio) (dark: \(isDark))")
    }

    // MARK: The two modes really differ, and Dark never regressed

    @Test func canvasFlipsBetweenModes() {
        #expect(ThemePalette.canvas.light.relativeLuminance > 0.8)
        #expect(ThemePalette.canvas.dark.relativeLuminance < 0.05)
        #expect(ThemePalette.textPrimary.light.relativeLuminance < ThemePalette.textPrimary.dark.relativeLuminance)
    }

    @Test func darkPaletteIsTheOriginalVerdigrisDeep() {
        func rgb(_ r: Double, _ g: Double, _ b: Double) -> ThemeRGB { ThemeRGB(red: r, green: g, blue: b) }
        #expect(ThemePalette.canvas.dark == rgb(0.047, 0.082, 0.071))
        #expect(ThemePalette.surface.dark == rgb(0.078, 0.129, 0.110))
        #expect(ThemePalette.surfaceRaised.dark == rgb(0.106, 0.165, 0.141))
        #expect(ThemePalette.hairline.dark == rgb(0.149, 0.216, 0.188))
        #expect(ThemePalette.amber.dark == rgb(0.890, 0.702, 0.255))
        #expect(ThemePalette.amberDeep.dark == rgb(0.659, 0.498, 0.157))
        #expect(ThemePalette.crimson.dark == rgb(0.769, 0.357, 0.306))
        #expect(ThemePalette.emerald.dark == rgb(0.239, 0.620, 0.463))
        #expect(ThemePalette.jade.dark == rgb(0.310, 0.769, 0.608))
        #expect(ThemePalette.sapphire.dark == rgb(0.427, 0.608, 0.710))
        #expect(ThemePalette.textPrimary.dark == rgb(0.937, 0.949, 0.937))
        #expect(ThemePalette.textSecondary.dark == rgb(0.576, 0.651, 0.612))
        #expect(ThemePalette.textTertiary.dark == rgb(0.365, 0.435, 0.396))
    }
}

struct AppearanceModeTests {
    @Test func defaultsToSystemWhenNothingIsStored() {
        #expect(AppearanceMode(storedValue: nil) == .system)
        #expect(AppearanceMode(storedValue: "") == .system)
        #expect(AppearanceMode(storedValue: "sepia") == .system)
    }

    @Test func restoresEveryStoredChoice() {
        for mode in AppearanceMode.allCases {
            #expect(AppearanceMode(storedValue: mode.rawValue) == mode)
        }
    }

    @Test func offersSystemLightDarkInThatOrder() {
        #expect(AppearanceMode.allCases == [.system, .light, .dark])
        #expect(AppearanceMode.allCases.map(\.title) == ["System", "Light", "Dark"])
        #expect(AppearanceMode.storageKey == "pq.appearance")
    }
}

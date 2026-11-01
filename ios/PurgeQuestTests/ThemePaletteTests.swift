//
//  ThemePaletteTests.swift
//  PurgeQuestTests
//
//  Contrast and stability rules for both palettes (Classic, Verdigris) in both
//  appearances, plus the appearance and palette settings. Foundation-only, so
//  these also run in the Linux harness.
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

    // MARK: Text on surfaces (every palette, every appearance)

    @Test(arguments: ColorTheme.allCases, [false, true])
    func primaryTextClearsAAAOnEverySurface(theme: ColorTheme, isDark: Bool) {
        let neutrals = ThemePalette.neutrals(for: theme)
        let text = neutrals.textPrimary.resolved(isDark: isDark)
        for background in neutrals.textBackgrounds {
            let ratio = text.contrast(with: background.pair.resolved(isDark: isDark))
            #expect(ratio >= 7, "\(theme) textPrimary on \(background.name) is \(ratio) (dark: \(isDark))")
        }
    }

    @Test(arguments: ColorTheme.allCases, [false, true])
    func secondaryTextClearsAAOnEverySurface(theme: ColorTheme, isDark: Bool) {
        let neutrals = ThemePalette.neutrals(for: theme)
        let text = neutrals.textSecondary.resolved(isDark: isDark)
        for background in neutrals.textBackgrounds {
            let ratio = text.contrast(with: background.pair.resolved(isDark: isDark))
            #expect(ratio >= 4.5, "\(theme) textSecondary on \(background.name) is \(ratio) (dark: \(isDark))")
        }
    }

    @Test(arguments: ColorTheme.allCases, [false, true])
    func tertiaryHintTextStaysLegibleOnCanvasAndCards(theme: ColorTheme, isDark: Bool) {
        let neutrals = ThemePalette.neutrals(for: theme)
        let text = neutrals.textTertiary.resolved(isDark: isDark)
        for background in [neutrals.canvas, neutrals.surface] {
            let ratio = text.contrast(with: background.resolved(isDark: isDark))
            #expect(ratio >= 3, "\(theme) textTertiary is \(ratio) (dark: \(isDark))")
        }
    }

    // MARK: Accents

    @Test(arguments: ColorTheme.allCases)
    func lightAccentsAreTextSafeOnLightSurfaces(theme: ColorTheme) {
        let neutrals = ThemePalette.neutrals(for: theme)
        for accent in ThemePalette.textAccents {
            for background in [neutrals.canvas, neutrals.surface] {
                let ratio = accent.pair.light.contrast(with: background.light)
                #expect(ratio >= 4.5, "\(theme) light \(accent.name) is \(ratio)")
            }
        }
    }

    @Test(arguments: ColorTheme.allCases)
    func darkAccentsKeepAtLeastTheirOriginalLegibility(theme: ColorTheme) {
        // Brick red is the weakest dark accent (about 3.4:1 to 3.9:1 on cards), so
        // the floor is 3:1. Hues added for the Bestiary families must do better.
        let neutrals = ThemePalette.neutrals(for: theme)
        let added: Set<String> = ["indigo", "coral", "rose"]
        for accent in ThemePalette.textAccents {
            for background in [neutrals.canvas, neutrals.surface] {
                let ratio = accent.pair.dark.contrast(with: background.dark)
                #expect(ratio >= (added.contains(accent.name) ? 4.5 : 3), "\(theme) dark \(accent.name) is \(ratio)")
            }
        }
    }

    @Test(arguments: ColorTheme.allCases, [false, true])
    func inkOnAccentFillsIsReadable(theme: ColorTheme, isDark: Bool) {
        let ink = ThemePalette.neutrals(for: theme).onAccent.resolved(isDark: isDark)
        for accent in ThemePalette.textAccents {
            let ratio = ink.contrast(with: accent.pair.resolved(isDark: isDark))
            #expect(ratio >= 4, "\(theme) onAccent on \(accent.name) is \(ratio) (dark: \(isDark))")
        }
    }

    @Test(arguments: ColorTheme.allCases)
    func deepLightAccentsCarryCreamInk(theme: ColorTheme) {
        let ink = ThemePalette.neutrals(for: theme).onAccent.light
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

    @Test(arguments: ColorTheme.allCases, [false, true])
    func wordmarkIsReadableOnTheCanvas(theme: ColorTheme, isDark: Bool) {
        let canvas = ThemePalette.neutrals(for: theme).canvas.resolved(isDark: isDark)
        let ratio = ThemePalette.goldTitle.resolved(isDark: isDark).contrast(with: canvas)
        #expect(ratio >= 4.5, "\(theme) goldTitle is \(ratio) (dark: \(isDark))")
    }

    // MARK: The palettes really differ, and what was kept did not change

    @Test(arguments: ColorTheme.allCases)
    func canvasFlipsBetweenModes(theme: ColorTheme) {
        let neutrals = ThemePalette.neutrals(for: theme)
        #expect(neutrals.canvas.light.relativeLuminance > 0.8)
        #expect(neutrals.canvas.dark.relativeLuminance < 0.05)
        #expect(neutrals.textPrimary.light.relativeLuminance < neutrals.textPrimary.dark.relativeLuminance)
    }

    @Test func classicDarkIsNeutralCharcoalNotGreen() {
        // Charcoal means no green cast: the channels stay within a few steps of each other.
        let neutrals = ThemePalette.classic
        for pair in [neutrals.canvas, neutrals.surface, neutrals.surfaceRaised, neutrals.hairline] {
            let spread = max(pair.dark.red, pair.dark.green, pair.dark.blue) - min(pair.dark.red, pair.dark.green, pair.dark.blue)
            #expect(spread < 0.03, "charcoal channel spread \(spread)")
        }
        // ...and it is clearly different from the green-black it replaces.
        #expect(ThemePalette.classic.canvas.dark != ThemePalette.verdigris.canvas.dark)
        // Surfaces step up in brightness: canvas < surface < raised.
        #expect(neutrals.canvas.dark.relativeLuminance < neutrals.surface.dark.relativeLuminance)
        #expect(neutrals.surface.dark.relativeLuminance < neutrals.surfaceRaised.dark.relativeLuminance)
    }

    @Test func verdigrisDarkIsTheOriginalVerdigrisDeep() {
        func rgb(_ r: Double, _ g: Double, _ b: Double) -> ThemeRGB { ThemeRGB(red: r, green: g, blue: b) }
        let v = ThemePalette.verdigris
        #expect(v.canvas.dark == rgb(0.047, 0.082, 0.071))
        #expect(v.surface.dark == rgb(0.078, 0.129, 0.110))
        #expect(v.surfaceRaised.dark == rgb(0.106, 0.165, 0.141))
        #expect(v.hairline.dark == rgb(0.149, 0.216, 0.188))
        #expect(v.textPrimary.dark == rgb(0.937, 0.949, 0.937))
        #expect(v.textSecondary.dark == rgb(0.576, 0.651, 0.612))
        #expect(v.textTertiary.dark == rgb(0.365, 0.435, 0.396))
    }

    @Test func sharedDarkAccentsAreTheOriginals() {
        func rgb(_ r: Double, _ g: Double, _ b: Double) -> ThemeRGB { ThemeRGB(red: r, green: g, blue: b) }
        #expect(ThemePalette.amber.dark == rgb(0.890, 0.702, 0.255))
        #expect(ThemePalette.amberDeep.dark == rgb(0.659, 0.498, 0.157))
        #expect(ThemePalette.crimson.dark == rgb(0.769, 0.357, 0.306))
        #expect(ThemePalette.emerald.dark == rgb(0.239, 0.620, 0.463))
        #expect(ThemePalette.jade.dark == rgb(0.310, 0.769, 0.608))
        #expect(ThemePalette.sapphire.dark == rgb(0.427, 0.608, 0.710))
    }

    @Test func classicLightIsTheParchmentFromTheMockup() {
        #expect(ThemePalette.classic.canvas.light == ThemeRGB(hex: 0xF4F4EC))
    }

    @Test func everyPaletteResolvesThroughNeutrals() {
        for theme in ColorTheme.allCases {
            let neutrals = ThemePalette.neutrals(for: theme)
            #expect(neutrals.textBackgrounds.count == 3)
        }
        #expect(ThemePalette.neutrals(for: .classic).canvas == ThemePalette.classic.canvas)
        #expect(ThemePalette.neutrals(for: .verdigris).canvas == ThemePalette.verdigris.canvas)
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

struct ColorThemeTests {
    @Test func defaultsToClassicWhenNothingIsStored() {
        #expect(ColorTheme(storedValue: nil) == .classic)
        #expect(ColorTheme(storedValue: "") == .classic)
        #expect(ColorTheme(storedValue: "neon") == .classic)
    }

    @Test func restoresEveryStoredChoice() {
        for theme in ColorTheme.allCases {
            #expect(ColorTheme(storedValue: theme.rawValue) == theme)
        }
    }

    @Test func offersClassicThenVerdigris() {
        #expect(ColorTheme.allCases == [.classic, .verdigris])
        #expect(ColorTheme.allCases.map(\.title) == ["Classic", "Verdigris"])
        #expect(ColorTheme.storageKey == "pq.colorTheme")
        #expect(ColorTheme.allCases.allSatisfy { !$0.summary.isEmpty })
    }

    @Test func storeStartsClassicAndTracksChanges() {
        // A private instance: the shared store is global state other tests may be rendering with.
        let store = ThemeStore()
        #expect(store.current == .classic)
        store.set(.verdigris)
        #expect(store.current == .verdigris)
        store.set(.classic)
        #expect(store.current == .classic)
    }

    @Test func storeIsSafeToUseFromManyThreads() async {
        let store = ThemeStore()
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<200 {
                group.addTask { store.set(i.isMultiple(of: 2) ? .classic : .verdigris); _ = store.current }
            }
        }
        #expect(ColorTheme.allCases.contains(store.current))
    }
}

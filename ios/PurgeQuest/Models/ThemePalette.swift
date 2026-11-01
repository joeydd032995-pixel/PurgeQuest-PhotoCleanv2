//
//  ThemePalette.swift
//  PurgeQuest
//
//  The Light and Dark palettes as plain data. Foundation-only so the contrast
//  rules can be unit tested on any platform; Color+Theme.swift turns each pair
//  into an adaptive SwiftUI Color.
//
//  Dark is the original "Verdigris Deep" palette, unchanged. Light is
//  "Parchment Gold": cream canvas, near-black ink, and deepened accents so
//  every accent that doubles as text keeps 4.5:1 on the cream surfaces.
//

import Foundation

/// An sRGB color with 0...1 components.
struct ThemeRGB: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// 0xRRGGBB.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// WCAG 2.x relative luminance.
    var relativeLuminance: Double {
        func channel(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// WCAG contrast ratio (1...21) against another color, order-independent.
    func contrast(with other: ThemeRGB) -> Double {
        let a = relativeLuminance
        let b = other.relativeLuminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

/// One design token: what it resolves to in each appearance.
struct ThemePair: Equatable, Sendable {
    let light: ThemeRGB
    let dark: ThemeRGB

    init(light: ThemeRGB, dark: ThemeRGB) {
        self.light = light
        self.dark = dark
    }

    init(light: UInt32, dark: ThemeRGB) {
        self.init(light: ThemeRGB(hex: light), dark: dark)
    }

    /// The same color in both appearances.
    init(both color: ThemeRGB) {
        self.init(light: color, dark: color)
    }

    func resolved(isDark: Bool) -> ThemeRGB {
        isDark ? dark : light
    }
}

enum ThemePalette {
    // MARK: Neutrals

    /// Screen canvas.
    static let canvas = ThemePair(light: 0xF4F4EC, dark: ThemeRGB(red: 0.047, green: 0.082, blue: 0.071))
    /// Top of the canvas gradient (a touch off the canvas for depth).
    static let canvasTop = ThemePair(light: 0xF9F9F2, dark: ThemeRGB(red: 0.031, green: 0.059, blue: 0.047))
    /// Cards and panels.
    static let surface = ThemePair(light: 0xFBFAF4, dark: ThemeRGB(red: 0.078, green: 0.129, blue: 0.110))
    /// Wells, stages and raised chips inside a card.
    static let surfaceRaised = ThemePair(light: 0xECE9DB, dark: ThemeRGB(red: 0.106, green: 0.165, blue: 0.141))
    /// Hairline borders.
    static let hairline = ThemePair(light: 0xD9D4C0, dark: ThemeRGB(red: 0.149, green: 0.216, blue: 0.188))

    // MARK: Text

    static let textPrimary = ThemePair(light: 0x1B1B17, dark: ThemeRGB(red: 0.937, green: 0.949, blue: 0.937))
    static let textSecondary = ThemePair(light: 0x5A574A, dark: ThemeRGB(red: 0.576, green: 0.651, blue: 0.612))
    static let textTertiary = ThemePair(light: 0x787464, dark: ThemeRGB(red: 0.365, green: 0.435, blue: 0.396))

    // MARK: Accents (usable as text, icons and tints on the surfaces above)

    static let amber = ThemePair(light: 0x8A6210, dark: ThemeRGB(red: 0.890, green: 0.702, blue: 0.255))
    static let amberDeep = ThemePair(light: 0x6A4A0C, dark: ThemeRGB(red: 0.659, green: 0.498, blue: 0.157))
    static let crimson = ThemePair(light: 0xA93B2E, dark: ThemeRGB(red: 0.769, green: 0.357, blue: 0.306))
    static let crimsonDeep = ThemePair(light: 0x7E2A20, dark: ThemeRGB(red: 0.561, green: 0.243, blue: 0.200))
    static let emerald = ThemePair(light: 0x1F7452, dark: ThemeRGB(red: 0.239, green: 0.620, blue: 0.463))
    static let emeraldDeep = ThemePair(light: 0x14503A, dark: ThemeRGB(red: 0.141, green: 0.333, blue: 0.255))
    /// Verdigris jade. Historic name (`xpViolet`) kept for compatibility.
    static let jade = ThemePair(light: 0x0E7A6C, dark: ThemeRGB(red: 0.310, green: 0.769, blue: 0.608))
    static let sapphire = ThemePair(light: 0x2D6A8E, dark: ThemeRGB(red: 0.427, green: 0.608, blue: 0.710))

    // Bestiary family hues that the older palette did not have.
    static let indigo = ThemePair(light: 0x4A55A8, dark: ThemeRGB(hex: 0x8C97D6))
    static let coral = ThemePair(light: 0xA8452C, dark: ThemeRGB(hex: 0xE0785C))
    static let rose = ThemePair(light: 0xA8353F, dark: ThemeRGB(hex: 0xD9686C))

    /// Ink for text and icons sitting on an accent fill: dark on the bright
    /// Dark-mode accents, cream on the deepened Light-mode ones.
    static let onAccent = ThemePair(light: 0xFFFBF0, dark: canvas.dark)

    /// Wordmark and display titles: deep bronze on cream, bright gold on dark.
    static let goldTitle = ThemePair(light: 0x6B4E1C, dark: amber.dark)

    // MARK: Brand gold plate (identical in both appearances)

    enum Gold {
        /// Ink printed on the gold plate.
        static let ink = ThemeRGB(hex: 0x2D1702)
        /// Outer rim of the plate.
        static let rim = ThemeRGB(hex: 0x8E7440)
        /// Bevel highlight line just inside the rim.
        static let bevel = ThemeRGB(hex: 0xFFF3C9)
        /// Top-to-bottom plate gradient stops.
        static let plateStops: [(color: ThemeRGB, location: Double)] = [
            (ThemeRGB(hex: 0xF2DF8F), 0.00),
            (ThemeRGB(hex: 0xE8CF78), 0.30),
            (ThemeRGB(hex: 0xDCBB6A), 0.60),
            (ThemeRGB(hex: 0xD0A85A), 0.85),
            (ThemeRGB(hex: 0xB98F52), 1.00)
        ]
    }

    // MARK: Reference lists (used by tests and documentation)

    /// Accents that appear as text or icons on canvas/surface in the app.
    static let textAccents: [(name: String, pair: ThemePair)] = [
        ("amber", amber), ("crimson", crimson), ("emerald", emerald), ("jade", jade),
        ("sapphire", sapphire), ("indigo", indigo), ("coral", coral), ("rose", rose)
    ]

    /// Backgrounds that body text sits on.
    static let textBackgrounds: [(name: String, pair: ThemePair)] = [
        ("canvas", canvas), ("surface", surface), ("surfaceRaised", surfaceRaised)
    ]
}

//
//  ColorTheme.swift
//  PurgeQuest
//
//  The palette family, chosen independently of Light/Dark:
//    Classic   charcoal in Dark, parchment in Light (the default)
//    Verdigris the original green-black in Dark, pale sage in Light
//  Accents (gold, jade, crimson, ...) are shared by both.
//

import Foundation

nonisolated enum ColorTheme: String, CaseIterable, Identifiable, Sendable {
    case classic
    case verdigris

    /// UserDefaults / @AppStorage key.
    static let storageKey = "pq.colorTheme"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic:   return "Classic"
        case .verdigris: return "Verdigris"
        }
    }

    /// One line shown under the picker.
    var summary: String {
        switch self {
        case .classic:   return "Charcoal in Dark, parchment in Light."
        case .verdigris: return "Green-black in Dark, pale sage in Light."
        }
    }

    /// Restores a stored value; anything missing or unrecognised falls back to Classic.
    init(storedValue: String?) {
        self = storedValue.flatMap(ColorTheme.init(rawValue:)) ?? .classic
    }
}

/// The palette currently in use, readable from any thread.
///
/// Colour tokens are plain `Color` values rather than environment-driven, so the
/// app publishes the chosen palette here (see `ContentView`) before building the
/// views that read it. Tests make their own instance instead of touching `shared`.
nonisolated final class ThemeStore: @unchecked Sendable {
    static let shared = ThemeStore()

    private let lock = NSLock()
    private var theme: ColorTheme

    init(_ initial: ColorTheme = .classic) {
        theme = initial
    }

    var current: ColorTheme {
        lock.lock()
        defer { lock.unlock() }
        return theme
    }

    func set(_ newValue: ColorTheme) {
        lock.lock()
        theme = newValue
        lock.unlock()
    }
}

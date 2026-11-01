//
//  AppearanceMode.swift
//  PurgeQuest
//
//  The user's Light/Dark choice. "System" follows the device setting and is
//  the default; the other two pin the app regardless of the device.
//

import Foundation

enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    /// UserDefaults / @AppStorage key.
    static let storageKey = "pq.appearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    /// Restores a stored value; anything missing or unrecognised falls back to System.
    init(storedValue: String?) {
        self = storedValue.flatMap(AppearanceMode.init(rawValue:)) ?? .system
    }
}

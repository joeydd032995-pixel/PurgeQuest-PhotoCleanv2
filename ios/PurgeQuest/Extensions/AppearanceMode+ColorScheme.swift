//
//  AppearanceMode+ColorScheme.swift
//  PurgeQuest
//

import SwiftUI

extension AppearanceMode {
    /// What to hand `preferredColorScheme`: nil follows the device setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

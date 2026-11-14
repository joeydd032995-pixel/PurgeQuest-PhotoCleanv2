//
//  SystemSettings.swift
//  PurgeQuest
//
//  The one place the app opens its own page in the iOS Settings app. Photo access, once refused,
//  can only be turned back on there, so every screen that reports a refusal offers this.
//

import UIKit

enum SystemSettings {
    /// Opens this app's page in Settings. Does nothing if the system gives no URL for it.
    @MainActor
    static func open() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

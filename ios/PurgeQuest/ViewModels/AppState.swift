//
//  AppState.swift
//  PurgeQuest
//

import Foundation
import SwiftUI
import Photos

enum AppPhase {
    case launching
    case onboarding
    case main
}

enum MainTab: Hashable {
    case dashboard, hero, bestiary, achievements, shop, settings
}

@Observable
final class AppState {
    var phase: AppPhase = .launching
    var selectedTab: MainTab = .dashboard
    var photoAuthStatus: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    var includeVideos: Bool = true
    var videoOnlyMode: Bool = false
    var hasOnboarded: Bool = UserDefaults.standard.bool(forKey: "pq.hasOnboarded")

    /// Triggered when the user taps "Enter Dungeon" from the dashboard.
    var combatRequested: Bool = false

    func completeOnboarding() {
        hasOnboarded = true
        UserDefaults.standard.set(true, forKey: "pq.hasOnboarded")
        phase = .main
    }

    @MainActor
    func refreshPhotoAuth() async {
        let svc = PhotoLibraryService.shared
        let current = svc.authorizationStatus
        if current == .notDetermined {
            photoAuthStatus = await svc.requestAuthorization()
        } else {
            photoAuthStatus = current
        }
    }
}

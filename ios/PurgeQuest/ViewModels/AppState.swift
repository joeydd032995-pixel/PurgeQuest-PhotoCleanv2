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

    /// PHAsset localIdentifiers hand-picked from the Photos picker for a
    /// targeted hunt; consumed (and cleared) by the next CombatView bootstrap.
    var pickedAssetIDs: [String] = []

    /// The kind of clutter the next dive leans toward, set by the dashboard's Focused Dive menu and
    /// consumed (and cleared on exit) by CombatView. Nil is the default mixed dive.
    var diveFocus: RoomBucket? = nil

    /// The capture dates dives draw from (see DateScope): all dates, only a range, or everything but a
    /// range. A standing setting, unlike `diveFocus`: it outlives a dive and a relaunch, and the
    /// Dashboard shows it for as long as it is on. Hand-picked hunts ignore it. Change it with
    /// `setDateScope`, which also saves it.
    private(set) var dateScope: DateScope

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // A screenshot tour can force a range (in memory only); otherwise it is the saved one.
        self.dateScope = UITestSupport.forcedDateScope ?? DateScopeStore.load(from: defaults)
    }

    func setDateScope(_ scope: DateScope) {
        dateScope = scope
        DateScopeStore.save(scope, to: defaults)
    }

    func completeOnboarding() {
        hasOnboarded = true
        UserDefaults.standard.set(true, forKey: "pq.hasOnboarded")
        phase = .main
    }

    /// What the app may do with the photo library, in the terms the screens need (see PhotoAccess).
    var photoAccess: PhotoAccess { PhotoAccess(status: photoAuthStatus) }

    /// Asks for access if it has never been asked for, which shows the system prompt, and otherwise
    /// just reads it. Call this only from a control the player pressed, after being told why.
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

    /// Reads the current photo authorization and never shows the prompt. Call it at launch and when the
    /// app returns to the foreground: the player may have changed the setting while away. A screenshot
    /// tour holds its own forced status, which this must not overwrite.
    @MainActor
    func syncPhotoAuth() {
        guard !UITestSupport.isTour else { return }
        photoAuthStatus = PhotoLibraryService.shared.authorizationStatus
    }
}

extension PhotoAccess {
    /// The access a `PHAuthorizationStatus` stands for.
    init(status: PHAuthorizationStatus) {
        self.init(rawStatus: status.rawValue)
    }
}

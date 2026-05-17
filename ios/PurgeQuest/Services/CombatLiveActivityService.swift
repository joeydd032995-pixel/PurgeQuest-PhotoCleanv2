//
//  CombatLiveActivityService.swift
//  PurgeQuest
//
//  ActivityKit attributes + service for the active combat session.
//
//  Activity rendering UI lives in a Widget Extension target (added in
//  a future build pass). Once that target is added and includes these
//  same `CombatActivityAttributes` types, activities started here will
//  render on the Lock Screen and Dynamic Island automatically.
//

import Foundation
#if canImport(ActivityKit)
import ActivityKit

struct CombatActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var heroHP: Int
        var heroMaxHP: Int
        var combo: Int
        var roomNumber: Int
        var totalRooms: Int
        var monstersRemaining: Int
        var mbFreed: Double
    }
    var heroName: String
    var sessionStart: Date
}
#endif

@MainActor
final class CombatLiveActivityService {
    static let shared = CombatLiveActivityService()
    private init() {}

    #if canImport(ActivityKit)
    private var activity: Activity<CombatActivityAttributes>?
    #endif

    var isAvailable: Bool {
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        #endif
        return false
    }

    func start(heroName: String) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *), isAvailable, activity == nil else { return }
        let attrs = CombatActivityAttributes(heroName: heroName, sessionStart: .now)
        let initial = CombatActivityAttributes.ContentState(
            heroHP: 100, heroMaxHP: 100, combo: 0,
            roomNumber: 1, totalRooms: 5, monstersRemaining: 0, mbFreed: 0
        )
        do {
            activity = try Activity.request(
                attributes: attrs,
                content: .init(state: initial, staleDate: nil),
                pushType: nil
            )
        } catch {
            // Silent — Live Activity entitlement / widget target may be absent.
        }
        #endif
    }

    func update(heroHP: Int, heroMaxHP: Int, combo: Int, room: Int, total: Int, remaining: Int, mb: Double) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *), let activity else { return }
        let state = CombatActivityAttributes.ContentState(
            heroHP: heroHP, heroMaxHP: heroMaxHP, combo: combo,
            roomNumber: room, totalRooms: total, monstersRemaining: remaining,
            mbFreed: mb
        )
        Task { await activity.update(.init(state: state, staleDate: nil)) }
        #endif
    }

    func end() {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *), let activity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        self.activity = nil
        #endif
    }
}

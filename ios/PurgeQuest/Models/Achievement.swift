//
//  Achievement.swift
//  PurgeQuest
//

import Foundation
import SwiftData

@Model
final class Achievement {
    @Attribute(.unique) var id: String
    var title: String
    var subtitle: String
    var iconName: String
    var goal: Int
    var progress: Int
    var isUnlocked: Bool
    var unlockedAt: Date?

    init(id: String, title: String, subtitle: String, iconName: String, goal: Int) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.goal = goal
        self.progress = 0
        self.isUnlocked = false
        self.unlockedAt = nil
    }
}

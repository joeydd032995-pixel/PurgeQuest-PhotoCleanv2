//
//  Quest.swift
//  PurgeQuest
//

import Foundation
import SwiftData

@Model
final class Quest {
    @Attribute(.unique) var id: UUID
    var title: String
    var subtitle: String
    var kindRaw: String
    var monsterTypeRaw: String?    // optional filter
    var targetCount: Int
    var currentCount: Int
    var rewardXP: Int
    var rewardGems: Int
    var expiresAt: Date
    var completed: Bool

    var kind: QuestKind { QuestKind(rawValue: kindRaw) ?? .anySlay }
    var monsterType: MonsterType? {
        guard let raw = monsterTypeRaw else { return nil }
        return MonsterType(rawValue: raw)
    }

    var progressFraction: Double {
        guard targetCount > 0 else { return 0 }
        return min(1.0, Double(currentCount) / Double(targetCount))
    }

    init(title: String, subtitle: String, kind: QuestKind, monsterType: MonsterType?, targetCount: Int, rewardXP: Int, rewardGems: Int, durationDays: Int = 1) {
        self.id = UUID()
        self.title = title
        self.subtitle = subtitle
        self.kindRaw = kind.rawValue
        self.monsterTypeRaw = monsterType?.rawValue
        self.targetCount = targetCount
        self.currentCount = 0
        self.rewardXP = rewardXP
        self.rewardGems = rewardGems
        self.expiresAt = Calendar.current.date(byAdding: .day, value: durationDays, to: Date()) ?? Date().addingTimeInterval(86_400)
        self.completed = false
    }

    /// A fresh quest from the catalog (see QuestCatalog in GameContent.swift).
    convenience init(template: QuestTemplate) {
        self.init(title: template.title, subtitle: template.subtitle, kind: template.kind,
                  monsterType: template.monsterType, targetCount: template.targetCount,
                  rewardXP: template.rewardXP, rewardGems: template.rewardGems)
    }
}

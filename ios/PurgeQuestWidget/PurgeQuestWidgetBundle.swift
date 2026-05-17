//
//  PurgeQuestWidgetBundle.swift
//  PurgeQuestWidget
//

import WidgetKit
import SwiftUI

@main
struct PurgeQuestWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyQuestWidget()
        StreakWidget()
        LockScreenGemWidget()
        LockScreenStreakWidget()
    }
}

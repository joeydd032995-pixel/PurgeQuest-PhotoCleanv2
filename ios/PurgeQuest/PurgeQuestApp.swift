//
//  PurgeQuestApp.swift
//  PurgeQuest
//

import SwiftUI
import SwiftData

@main
struct PurgeQuestApp: App {

    @State private var appState = AppState()

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Hero.self,
            Achievement.self,
            CosmeticItem.self,
            Quest.self,
            DeletedMediaRecord.self,
            CombatSession.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Fallback to in-memory if disk fails (corrupt store, etc.)
            do {
                let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
    }
}

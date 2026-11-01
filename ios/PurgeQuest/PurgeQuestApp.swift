//
//  PurgeQuestApp.swift
//  PurgeQuest
//

import SwiftUI
import SwiftData

@main
struct PurgeQuestApp: App {

    init() {
        DungeonFont.registerAll()
    }

    @State private var appState = AppState()

    /// Light / Dark / System. Changed in Settings; System follows the device.
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue

    let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Hero.self,
            Achievement.self,
            CosmeticItem.self,
            Quest.self,
            DeletedMediaRecord.self,
            CombatSession.self,
            SparedMediaRecord.self,
            MediaFingerprintRecord.self,
            MonsterSightingRecord.self
        ])
        // UI tests run against an in-memory store so they never touch real data.
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: CommandLine.arguments.contains("-UITestForge") || UITestSupport.isTour)
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
            Group {
                #if DEBUG
                if CommandLine.arguments.contains("-UITestForge") {
                    ForgeUITestRoot()
                } else {
                    ContentView()
                }
                #else
                ContentView()
                #endif
            }
            .environment(appState)
            .preferredColorScheme(AppearanceMode(storedValue: appearanceRaw).colorScheme)
        }
        .modelContainer(sharedModelContainer)
    }
}

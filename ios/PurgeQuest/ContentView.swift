//
//  ContentView.swift
//  PurgeQuest
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    var body: some View {
        ZStack {
            switch appState.phase {
            case .launching:
                splash
            case .onboarding:
                OnboardingView()
                    .transition(.opacity)
            case .main:
                main
                    .transition(.opacity)
            }
        }
        .task { await bootstrap() }
    }

    private var splash: some View {
        SplashView()
    }

    private var main: some View {
        @Bindable var appState = appState
        return TabView(selection: $appState.selectedTab) {
            NavigationStack {
                DashboardView()
                    .navigationDestination(isPresented: Binding(
                        get: { appState.combatRequested },
                        set: { appState.combatRequested = $0 }
                    )) {
                        CombatView()
                    }
            }
            .tabItem { Label("Library", systemImage: "photo.stack") }
            .tag(MainTab.dashboard)

            NavigationStack { HeroTabView() }
                .tabItem { Label("Hero", systemImage: "figure.fencing") }
                .tag(MainTab.hero)

            NavigationStack { BestiaryView() }
                .tabItem { Label("Bestiary", systemImage: "book.closed.fill") }
                .tag(MainTab.bestiary)

            NavigationStack { ShopView() }
                .tabItem { Label("Armory", systemImage: "shield.lefthalf.filled") }
                .tag(MainTab.shop)

            NavigationStack { AchievementsView() }
                .tabItem { Label("Trophies", systemImage: "trophy") }
                .tag(MainTab.achievements)

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(MainTab.settings)
        }
        .tint(.questAmber)
    }

    private func bootstrap() async {
        // Seed data
        GameDataService.seedAchievementsIfNeeded(in: modelContext)
        GameDataService.seedCosmeticsIfNeeded(in: modelContext)
        GameDataService.refreshDailyQuestsIfNeeded(in: modelContext)

        // Hero — apply onboarding choices if first launch
        let hero = GameDataService.loadOrCreateHero(in: modelContext)
        if let className = UserDefaults.standard.string(forKey: "pq.selectedClass") {
            let cls = HeroClass(rawValue: className) ?? HeroClass.legacyClass(forRaw: className)
            if let cls { hero.heroClass = cls }
        }
        if let raceRaw = UserDefaults.standard.string(forKey: "pq.race") {
            // legacyRaw migrates the removed Skeleton Warrior pack.
            hero.race = HeroRace(legacyRaw: raceRaw)
        }
        // Apply the look drafted during onboarding once, then clear it so
        // later Forge edits always win.
        if let lookData = UserDefaults.standard.data(forKey: "pq.appearanceDraft") {
            hero.appearance = HeroAppearance.decode(lookData, for: hero.archetype)
            UserDefaults.standard.removeObject(forKey: "pq.appearanceDraft")
        }
        if let archetypeRaw = UserDefaults.standard.string(forKey: "pq.archetype"),
           let archetype = CharacterArchetype(rawValue: archetypeRaw) {
            hero.archetype = archetype
        }
        if let name = UserDefaults.standard.string(forKey: "pq.heroName"), !name.isEmpty {
            hero.name = name
        }
        try? modelContext.save()

        // Bring achievement progress in line with lifetime stats and the deletion log.
        GameDataService.syncAchievements(hero: hero, in: modelContext)

        // Screenshot tours skip the permission prompt and stop on a chosen screen.
        if UITestSupport.isTour {
            appState.photoAuthStatus = .authorized
            if let phase = UITestSupport.requestedPhase, phase != .launching {
                appState.phase = phase
            }
            return
        }

        // Determine phase
        await appState.refreshPhotoAuth()
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.easeInOut(duration: 0.4)) {
            appState.phase = appState.hasOnboarded ? .main : .onboarding
        }
    }
}

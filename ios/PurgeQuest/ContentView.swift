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
        .preferredColorScheme(.dark)
        .task { await bootstrap() }
    }

    private var splash: some View {
        ZStack {
            DungeonBackgroundView()
            VStack(spacing: 20) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.questAmber)
                    .frame(width: 116, height: 116)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.dungeonStone)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.questAmber.opacity(0.6), lineWidth: 1))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.questAmber.opacity(0.3), lineWidth: 1).padding(3))
                    )
                Text("PurgeQuest")
                    .font(.dungeonTitle)
                    .foregroundStyle(.textPrimary)
                ProgressView().tint(.questAmber)
            }
        }
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
        if let className = UserDefaults.standard.string(forKey: "pq.selectedClass"),
           let cls = HeroClass(rawValue: className) {
            hero.heroClass = cls
        }
        if let archetypeRaw = UserDefaults.standard.string(forKey: "pq.archetype"),
           let archetype = CharacterArchetype(rawValue: archetypeRaw) {
            hero.archetype = archetype
        }
        if let name = UserDefaults.standard.string(forKey: "pq.heroName"), !name.isEmpty {
            hero.name = name
        }
        try? modelContext.save()

        // Determine phase
        await appState.refreshPhotoAuth()
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.easeInOut(duration: 0.4)) {
            appState.phase = appState.hasOnboarded ? .main : .onboarding
        }
    }
}

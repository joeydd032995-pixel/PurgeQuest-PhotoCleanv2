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
        @Bindable var appState = appState
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
            DungeonBackgroundView(intensity: 0.4)
            VStack(spacing: 18) {
                Image(systemName: "sword.fill")
                    .font(.system(size: 90, weight: .bold))
                    .foregroundStyle(LinearGradient.amberGlow)
                    .symbolRenderingMode(.hierarchical)
                    .shadow(color: .questAmber.opacity(0.7), radius: 20)
                Text("PurgeQuest")
                    .font(.system(size: 44, weight: .black, design: .serif))
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
            .tabItem { Label("Dungeon", systemImage: "shield.lefthalf.filled") }
            .tag(MainTab.dashboard)

            NavigationStack { AchievementsView() }
                .tabItem { Label("Trophies", systemImage: "trophy.fill") }
                .tag(MainTab.achievements)

            NavigationStack { ShopView() }
                .tabItem { Label("Shop", systemImage: "cart.fill") }
                .tag(MainTab.shop)

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
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

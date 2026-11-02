//
//  ContentView.swift
//  PurgeQuest
//

import SwiftUI
import SwiftData
import Photos

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    /// Classic or Verdigris, chosen in Settings.
    @AppStorage(ColorTheme.storageKey) private var colorThemeRaw = ColorTheme.classic.rawValue

    /// The palette to render with. Publishing it before any child view builds is what
    /// lets the color tokens (plain Colors, not environment values) pick it up.
    private var colorTheme: ColorTheme {
        let theme = ColorTheme(storedValue: colorThemeRaw)
        ThemeStore.shared.set(theme)
        return theme
    }

    var body: some View {
        // Reading the palette here publishes it before any view below is built, and makes
        // this body re-run when the setting changes (each tab then rebuilds; see `main`).
        // The launch task stays on this stable container, so it does not re-run.
        _ = colorTheme
        return ZStack {
            phaseContent
        }
        .task { await bootstrap() }
    }

    @ViewBuilder
    private var phaseContent: some View {
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

    private var splash: some View {
        SplashView()
    }

    private var main: some View {
        @Bindable var appState = appState
        // Each tab's stack is keyed by the palette, so changing it repaints that tab (and
        // returns its stack to the root). The TabView itself is kept, so the selected tab,
        // including one folded under "More" such as Settings, stays where it is.
        let theme = colorTheme
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
            .id(theme)
            .tabItem { Label("Library", systemImage: "photo.stack") }
            .tag(MainTab.dashboard)

            NavigationStack { HeroTabView() }
                .id(theme)
                .tabItem { Label("Hero", systemImage: "figure.fencing") }
                .tag(MainTab.hero)

            NavigationStack { BestiaryView() }
                .id(theme)
                .tabItem { Label("Bestiary", systemImage: "book.closed.fill") }
                .tag(MainTab.bestiary)

            NavigationStack { ShopView() }
                .id(theme)
                .tabItem { Label("Armory", systemImage: "shield.lefthalf.filled") }
                .tag(MainTab.shop)

            NavigationStack { AchievementsView() }
                .id(theme)
                .tabItem { Label("Trophies", systemImage: "trophy") }
                .tag(MainTab.achievements)

            NavigationStack { SettingsView() }
                .id(theme)
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(MainTab.settings)
        }
        .tint(.questAmber)
    }

    private func bootstrap() async {
        // Seed the catalogs, make sure a hero exists, and apply any saved onboarding choices.
        // This only runs at launch; onboarding provisions again when it finishes, because
        // "Reset all PurgeQuest data" empties the store without relaunching the app.
        GameDataService.provision(in: modelContext)

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

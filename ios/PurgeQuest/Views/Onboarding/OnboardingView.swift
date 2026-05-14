//
//  OnboardingView.swift
//  PurgeQuest
//

import SwiftUI
import Photos

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var pageIndex: Int = 0
    @State private var requestingPermission: Bool = false
    @State private var selectedClass: HeroClass = .purgeKnight
    @State private var heroName: String = ""

    private let totalPages = 4

    var body: some View {
        ZStack {
            DungeonBackgroundView(intensity: Double(pageIndex) / Double(totalPages - 1))

            VStack(spacing: 0) {
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { i in
                        Capsule()
                            .fill(i == pageIndex ? Color.questAmber : Color.dungeonAsh)
                            .frame(width: i == pageIndex ? 24 : 8, height: 6)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: pageIndex)
                    }
                }
                .padding(.top, 16)

                TabView(selection: $pageIndex) {
                    introPage.tag(0)
                    permissionPage.tag(1)
                    classPage.tag(2)
                    swipeTutorialPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: pageIndex)

                bottomBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Pages

    private var introPage: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack {
                Circle()
                    .fill(LinearGradient.amberGlow)
                    .frame(width: 180, height: 180)
                    .blur(radius: 60)
                Image(systemName: "sword.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .foregroundStyle(LinearGradient.amberGlow)
                    .symbolRenderingMode(.hierarchical)
                    .shadow(color: .questAmber.opacity(0.6), radius: 20)
            }
            VStack(spacing: 12) {
                Text("PurgeQuest")
                    .font(.system(size: 44, weight: .black, design: .serif))
                    .foregroundStyle(.textPrimary)
                Text("Your Camera Roll is a Dungeon.\nPhotos and videos hide as monsters.\nWill you slay them all?")
                    .font(.headline)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Spacer()
        }
    }

    private var permissionPage: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundStyle(LinearGradient.amberGlow)
                .symbolRenderingMode(.hierarchical)
            Text("Unlock the Dungeon")
                .font(.title.weight(.bold))
                .foregroundStyle(.textPrimary)
            Text("PurgeQuest needs Full Photo Library access to summon monsters from your photos AND videos. Items you choose to delete are moved to **Recently Deleted** in Photos — you can restore them for 30 days.")
                .font(.callout)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            statusChip

            Button {
                Task {
                    requestingPermission = true
                    await appState.refreshPhotoAuth()
                    requestingPermission = false
                }
            } label: {
                HStack {
                    if requestingPermission { ProgressView().tint(.dungeonVoid) }
                    Text(appState.photoAuthStatus == .notDetermined ? "Grant Photo Library Access" : "Update Permissions")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(LinearGradient.amberGlow, in: Capsule())
                .foregroundStyle(.dungeonVoid)
                .shadow(color: .questAmber.opacity(0.5), radius: 16)
            }
            .padding(.horizontal, 24)
            .disabled(requestingPermission)
            Spacer()
        }
    }

    private var statusChip: some View {
        let (text, tint): (String, Color) = {
            switch appState.photoAuthStatus {
            case .authorized: return ("✓ Full access — ready to fight", .gemEmerald)
            case .limited: return ("⚠ Limited access — some monsters won't appear", .questAmber)
            case .denied, .restricted: return ("✗ Denied — open Settings to enable", .combatCrimson)
            case .notDetermined: return ("Awaiting permission", .textSecondary)
            @unknown default: return ("Unknown", .textSecondary)
            }
        }()
        return Text(text)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(tint.opacity(0.15)).overlay(Capsule().stroke(tint.opacity(0.5), lineWidth: 1)))
            .foregroundStyle(tint)
    }

    private var classPage: some View {
        VStack(spacing: 16) {
            Text("Choose Your Class")
                .font(.title.weight(.bold))
                .foregroundStyle(.textPrimary)
                .padding(.top, 24)
            Text("Each class grants a passive bonus.")
                .font(.callout)
                .foregroundStyle(.textSecondary)

            TextField("Hero name", text: $heroName)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.dungeonStone, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dungeonAsh, lineWidth: 1))
                .padding(.horizontal, 24)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(HeroClass.allCases, id: \.self) { hc in
                        classRow(hc)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
            }
        }
    }

    private func classRow(_ hc: HeroClass) -> some View {
        let selected = selectedClass == hc
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedClass = hc
            }
            HapticsService.shared.light()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: hc.symbol)
                    .font(.title2)
                    .foregroundStyle(selected ? Color.dungeonVoid : Color.questAmber)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle().fill(selected ? AnyShapeStyle(LinearGradient.amberGlow) : AnyShapeStyle(Color.dungeonStoneLight))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(hc.displayName)
                        .font(.headline)
                        .foregroundStyle(.textPrimary)
                    Text(hc.perkDescription)
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.gemEmerald)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.dungeonStone)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Color.questAmber : Color.dungeonAsh, lineWidth: selected ? 2 : 1))
            )
        }
        .buttonStyle(.plain)
    }

    private var swipeTutorialPage: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("How to Fight")
                .font(.title.weight(.bold))
                .foregroundStyle(.textPrimary)
            Text("Each monster appears as a card.\nSwipe to choose its fate.")
                .font(.callout)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)

            // Animated demo
            DemoSwipeCard()
                .frame(height: 320)
                .padding(.horizontal, 30)

            HStack(spacing: 10) {
                Label("Swipe ← to DELETE", systemImage: "arrow.left")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.combatCrimson)
                    .padding(.vertical, 8).padding(.horizontal, 12)
                    .background(Capsule().fill(Color.combatCrimson.opacity(0.12)).overlay(Capsule().stroke(Color.combatCrimson.opacity(0.5), lineWidth: 1)))
                Label("Swipe → to SPARE", systemImage: "arrow.right")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.gemEmerald)
                    .padding(.vertical, 8).padding(.horizontal, 12)
                    .background(Capsule().fill(Color.gemEmerald.opacity(0.12)).overlay(Capsule().stroke(Color.gemEmerald.opacity(0.5), lineWidth: 1)))
            }
            Spacer()
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack {
            if pageIndex > 0 {
                Button {
                    withAnimation { pageIndex = max(0, pageIndex - 1) }
                } label: {
                    Text("Back").foregroundStyle(.textSecondary)
                }
            }
            Spacer()
            Button {
                advance()
            } label: {
                HStack(spacing: 6) {
                    Text(pageIndex == totalPages - 1 ? "Enter the Dungeon" : "Continue")
                    Image(systemName: "arrow.right")
                }
                .font(.headline)
                .padding(.vertical, 12).padding(.horizontal, 18)
                .background(LinearGradient.amberGlow, in: Capsule())
                .foregroundStyle(.dungeonVoid)
                .shadow(color: .questAmber.opacity(0.5), radius: 10)
            }
            .disabled(pageIndex == 1 && (appState.photoAuthStatus != .authorized && appState.photoAuthStatus != .limited))
            .opacity((pageIndex == 1 && (appState.photoAuthStatus != .authorized && appState.photoAuthStatus != .limited)) ? 0.4 : 1.0)
        }
    }

    private func advance() {
        if pageIndex < totalPages - 1 {
            withAnimation { pageIndex += 1 }
        } else {
            // Persist hero choices via UserDefaults; the actual Hero is created lazily.
            UserDefaults.standard.set(selectedClass.rawValue, forKey: "pq.selectedClass")
            let trimmed = heroName.trimmingCharacters(in: .whitespaces)
            UserDefaults.standard.set(trimmed.isEmpty ? "Hero" : trimmed, forKey: "pq.heroName")
            appState.completeOnboarding()
        }
    }
}

// MARK: - Tutorial demo

private struct DemoSwipeCard: View {
    @State private var offset: CGFloat = 0
    @State private var animateRight: Bool = false

    var body: some View {
        ZStack {
            // Static placeholder card
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [.dungeonStoneLight, .dungeonStone], startPoint: .top, endPoint: .bottom))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.questAmber.opacity(0.5), lineWidth: 1.5)
                )
                .overlay(
                    VStack(spacing: 12) {
                        Image(systemName: "drop.halffull")
                            .font(.system(size: 70, weight: .bold))
                            .foregroundStyle(LinearGradient.amberGlow)
                        Text("Blur Beast")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.textPrimary)
                        Text("4.2 MB · 3 yr ago")
                            .font(.caption)
                            .foregroundStyle(.textSecondary)
                    }
                )
                .offset(x: offset)
                .rotationEffect(.degrees(Double(offset / 20)))
                .shadow(color: .black.opacity(0.5), radius: 18, y: 8)
                .onAppear {
                    Task { await loop() }
                }
        }
    }

    private func loop() async {
        while true {
            try? await Task.sleep(for: .seconds(1.0))
            await MainActor.run {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    offset = animateRight ? 140 : -140
                }
            }
            try? await Task.sleep(for: .seconds(0.8))
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { offset = 0 }
                animateRight.toggle()
            }
        }
    }
}

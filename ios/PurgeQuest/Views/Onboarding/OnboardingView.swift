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
    @State private var selectedArchetype: CharacterArchetype = .knight
    @State private var heroName: String = ""

    private let totalPages = 5

    var body: some View {
        ZStack {
            DungeonBackgroundView()

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3)
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
                    characterPage.tag(3)
                    swipeTutorialPage.tag(4)
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
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(.questAmber)
                .frame(width: 112, height: 112)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dungeonStone)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.questAmber.opacity(0.6), lineWidth: 1))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.questAmber.opacity(0.3), lineWidth: 1).padding(3))
                )
            VStack(spacing: 12) {
                Text("PurgeQuest")
                    .font(.dungeonTitle)
                    .foregroundStyle(.textPrimary)
                Text("Your library is a dungeon.\nPhotos and videos hide as monsters.\nClear the depths and reclaim your storage.")
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
                .frame(width: 84, height: 84)
                .foregroundStyle(.questAmber)
            Text("Unlock the Dungeon")
                .font(.dungeonHeader)
                .foregroundStyle(.textPrimary)
            Text("PurgeQuest needs full photo library access to review your photos and videos. Items you choose to delete are moved to **Recently Deleted** in Photos. You can restore them for 30 days.")
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
                        .font(.dungeonHeader)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.questAmber)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.questAmberDeep, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.dungeonVoid)
            }
            .padding(.horizontal, 24)
            .disabled(requestingPermission)
            Spacer()
        }
    }

    private var statusChip: some View {
        let (text, symbol, tint): (String, String, Color) = {
            switch appState.photoAuthStatus {
            case .authorized: return ("Full access", "checkmark.circle.fill", .gemEmerald)
            case .limited: return ("Limited access. Some items won't appear", "exclamationmark.triangle.fill", .questAmber)
            case .denied, .restricted: return ("Access denied. Open Settings to enable", "xmark.circle.fill", .combatCrimson)
            case .notDetermined: return ("Awaiting permission", "circle.dashed", .textSecondary)
            @unknown default: return ("Unknown", "questionmark.circle", .textSecondary)
            }
        }()
        return Label(text, systemImage: symbol)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(tint.opacity(0.15)).overlay(RoundedRectangle(cornerRadius: 8).stroke(tint.opacity(0.5), lineWidth: 1)))
            .foregroundStyle(tint)
    }

    private var classPage: some View {
        VStack(spacing: 16) {
            Text("Choose Your Class")
                .font(.dungeonTitle)
                .foregroundStyle(.textPrimary)
                .padding(.top, 24)
            Text("Each class grants a passive bonus.")
                .font(.callout)
                .foregroundStyle(.textSecondary)

            TextField("Hero name", text: $heroName)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.dungeonStone, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1))
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

    private var characterPage: some View {
        VStack(spacing: 16) {
            Text("Choose Your Character")
                .font(.dungeonTitle)
                .foregroundStyle(.textPrimary)
                .padding(.top, 24)
            Text("Who ventures into the dungeon?")
                .font(.callout)
                .foregroundStyle(.textSecondary)

            VStack(spacing: 14) {
                ForEach(CharacterArchetype.allCases, id: \.self) { arch in
                    characterCard(arch)
                }
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    private func characterCard(_ arch: CharacterArchetype) -> some View {
        let selected = selectedArchetype == arch
        let tint: Color = arch == .knight ? .questAmber : .xpViolet
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedArchetype = arch
            }
            HapticsService.shared.light()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: arch.symbol)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 64, height: 64)
                    .background(
                        Circle()
                            .fill(tint.opacity(0.14))
                            .overlay(Circle().stroke(tint.opacity(selected ? 0.8 : 0.4), lineWidth: 1.5))
                            .overlay(Circle().stroke(tint.opacity(selected ? 0.4 : 0.2), lineWidth: 1).padding(4))
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(arch.displayName)
                        .font(.dungeonHeader)
                        .foregroundStyle(.textPrimary)
                    Text(arch.tagline)
                        .font(.callout)
                        .foregroundStyle(.textSecondary)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(tint)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dungeonStone)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selected ? tint : Color.dungeonAsh, lineWidth: selected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
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
                        RoundedRectangle(cornerRadius: 10).fill(selected ? AnyShapeStyle(Color.questAmber) : AnyShapeStyle(Color.dungeonStoneLight))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.questAmberDeep : Color.dungeonAsh, lineWidth: 1))
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
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.dungeonStone)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.questAmber : Color.dungeonAsh, lineWidth: selected ? 2 : 1))
            )
        }
        .buttonStyle(.plain)
    }

    private var swipeTutorialPage: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("How to Review")
                .font(.dungeonTitle)
                .foregroundStyle(.textPrimary)
            Text("Each item appears as a card.\nSwipe to choose its fate.")
                .font(.callout)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)

            DemoSwipeCard()
                .frame(height: 320)
                .padding(.horizontal, 30)

            HStack(spacing: 10) {
                Label("Swipe left to delete", systemImage: "arrow.left")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.combatCrimson)
                    .padding(.vertical, 8).padding(.horizontal, 12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.combatCrimson.opacity(0.12)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.combatCrimson.opacity(0.5), lineWidth: 1)))
                Label("Swipe right to spare", systemImage: "arrow.right")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.gemEmerald)
                    .padding(.vertical, 8).padding(.horizontal, 12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.gemEmerald.opacity(0.12)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gemEmerald.opacity(0.5), lineWidth: 1)))
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
                Text(pageIndex == totalPages - 1 ? "Enter the Dungeon" : "Continue")
                    .font(.dungeonHeader)
                    .padding(.vertical, 12).padding(.horizontal, 18)
                    .background(Color.questAmber)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.questAmberDeep, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.dungeonVoid)
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
            UserDefaults.standard.set(selectedArchetype.rawValue, forKey: "pq.archetype")
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
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dungeonStoneLight)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.questAmber.opacity(0.5), lineWidth: 1.5)
                )
                .overlay(
                    VStack(spacing: 12) {
                        Image(systemName: "drop.halffull")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundStyle(.questAmber)
                        Text("Blur Beast")
                            .font(.dungeonHeader)
                            .foregroundStyle(.textPrimary)
                        Text("4.2 MB · 3 yr ago")
                            .font(.caption)
                            .foregroundStyle(.textSecondary)
                    }
                )
                .offset(x: offset)
                .rotationEffect(.degrees(Double(offset / 20)))
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

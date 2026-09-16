//
//  OnboardingView.swift
//  PurgeQuest
//
//  Six-step onboarding: intro, photo permission, race picker (nine
//  illustrated races), class picker (17 variants grouped by discipline),
//  appearance customization (paint job + core recolors), and the swipe
//  tutorial. Choices persist via UserDefaults and land on the hero record
//  at first bootstrap.
//

import SwiftUI
import Photos

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var pageIndex: Int = 0
    @State private var requestingPermission: Bool = false
    @State private var selectedRace: HeroRace = .valkyrie
    @State private var selectedClass: HeroClass = .paladinHoly
    @State private var heroName: String = ""
    @State private var draftLook: HeroAppearance = .default(for: .valkyrie)
    @State private var previewHero: Hero = Hero()

    private let totalPages = 6

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
                    racePage.tag(2)
                    classPage.tag(3)
                    lookPage.tag(4)
                    swipeTutorialPage.tag(5)
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

    // MARK: Race page

    private var racePage: some View {
        VStack(spacing: 14) {
            Text("Choose Your Race")
                .font(.dungeonTitle)
                .foregroundStyle(.textPrimary)
                .padding(.top, 20)
            Text("Nine illustrated races. Three paint jobs each.")
                .font(.callout)
                .foregroundStyle(.textSecondary)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(HeroRace.allCases, id: \.self) { race in
                        raceCard(race)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
        }
    }

    private func raceCard(_ race: HeroRace) -> some View {
        let selected = selectedRace == race
        return Button {
            HapticsService.shared.light()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedRace = race
                selectedClass = race.recommendedClass
                draftLook = .default(for: race)
            }
        } label: {
            VStack(spacing: 8) {
                HeroSpriteView(hero: previewHero, appearance: .default(for: race), size: 104, isAnimated: false)
                    .frame(height: 104)
                Text(race.displayName)
                    .font(.headline)
                    .foregroundStyle(.textPrimary)
                Text(race.tagline)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dungeonStone)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selected ? race.accent : Color.dungeonAsh, lineWidth: selected ? 2 : 1)
                    )
            )
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(race.accent)
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Class page

    private var classPage: some View {
        VStack(spacing: 14) {
            Text("Choose Your Class")
                .font(.dungeonTitle)
                .foregroundStyle(.textPrimary)
                .padding(.top, 20)

            TextField("Hero name", text: $heroName)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.dungeonStone, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1))
                .padding(.horizontal, 20)

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(HeroDiscipline.allCases, id: \.self) { discipline in
                        VStack(alignment: .leading, spacing: 8) {
                            Label(discipline.displayName, systemImage: discipline.symbol)
                                .font(.caption.weight(.bold))
                                .tracking(0.8)
                                .foregroundStyle(.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            ForEach(HeroClass.allCases.filter { $0.discipline == discipline }, id: \.self) { hc in
                                classRow(hc)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
        }
    }

    private func classRow(_ hc: HeroClass) -> some View {
        let selected = selectedClass == hc
        return Button {
            HapticsService.shared.light()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedClass = hc
            }
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

    // MARK: Look page

    private var lookPage: some View {
        VStack(spacing: 14) {
            Text("Shape Your Look")
                .font(.dungeonTitle)
                .foregroundStyle(.textPrimary)
                .padding(.top, 20)

            HeroSpriteView(hero: previewHero, appearance: draftLook, size: 190)
                .frame(height: 190)

            ScrollView {
                VStack(spacing: 16) {
                    paintChips
                    swatchRow("Skin tone", Array(SkinTone.allCases), selection: draftLook.skinTone) { draftLook.skinTone = $0 }
                    swatchRow("Hair color", Array(HairColor.allCases), selection: draftLook.hairColor) { draftLook.hairColor = $0 }
                    swatchRow("Armor dye", Array(ArmorDye.allCases), selection: draftLook.armorDye) { draftLook.armorDye = $0 }
                    Text("Deep customization lives in the Hero Forge after onboarding.")
                        .font(.caption2)
                        .foregroundStyle(.textTertiary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
        }
    }

    private var paintChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PAINT JOB")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 10) {
                ForEach([1, 2, 3], id: \.self) { variant in
                    Button {
                        HapticsService.shared.light()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            draftLook.paintVariant = variant
                        }
                    } label: {
                        Text("Paint \(variant)")
                            .font(.callout.weight(.semibold))
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(draftLook.paintVariant == variant ? AnyShapeStyle(Color.questAmber) : AnyShapeStyle(Color.dungeonStone))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(draftLook.paintVariant == variant ? Color.questAmberDeep : Color.dungeonAsh, lineWidth: 1))
                            )
                            .foregroundStyle(draftLook.paintVariant == variant ? AnyShapeStyle(.dungeonVoid) : AnyShapeStyle(.textPrimary))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func swatchRow<T: ForgeSwatch>(
        _ title: String,
        _ options: [T],
        selection: T,
        onSelect: @escaping (T) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            HapticsService.shared.light()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { onSelect(option) }
                        } label: {
                            Circle()
                                .fill(option.color)
                                .frame(width: 40, height: 40)
                                .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1))
                                .overlay(
                                    Circle().strokeBorder(
                                        selection == option ? Color.questAmber : Color.clear,
                                        lineWidth: 3
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.displayName)
                        .accessibilityAddTraits(selection == option ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 2)
            }
        }
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
            // Persist hero choices via UserDefaults; the hero is created lazily
            // and applies them (plus the drafted look) at first bootstrap.
            UserDefaults.standard.set(selectedClass.rawValue, forKey: "pq.selectedClass")
            UserDefaults.standard.set(selectedRace.rawValue, forKey: "pq.race")
            draftLook.race = selectedRace
            if let data = try? JSONEncoder().encode(draftLook) {
                UserDefaults.standard.set(data, forKey: "pq.appearanceDraft")
            }
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

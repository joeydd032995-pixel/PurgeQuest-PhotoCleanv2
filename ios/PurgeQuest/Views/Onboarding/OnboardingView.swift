//
//  OnboardingView.swift
//  PurgeQuest
//
//  Six-step onboarding: intro, photo permission, race picker (nine
//  illustrated races), class picker (17 variants grouped by discipline),
//  appearance customization (paint job + core recolors), and the swipe
//  tutorial. Choices persist via UserDefaults and land on the hero record
//  when GameDataService.provision runs as onboarding completes.
//

import SwiftUI
import SwiftData
import Photos

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
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
                // The pager can be swiped as well as stepped with Continue. Swiping must not get past the
                // permission page while the app cannot see the library.
                .onChange(of: pageIndex) { _, page in
                    if page > Self.permissionPageIndex && !permissionGranted {
                        withAnimation { pageIndex = Self.permissionPageIndex }
                    }
                }

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
            WordmarkView()
            EmblemView()
                .frame(maxWidth: 220)
            VStack(spacing: 12) {
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
        let access = appState.photoAccess
        return VStack(spacing: 22) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
                .foregroundStyle(.questAmber)
            Text("Allow photo access")
                .font(.dungeonHeader)
                .foregroundStyle(.textPrimary)
            Text("PurgeQuest reads your photo library to find clutter. Items you choose to delete are moved to **Recently Deleted** in Photos. You can restore them for 30 days.")
                .font(.callout)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            statusChip(access)
            permissionAction(access)
            Spacer()
        }
    }

    /// What the player can do about the current access. When it is open there is nothing to do here and
    /// Continue, in the bottom bar, is the one plate. Otherwise this is the one plate, so the page never
    /// shows two.
    @ViewBuilder
    private func permissionAction(_ access: PhotoAccess) -> some View {
        switch access {
        case .notAsked:
            Button {
                Task {
                    requestingPermission = true
                    await appState.refreshPhotoAuth()
                    requestingPermission = false
                }
            } label: {
                HStack {
                    if requestingPermission { ProgressView() }
                    Text("Allow photo access")
                }
            }
            .buttonStyle(.gold(fullWidth: true))
            .padding(.horizontal, 24)
            .disabled(requestingPermission)
        case .denied:
            VStack(spacing: 10) {
                Button("Open Settings") { SystemSettings.open() }
                    .buttonStyle(.gold(fullWidth: true))
                Text("Turn on Photos for PurgeQuest, then come back. This page updates by itself.")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
        case .restricted:
            Text(access.message)
                .font(.caption)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        case .limited:
            Button("Allow more photos") { SystemSettings.open() }
                .buttonStyle(.plain)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.textPrimary)
                .padding(.horizontal, 20)
                .frame(minHeight: 44)
                .background(DungeonPanelBackground())
        case .full:
            EmptyView()
        }
    }

    private func statusChip(_ access: PhotoAccess) -> some View {
        let (symbol, tint): (String, Color) = {
            switch access {
            case .full: return ("checkmark.circle.fill", .gemEmerald)
            case .limited: return ("exclamationmark.triangle.fill", .questAmber)
            case .denied, .restricted: return ("xmark.circle.fill", .combatCrimson)
            case .notAsked: return ("circle.dashed", .textSecondary)
            }
        }()
        return Label(access.chipText, systemImage: symbol)
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
            Text("Eight illustrated races. Every paint job recolorable.")
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
        .accessibilityIdentifier("onboarding.race.\(race.rawValue)")
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
                    .foregroundStyle(selected ? Color.goldInk : Color.questAmber)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 10).fill(selected ? AnyShapeStyle(Color.goldFill) : AnyShapeStyle(Color.dungeonStoneLight))
                    )
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.goldRim : Color.dungeonAsh, lineWidth: 1))
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
                    let capabilities = lookCapabilities
                    swatchRow("Skin tone", Array(SkinTone.allCases), selection: draftLook.chosenSkinTone,
                              availability: capabilities.skin, offersAsPainted: true) { draftLook = draftLook.choosingSkin($0) }
                    swatchRow("Hair color", Array(HairColor.allCases), selection: draftLook.chosenHairColor,
                              availability: capabilities.hair, offersAsPainted: true) { draftLook = draftLook.choosingHair($0) }
                    swatchRow("Armor dye", Array(ArmorDye.allCases), selection: draftLook.armorDye,
                              availability: capabilities.armorDye, offersAsPainted: false) { if let dye = $0 { draftLook.armorDye = dye } }
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
                ForEach(1...max(selectedRace.variantCount, 1), id: \.self) { variant in
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
                                    .fill(draftLook.paintVariant == variant ? AnyShapeStyle(Color.goldFill) : AnyShapeStyle(Color.dungeonStone))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(draftLook.paintVariant == variant ? Color.goldRim : Color.dungeonAsh, lineWidth: 1))
                            )
                            .foregroundStyle(draftLook.paintVariant == variant ? AnyShapeStyle(.goldInk) : AnyShapeStyle(.textPrimary))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Which look controls change the sprite on the paint being previewed (see LookCapabilities).
    private var lookCapabilities: LookCapabilities {
        LookCapabilities.forPaint(
            race: selectedRace, variant: draftLook.paintVariant,
            parts: ModularAssetCatalog.shared.parts(forPack: selectedRace.artBase(variant: draftLook.paintVariant)))
    }

    /// One row of swatches. `selection` is the applied swatch, nil for the art as painted; skin and hair offer an
    /// "As painted" chip first. A row with nothing to change on this paint is dimmed and says why.
    private func swatchRow<T: ForgeSwatch>(
        _ title: String,
        _ options: [T],
        selection: T?,
        availability: LookAvailability,
        offersAsPainted: Bool,
        onSelect: @escaping (T?) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if offersAsPainted {
                        AsPaintedChip(isSelected: selection == nil) {
                            HapticsService.shared.light()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { onSelect(nil) }
                        }
                    }
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
            .disabled(!availability.isAvailable)
            .opacity(availability.isAvailable ? 1 : 0.4)
            LookUnavailableNote(availability: availability)
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
            // While the library is closed, the permission page's own button is the one plate on screen.
            if !continueBlockedByPermission {
                Button {
                    advance()
                } label: {
                    Text(pageIndex == totalPages - 1 ? "Enter the Dungeon" : "Continue")
                }
                .buttonStyle(.gold)
            }
        }
        // Keeps the page from jumping when Continue appears and disappears.
        .frame(minHeight: 52)
    }

    /// The index of the permission page in the pager.
    private static let permissionPageIndex = 1

    /// Whether the app may open the library (full or limited access).
    private var permissionGranted: Bool { appState.photoAccess.canReview }

    /// The permission page cannot be passed until photo access is granted (full or limited).
    private var continueBlockedByPermission: Bool {
        pageIndex == Self.permissionPageIndex && !permissionGranted
    }

    private func advance() {
        if pageIndex < totalPages - 1 {
            withAnimation { pageIndex += 1 }
        } else {
            // Save the hero choices, then apply them before the main tabs appear. The launch
            // task ran before this screen was shown, so it cannot: on a first run it made a
            // default hero, and after "Reset all PurgeQuest data" it left the store empty.
            UserDefaults.standard.set(selectedClass.rawValue, forKey: "pq.selectedClass")
            UserDefaults.standard.set(selectedRace.rawValue, forKey: "pq.race")
            draftLook.race = selectedRace
            if let data = try? JSONEncoder().encode(draftLook) {
                UserDefaults.standard.set(data, forKey: "pq.appearanceDraft")
            }
            let trimmed = heroName.trimmingCharacters(in: .whitespaces)
            UserDefaults.standard.set(trimmed.isEmpty ? "Hero" : trimmed, forKey: "pq.heroName")
            GameDataService.provision(in: modelContext)
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

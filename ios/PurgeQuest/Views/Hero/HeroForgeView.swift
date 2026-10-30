//
//  HeroForgeView.swift
//  PurgeQuest
//
//  Immersive full-screen hero editor. All edits land on a draft appearance
//  that drives the live preview only; Save commits it to the hero record,
//  Cancel/swipe-down discards, and Reset restores the designed default for
//  the archetype. Gear is untouched here — it stays in the Armory and keeps
//  rendering over the identity.
//

import SwiftUI
import SwiftData

/// An option the forge renders as a named row with a symbol.
protocol ForgeOption: Hashable {
    var forgeName: String { get }
    var forgeSymbol: String { get }
}

/// An option the forge renders as a color swatch.
protocol ForgeSwatch: Hashable {
    var displayName: String { get }
    var color: Color { get }
}

/// Forge categories, in display order.
enum ForgeCategory: String, CaseIterable, Identifiable {
    case race, paint, skin, face, eyes, brows, mouth, hair, expression, armorDye, gear, colors, backdrop

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .race: return "Race"
        case .paint: return "Paint Job"
        case .skin: return "Skin"
        case .face: return "Face"
        case .eyes: return "Eyes"
        case .brows: return "Brows"
        case .mouth: return "Mouth"
        case .hair: return "Hair"
        case .expression: return "Mood"
        case .armorDye: return "Armor Dye"
        case .gear: return "Gear"
        case .colors: return "Colors"
        case .backdrop: return "Backdrop"
        }
    }

    var symbol: String {
        switch self {
        case .race: return "person.2.fill"
        case .paint: return "paintbrush.fill"
        case .skin: return "person.fill"
        case .face: return "smiley"
        case .eyes: return "eye.fill"
        case .brows: return "eyebrow"
        case .mouth: return "mouth"
        case .hair: return "comb"
        case .expression: return "theatermasks"
        case .armorDye: return "paintpalette.fill"
        case .gear: return "shield.lefthalf.filled"
        case .colors: return "paintpalette"
        case .backdrop: return "rectangle.inset.filled"
        }
    }
}

struct HeroForgeView: View {
    let hero: Hero

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var cosmetics: [CosmeticItem]
    @Query private var achievements: [Achievement]

    @State private var draft: HeroAppearance
    @State private var category: ForgeCategory = .skin
    @State private var showStripPreview: Bool = false
    /// Requirement text shown after tapping a locked dye.
    @State private var lockMessage: String?
    /// Equipment edits (slot raw value -> item id). nil until the player touches Gear; Save applies it, Cancel drops it.
    @State private var draftEquipped: [String: String]?
    /// A race change waiting on the player's whole-look / anatomy-only / cancel choice.
    @State private var pendingRace: HeroRace?
    /// Set when persisting fails; the Forge stays open and shows it.
    @State private var saveError: String?

    init(hero: Hero) {
        self.hero = hero
        _draft = State(initialValue: hero.appearance)
    }

    private var equippedItems: [CosmeticItem] { cosmetics.filter { $0.isEquipped } }

    private static let managedSlots: Set<CosmeticType> = [.weapon, .shield, .head]

    /// What is equipped right now, by managed slot.
    private var currentEquipped: [String: String] {
        Dictionary(equippedItems.filter { Self.managedSlots.contains($0.type) }.map { ($0.type.rawValue, $0.id) },
                   uniquingKeysWith: { first, _ in first })
    }

    private var equippedMap: Binding<[String: String]> {
        Binding(get: { draftEquipped ?? currentEquipped }, set: { draftEquipped = $0 })
    }

    /// Equipment as the preview should draw it: the draft's picks, other slots as they are.
    private var previewItems: [CosmeticItem] {
        guard let draftEquipped else { return equippedItems }
        let picked = Set(draftEquipped.values)
        return cosmetics.filter { item in
            Self.managedSlots.contains(item.type) ? picked.contains(item.id) : item.isEquipped
        }
    }

    private var draftRace: HeroRace { draft.race ?? hero.race }
    private var draftVariant: Int { min(max(draft.paintVariant, 1), draftRace.variantCount) }

    private var isDirty: Bool {
        ForgeDraft(appearance: draft, equipped: equippedMap.wrappedValue)
            .isDirty(comparedTo: ForgeDraft(appearance: hero.appearance, equipped: currentEquipped))
    }
    private var isDefaultLook: Bool { draft == .default(for: hero.race) }

    private var tier: GearTier {
        HeroAppearance.gearTier(
            maxEquippedPrice: equippedItems.map(\.priceGems).max() ?? 0,
            hasPremium: equippedItems.contains { $0.isPremium }
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            DungeonBackgroundView()
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        preview
                        contextToggle
                        categoryBar
                        lockBanner
                        optionArea
                        Color.clear.frame(height: 8)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
                actionBar
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: draft.race) { _, _ in pruneIncompatibleEquipment() }
        .onChange(of: draft.paintVariant) { _, _ in pruneIncompatibleEquipment() }
        .confirmationDialog(
            "Change ancestry to \(pendingRace?.displayName ?? "")?",
            isPresented: Binding(get: { pendingRace != nil }, set: { if !$0 { pendingRace = nil } }),
            titleVisibility: .visible
        ) {
            Button("Whole look") { resolveRaceChange(.wholeLook) }
            Button("Anatomy only") { resolveRaceChange(.anatomyOnly) }
            Button("Cancel", role: .cancel) { resolveRaceChange(.cancel) }
        } message: {
            Text("Whole look takes the new ancestry's designed look. Anatomy only keeps your face, colours and dyes.")
        }
        .alert(
            "Couldn't save your hero",
            isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(saveError ?? "") Your changes are still in the Forge; nothing was applied.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.bold))
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.dungeonStone))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1))
            }
            .accessibilityLabel("Cancel editing without saving")

            Spacer()

            VStack(spacing: 2) {
                Text("Hero Forge")
                    .font(.dungeonTitle)
                    .foregroundStyle(.textPrimary)
                Text(tier.displayName + " gear tier")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tier.accent)
            }

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    // MARK: - Preview

    @ViewBuilder private var preview: some View {
        if showStripPreview {
            // Compact-context preview mirroring the Dashboard hero strip.
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.dungeonStoneLight)
                        .overlay(Circle().stroke(tier.accent.opacity(0.6), lineWidth: 1))
                    MiniAvatarView(hero: hero, equipped: previewItems, size: 88, appearance: draft)
                        .frame(width: 52, height: 62)
                        .clipped()
                }
                .frame(width: 68, height: 68)

                VStack(alignment: .leading, spacing: 4) {
                    Text(hero.name)
                        .font(.dungeonHeader)
                        .foregroundStyle(.textPrimary)
                    Text("LV \(hero.level)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(.textSecondary)
                }
                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dungeonStone.opacity(0.85))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(tier.accent.opacity(0.35), lineWidth: 1))
            )
        } else {
            CharacterAvatarView(hero: hero, equipped: previewItems, size: 230, appearance: draft)
                .frame(maxWidth: .infinity)
        }
    }

    private var contextToggle: some View {
        VStack(spacing: 6) {
            Picker("Preview context", selection: $showStripPreview) {
                Text("Portrait").tag(false)
                Text("Dashboard Strip").tag(true)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)
            .accessibilityLabel("Preview size")
            Text("Gear and colours here are a draft until you tap Save Hero. Buy gear in the Armory.")
                .font(.caption2)
                .foregroundStyle(.textTertiary)
        }
    }

    // MARK: - Categories

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ForgeCategory.allCases) { c in
                    Button {
                        guard category != c else { return }
                        HapticsService.shared.light()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { category = c }
                    } label: {
                        Label(c.displayName, systemImage: c.symbol)
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(category == c ? AnyShapeStyle(Color.questAmber) : AnyShapeStyle(Color.dungeonStone))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(category == c ? Color.questAmberDeep : Color.dungeonAsh, lineWidth: 1))
                            )
                            .foregroundStyle(category == c ? AnyShapeStyle(.dungeonVoid) : AnyShapeStyle(.textPrimary))
                    }
                    .accessibilityLabel("\(c.displayName) options")
                    .accessibilityAddTraits(category == c ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Options

    @ViewBuilder private var optionArea: some View {
        switch category {
        case .race:
            raceSection
        case .paint:
            paintSection
        case .skin:
            swatchSection("Skin tone", options: SkinTone.allCases, selected: draft.skinTone) { draft.skinTone = $0 }
            hueSlider("Custom skin hue", value: draft.skinHueShift) { draft.skinHueShift = HeroAppearance.clampedHue($0) }
        case .face:
            optionSection("Face shape", options: FaceShape.allCases, selected: draft.faceShape) { draft.faceShape = $0 }
        case .eyes:
            optionSection("Eye style", options: EyeStyle.allCases, selected: draft.eyeStyle) { draft.eyeStyle = $0 }
            swatchSection(
                "Eye color",
                options: EyeColor.allCases,
                selected: draft.eyeColor,
                lockInfo: { lockRequirement($0.requiredAchievementID) }
            ) { draft.eyeColor = $0 }
            hueSlider("Custom eye hue", value: draft.eyeHueShift) { draft.eyeHueShift = HeroAppearance.clampedHue($0) }
        case .brows:
            optionSection("Brow style", options: BrowStyle.allCases, selected: draft.browStyle) { draft.browStyle = $0 }
        case .mouth:
            optionSection("Mouth", options: MouthStyle.allCases, selected: draft.mouthStyle) { draft.mouthStyle = $0 }
        case .hair:
            optionSection("Hair style", options: HairStyle.allCases, selected: draft.hairStyle) { draft.hairStyle = $0 }
            swatchSection(
                "Hair color",
                options: HairColor.allCases,
                selected: draft.hairColor,
                lockInfo: { lockRequirement($0.requiredAchievementID) }
            ) { draft.hairColor = $0 }
            hueSlider("Custom hair hue", value: draft.hairHueShift) { draft.hairHueShift = HeroAppearance.clampedHue($0) }
        case .expression:
            presetSection("Expression presets")
            optionSection("Mood", options: Expression.allCases, selected: draft.expression) { draft.expression = $0 }
        case .armorDye:
            swatchSection(
                "Armor dye",
                options: ArmorDye.allCases,
                selected: draft.armorDye,
                lockInfo: { lockRequirement($0.requiredAchievementID) }
            ) { draft.armorDye = $0 }
        case .gear:
            ForgeGearPicker(cosmetics: cosmetics, race: draftRace, variant: draftVariant, equipped: equippedMap)
        case .colors:
            colorsSection
        case .backdrop:
            optionSection("Backdrop", options: BackdropStyle.allCases, selected: draft.backdropStyle) { draft.backdropStyle = $0 }
        }
    }

    // MARK: - Colors

    /// Regions the equipped gear's masks expose.
    private var gearRegions: [MaterialRegion] {
        var found = Set<MaterialRegion>()
        for item in previewItems where Self.managedSlots.contains(item.type) {
            if let entry = ModularAssetCatalog.shared.gearItem(id: item.id) {
                found.formUnion(entry.maskResources.keys.compactMap(MaterialRegion.init(rawValue:)))
            }
        }
        return Array(found)
    }

    private var bodyRegions: [MaterialRegion] {
        var found = Set<MaterialRegion>()
        for part in ModularAssetCatalog.shared.parts(forPack: draftRace.artBase(variant: draftVariant)) {
            found.formUnion(part.materialRegions)
        }
        return Array(found)
    }

    /// Body colours only render through the modular path, which needs every layer of the look approved.
    private var bodyColorsActive: Bool {
        let layers = ModularAssetCatalog.shared.parts(forPack: draftRace.artBase(variant: draftVariant)).filter { $0.kind != "face" }
        return !layers.isEmpty && layers.allSatisfy { $0.verification.status == .verified }
    }

    private var colorsSection: some View {
        ForgeColorSection(
            gearRegions: gearRegions,
            bodyRegions: bodyRegions,
            bodyColorsActive: bodyColorsActive,
            gearMaterials: Binding(get: { draft.gearMaterials }, set: { draft.gearMaterials = $0 }),
            bodyMaterials: Binding(get: { draft.materials }, set: { draft.materials = $0 })
        )
    }

    // MARK: - Ancestry and equipment compatibility

    /// A race change that would overwrite customisation waits for an explicit choice.
    private func requestRaceChange(_ race: HeroRace) {
        let current = draftRace
        guard race != current else { return }
        if AncestryChange.hasCustomization(draft, currentRace: current) {
            HapticsService.shared.light()
            pendingRace = race
        } else {
            select(race) { draft = AncestryChange.apply(.wholeLook, to: draft, newRace: $0) }
        }
    }

    private func resolveRaceChange(_ choice: AncestryChoice) {
        defer { pendingRace = nil }
        guard let race = pendingRace, choice != .cancel else { return }
        select(race) { draft = AncestryChange.apply(choice, to: draft, newRace: $0) }
    }

    /// Drops equipment the new body can't wear (e.g. the Elven Recurve on a sword-pack paint job) and says so.
    private func pruneIncompatibleEquipment() {
        var map = equippedMap.wrappedValue
        var removed: [String] = []
        for (slot, id) in map {
            guard let entry = ModularAssetCatalog.shared.gearItem(id: id),
                  !GearCompatibility.isSupported(entry, race: draftRace, variant: draftVariant) else { continue }
            map.removeValue(forKey: slot)
            removed.append(entry.name)
        }
        guard !removed.isEmpty else { return }
        draftEquipped = map
        lockMessage = "Unequipped \(removed.joined(separator: ", ")): not supported on this body."
    }

    /// The achievement id gating a dye, or nil when the dye is free or the
    /// achievement has already been earned.
    private func lockRequirement(_ achievementID: String?) -> String? {
        guard let achievementID else { return nil }
        let unlocked = achievements.first { $0.id == achievementID }?.isUnlocked ?? false
        return unlocked ? nil : achievementID
    }

    @ViewBuilder private var lockBanner: some View {
        if let lockMessage {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.caption.weight(.bold))
                Text(lockMessage)
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.dungeonStone)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1))
            )
            .foregroundStyle(.textSecondary)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Race, paint, and hue sections

    private var raceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Race")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 12) {
                ForEach(HeroRace.allCases, id: \.self) { race in
                    Button {
                        requestRaceChange(race)
                    } label: {
                        VStack(spacing: 6) {
                            HeroSpriteView(hero: hero, appearance: .default(for: race), size: 76)
                                .frame(height: 76)
                            Text(race.displayName)
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                                .foregroundStyle(.textSecondary)
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(draft.race == race ? AnyShapeStyle(Color.questAmber.opacity(0.16)) : AnyShapeStyle(Color.dungeonStone))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(draft.race == race ? Color.questAmber : Color.dungeonAsh, lineWidth: draft.race == race ? 1.5 : 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(race.displayName) race")
                    .accessibilityAddTraits(draft.race == race ? .isSelected : [])
                }
            }
        }
    }

    private var paintSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Paint job")
            HStack(spacing: 10) {
                ForEach(1...max((draft.race ?? hero.race).variantCount, 1), id: \.self) { variant in
                    Button {
                        select(variant) { draft.paintVariant = $0 }
                    } label: {
                        VStack(spacing: 6) {
                            HeroSpriteView(hero: hero, appearance: paintPreview(variant), size: 84)
                                .frame(height: 84)
                            Text("Paint \(variant)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(draft.paintVariant == variant ? AnyShapeStyle(Color.questAmber.opacity(0.16)) : AnyShapeStyle(Color.dungeonStone))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(draft.paintVariant == variant ? Color.questAmber : Color.dungeonAsh, lineWidth: draft.paintVariant == variant ? 1.5 : 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Paint job \(variant)")
                    .accessibilityAddTraits(draft.paintVariant == variant ? .isSelected : [])
                }
            }
        }
    }

    /// A preview copy of the draft with just the paint variant swapped.
    private func paintPreview(_ variant: Int) -> HeroAppearance {
        var look = draft
        look.paintVariant = variant
        return look
    }

    /// A -180°...180° hue slider bound to one appearance shift.
    private func hueSlider(_ title: String, value: Double, onChange: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle(title)
            Slider(
                value: Binding(get: { value }, set: { onChange($0) }),
                in: -1...1
            )
            HStack {
                Text("-180°").font(.caption2).foregroundStyle(.textTertiary)
                Spacer()
                Text("0°").font(.caption2).foregroundStyle(.textTertiary)
                Spacer()
                Text("+180°").font(.caption2).foregroundStyle(.textTertiary)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func optionSection<T: ForgeOption>(
        _ title: String,
        options: [T],
        selected: T,
        onSelect: @escaping (T) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(title)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(options, id: \.self) { option in
                    optionButton(option, isSelected: selected == option) {
                        select(option, apply: onSelect)
                    }
                }
            }
        }
    }

    /// Presets apply a matched expression + brows + mouth in one tap; they
    /// edit the draft like any other trait, so Cancel still discards.
    private func presetSection(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(title)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(ExpressionPreset.allCases, id: \.self) { preset in
                    optionButton(preset, isSelected: preset.matches(draft)) {
                        HapticsService.shared.light()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            preset.apply(to: &draft)
                        }
                    }
                }
            }
        }
    }

    private func swatchSection<T: ForgeSwatch>(
        _ title: String,
        options: [T],
        selected: T,
        lockInfo: ((T) -> String?)? = nil,
        onSelect: @escaping (T) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(title)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 10)], spacing: 12) {
                ForEach(options, id: \.self) { option in
                    swatchButton(
                        option,
                        isSelected: selected == option,
                        lockedRequirement: lockInfo?(option)
                    ) {
                        select(option, apply: onSelect)
                    }
                }
            }
        }
    }

    private func optionButton<T: ForgeOption>(
        _ option: T,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if T.self == HairStyle.self {
                    // Hair styles preview with the currently chosen hair color.
                    Circle()
                        .fill(draft.hairColor.color)
                        .frame(width: 18, height: 18)
                        .overlay(Circle().stroke(Color.dungeonAsh, lineWidth: 1))
                } else {
                    Image(systemName: option.forgeSymbol)
                        .font(.subheadline.weight(.bold))
                        .frame(width: 20)
                }
                Text(option.forgeName)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.questAmber) : AnyShapeStyle(Color.dungeonAsh))
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? AnyShapeStyle(Color.questAmber.opacity(0.16)) : AnyShapeStyle(Color.dungeonStone))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.questAmber : Color.dungeonAsh, lineWidth: isSelected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.forgeName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func swatchButton<T: ForgeSwatch>(
        _ option: T,
        isSelected: Bool,
        lockedRequirement: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            if let requirement = lockedRequirement {
                HapticsService.shared.warning()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    lockMessage = DyeGate.requirementText(for: requirement)
                }
            } else {
                action()
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(option.color)
                        .frame(width: 46, height: 46)
                        .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 1))
                        .opacity(lockedRequirement == nil ? 1 : 0.35)
                    if let requirement = lockedRequirement {
                        Image(systemName: "lock.fill")
                            .font(.callout.weight(.bold))
                            .foregroundStyle(.textPrimary)
                            .shadow(color: .black.opacity(0.6), radius: 1)
                            .accessibilityHidden(true)
                        Text(DyeGate.achievementTitle(for: requirement))
                            .font(.system(size: 8, weight: .bold))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.textSecondary)
                            .frame(width: 50)
                            .offset(y: 16)
                    }
                    if isSelected {
                        Circle()
                            .strokeBorder(Color.questAmber, lineWidth: 3)
                            .frame(width: 52, height: 52)
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 1)
                    }
                }
                .frame(width: 54, height: 54)
                Text(option.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(lockedRequirement == nil ? AnyShapeStyle(.textSecondary) : AnyShapeStyle(Color.dungeonAsh))
                    .lineLimit(1)
            }
            .frame(minWidth: 56, minHeight: 68)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            lockedRequirement == nil
                ? "\(option.displayName) tone"
                : "\(option.displayName), locked. \(DyeGate.requirementText(for: lockedRequirement!))"
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Actions

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button(action: resetToDefault) {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .font(.callout.weight(.bold))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.dungeonStone))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1))
                    .foregroundStyle(.textPrimary)
            }
            .disabled(!isDirty)
            .opacity(isDirty ? 1 : 0.45)
            .accessibilityHint("Restores the designed default look for this archetype")

            Button(action: save) {
                Label("Save Hero", systemImage: "checkmark")
                    .font(.callout.weight(.heavy))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isDirty ? AnyShapeStyle(Color.questAmber) : AnyShapeStyle(Color.dungeonStone))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.questAmberDeep, lineWidth: 1)
                            .opacity(isDirty ? 1 : 0.3)
                    )
                    .foregroundStyle(isDirty ? AnyShapeStyle(.dungeonVoid) : AnyShapeStyle(.textSecondary))
            }
            .disabled(!isDirty)
            .accessibilityHint("Applies this look to the hero everywhere")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.dungeonVoid.opacity(0.92))
    }

    private func select<T: Hashable>(_ value: T, apply: @escaping (T) -> Void) {
        HapticsService.shared.light()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            apply(value)
            lockMessage = nil
        }
    }

    private func resetToDefault() {
        HapticsService.shared.heavy()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            draft = .default(for: hero.race)
        }
    }

    /// Applies the draft and persists it. On failure the previous look and equipment are restored, the Forge
    /// stays open, and the error is shown; the success haptic and dismissal happen only after a real save.
    private func save() {
        var committed = draft
        committed.materials = MaterialPalette.normalized(committed.materials)
        committed.gearMaterials = MaterialPalette.normalized(committed.gearMaterials)
        if committed.materials != nil || committed.gearMaterials != nil {
            committed.schemaVersion = HeroAppearance.currentSchemaVersion
        }
        let previousAppearance = hero.appearance
        let previousEquipped = Dictionary(cosmetics.map { ($0.id, $0.isEquipped) }, uniquingKeysWith: { first, _ in first })
        let wanted = draftEquipped.map { Set($0.values) }

        let outcome = ForgeSaveCoordinator.commit(
            apply: {
                hero.appearance = committed
                if let wanted {
                    for item in cosmetics where Self.managedSlots.contains(item.type) {
                        item.isEquipped = wanted.contains(item.id)
                    }
                }
            },
            persist: { try modelContext.save() },
            rollback: {
                hero.appearance = previousAppearance
                for item in cosmetics {
                    if let was = previousEquipped[item.id] { item.isEquipped = was }
                }
                modelContext.rollback()
            }
        )
        switch outcome {
        case .saved:
            HapticsService.shared.success()
            dismiss()
        case .failed(let message):
            HapticsService.shared.warning()
            saveError = message
        }
    }
}

// MARK: - Forge conformances

extension SkinTone: ForgeSwatch {}
extension EyeColor: ForgeSwatch {}
extension HairColor: ForgeSwatch {}
extension ArmorDye: ForgeSwatch {}

extension FaceShape: ForgeOption {
    var forgeName: String { displayName }
    var forgeSymbol: String {
        switch self {
        case .round: return "circle.fill"
        case .boulder: return "squircle.fill"
        case .nimble: return "oval.fill"
        }
    }
}

extension EyeStyle: ForgeOption {
    var forgeName: String { displayName }
    var forgeSymbol: String {
        switch self {
        case .bright: return "eye.fill"
        case .keen: return "eye"
        case .gentle: return "eye.circle"
        }
    }
}

extension BrowStyle: ForgeOption {
    var forgeName: String { displayName }
    var forgeSymbol: String {
        switch self {
        case .steady: return "minus"
        case .fierce: return "chevron.down"
        case .worried: return "chevron.up"
        case .stern: return "line.diagonal"
        }
    }
}

extension MouthStyle: ForgeOption {
    var forgeName: String { displayName }
    var forgeSymbol: String {
        switch self {
        case .smile: return "face.smiling"
        case .grin: return "mouth"
        case .neutral: return "minus"
        case .frown: return "face.dashed"
        }
    }
}

extension HairStyle: ForgeOption {
    var forgeName: String { displayName }
    var forgeSymbol: String {
        switch self {
        case .short: return "scissors"
        case .swept: return "wind"
        case .long: return "arrow.down.circle"
        case .buzz: return "circle.dotted"
        case .bald: return "circle"
        }
    }
}

extension Expression: ForgeOption {
    var forgeName: String { displayName }
    var forgeSymbol: String {
        switch self {
        case .calm: return "leaf.fill"
        case .fierce: return "flame.fill"
        case .happy: return "sun.max.fill"
        case .weary: return "moon.zzz.fill"
        }
    }
}

extension ExpressionPreset: ForgeOption {
    var forgeName: String { displayName }
    var forgeSymbol: String {
        switch self {
        case .valor:        return "shield.fill"
        case .battleFrenzy: return "flame.fill"
        case .triumph:      return "trophy.fill"
        case .exhausted:    return "moon.zzz.fill"
        }
    }
}

extension BackdropStyle: ForgeOption {
    var forgeName: String { displayName }
    var forgeSymbol: String {
        switch self {
        case .plaque: return "rectangle.inset.filled"
        case .medallion: return "circle.circle"
        case .banner: return "flag.fill"
        }
    }
}

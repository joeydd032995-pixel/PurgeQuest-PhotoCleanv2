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
    case skin, face, eyes, brows, mouth, hair, expression, armorDye, backdrop

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .skin: return "Skin"
        case .face: return "Face"
        case .eyes: return "Eyes"
        case .brows: return "Brows"
        case .mouth: return "Mouth"
        case .hair: return "Hair"
        case .expression: return "Mood"
        case .armorDye: return "Armor Dye"
        case .backdrop: return "Backdrop"
        }
    }

    var symbol: String {
        switch self {
        case .skin: return "person.fill"
        case .face: return "smiley"
        case .eyes: return "eye.fill"
        case .brows: return "eyebrow"
        case .mouth: return "mouth"
        case .hair: return "comb"
        case .expression: return "theatermasks"
        case .armorDye: return "paintpalette.fill"
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

    init(hero: Hero) {
        self.hero = hero
        _draft = State(initialValue: hero.appearance)
    }

    private var equippedItems: [CosmeticItem] { cosmetics.filter { $0.isEquipped } }

    private var isDirty: Bool { draft != hero.appearance }
    private var isDefaultLook: Bool { draft == .default(for: hero.archetype) }

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
                    MiniAvatarView(hero: hero, equipped: equippedItems, size: 88, appearance: draft)
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
            CharacterAvatarView(hero: hero, equipped: equippedItems, size: 230, appearance: draft)
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
            Text("Gear is equipped in the Armory. The forge shapes the hero underneath.")
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
        case .skin:
            swatchSection("Skin tone", options: SkinTone.allCases, selected: draft.skinTone) { draft.skinTone = $0 }
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
        case .backdrop:
            optionSection("Backdrop", options: BackdropStyle.allCases, selected: draft.backdropStyle) { draft.backdropStyle = $0 }
        }
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
            draft = .default(for: hero.archetype)
        }
    }

    private func save() {
        hero.appearance = draft
        try? modelContext.save()
        HapticsService.shared.success()
        dismiss()
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

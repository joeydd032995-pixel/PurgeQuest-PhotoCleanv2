//
//  ForgeGearViews.swift
//  PurgeQuest
//
//  Forge controls for owned, compatible gear and masked material colours.
//  Both edit the Forge's draft only; nothing here writes to the hero or the
//  store. Save commits (HeroForgeView.save), Cancel discards.
//

import SwiftUI
import UIKit

/// Equippable slots the Forge manages, in display order.
enum ForgeGearSlot: String, CaseIterable, Identifiable {
    case weapon, shield

    var id: String { rawValue }

    var cosmeticType: CosmeticType {
        switch self {
        case .weapon: return .weapon
        case .shield: return .shield
        }
    }

    var title: String {
        switch self {
        case .weapon: return "Weapon"
        case .shield: return "Shield"
        }
    }

    var symbol: String {
        switch self {
        case .weapon: return "sword.fill"
        case .shield: return "shield.fill"
        }
    }
}

/// Owned gear for each slot. Items the current body can't wear are hidden (never offered), not greyed out.
struct ForgeGearPicker: View {
    let cosmetics: [CosmeticItem]
    let race: HeroRace
    let variant: Int
    @Binding var equipped: [String: String]

    private func items(for slot: ForgeGearSlot) -> [CosmeticItem] {
        cosmetics
            .filter { $0.type == slot.cosmeticType && $0.isUnlocked }
            .filter { item in
                guard let entry = ModularAssetCatalog.shared.gearItem(id: item.id) else { return true }
                return GearCompatibility.isSupported(entry, race: race, variant: variant)
            }
            .sorted { ($0.priceGems, $0.name) < ($1.priceGems, $1.name) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(ForgeGearSlot.allCases) { slot in
                let owned = items(for: slot)
                VStack(alignment: .leading, spacing: 8) {
                    Text(slot.title.uppercased())
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(.textSecondary)
                    row(title: "None", symbol: "xmark.circle", isSelected: equipped[slot.rawValue] == nil) {
                        equipped.removeValue(forKey: slot.rawValue)
                    }
                    ForEach(owned, id: \.id) { item in
                        row(title: item.name, symbol: item.iconName, isSelected: equipped[slot.rawValue] == item.id) {
                            equipped[slot.rawValue] = item.id
                        }
                    }
                    if owned.isEmpty {
                        Text("Nothing owned for this body yet. Find more in the Armory.")
                            .font(.caption2)
                            .foregroundStyle(.textTertiary)
                    }
                }
            }
        }
    }

    private func row(title: String, symbol: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticsService.shared.light()
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.bold))
                    .frame(width: 20)
                Text(title)
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
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.questAmber : Color.dungeonAsh, lineWidth: isSelected ? 1.5 : 1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// One colour well per material region the equipped gear (or, once approved, the body) exposes.
struct ForgeColorSection: View {
    /// Regions the equipped gear's masks expose, e.g. [.primary, .trim].
    let gearRegions: [MaterialRegion]
    /// Regions the body's armor layers expose; only editable once this look renders modularly.
    let bodyRegions: [MaterialRegion]
    let bodyColorsActive: Bool
    @Binding var gearMaterials: CharacterMaterialSet?
    @Binding var bodyMaterials: CharacterMaterialSet?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            group(title: "Gear colors", regions: gearRegions, set: $gearMaterials,
                  emptyNote: "Equip a weapon or shield in Gear to colour it.")
            if bodyColorsActive {
                group(title: "Body colors", regions: bodyRegions, set: $bodyMaterials, emptyNote: "This look has no colourable body regions.")
            } else {
                Text("Body colors unlock when this look's art has been approved. Until then, use Armor Dye and the hue sliders.")
                    .font(.caption2)
                    .foregroundStyle(.textTertiary)
            }
        }
    }

    @ViewBuilder
    private func group(title: String, regions: [MaterialRegion], set: Binding<CharacterMaterialSet?>, emptyNote: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.textSecondary)
            if regions.isEmpty {
                Text(emptyNote).font(.caption2).foregroundStyle(.textTertiary)
            }
            ForEach(MaterialPalette.displayOrder.filter { regions.contains($0) }, id: \.self) { region in
                HStack(spacing: 12) {
                    ColorPicker(
                        MaterialPalette.displayName(region),
                        selection: Binding(
                            get: { Self.color(MaterialPalette.selection(set.wrappedValue, region)) },
                            set: { newColor in
                                set.wrappedValue = MaterialPalette.setting(
                                    set.wrappedValue, region,
                                    to: MaterialSelection(id: "custom", color: Self.rgba(newColor)))
                            }),
                        supportsOpacity: false
                    )
                    .font(.callout.weight(.semibold))
                    Button("Reset") {
                        set.wrappedValue = MaterialPalette.normalized(MaterialPalette.setting(set.wrappedValue, region, to: nil))
                    }
                    .font(.caption.weight(.bold))
                    .disabled(MaterialPalette.selection(set.wrappedValue, region) == nil)
                    .accessibilityLabel("Reset \(MaterialPalette.displayName(region)) colour")
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 46)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.dungeonStone)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1))
                )
            }
        }
    }

    private static func color(_ selection: MaterialSelection?) -> Color {
        guard let c = selection?.color else { return Color(white: 0.6) }
        return Color(.sRGB, red: c.red, green: c.green, blue: c.blue, opacity: 1)
    }

    private static func rgba(_ color: Color) -> MaterialRGBA {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return MaterialRGBA(red: Double(r), green: Double(g), blue: Double(b), alpha: 1)
    }
}

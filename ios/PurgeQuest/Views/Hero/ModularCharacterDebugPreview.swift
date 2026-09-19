#if DEBUG && canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

/// Xcode-only comparison surface for the first `humanoid_v1` migration.
/// The left side is the production legacy renderer. The right side requests
/// the modular preview and visibly falls back to the legacy renderer when the
/// requested race/variant is not yet migrated.
struct ModularCharacterDebugPreview: View {
    let hero: Hero
    var race: HeroRace = .valkyrie
    var variant: Int = 1
    var equipped: [CosmeticItem] = []
    var size: CGFloat = 150

    private let frameIndex = 0

    private var clampedVariant: Int {
        min(max(variant, 1), race.variantCount)
    }

    private var appearance: HeroAppearance {
        var look = HeroAppearance.default(for: race)
        look.paintVariant = clampedVariant
        return look
    }

    private var plan: CharacterRenderPlan {
        ModularCharacterPreviewRenderer.shared.availability(race: race, variant: clampedVariant)
    }

    private var weaponResource: String? {
        guard let item = equipped.first(where: { $0.type == .weapon }) else { return nil }
        return GearCatalog.design(id: item.id)?.resourceName
    }

    private var shieldResource: String? {
        guard let item = equipped.first(where: { $0.type == .shield }) else { return nil }
        return GearCatalog.design(id: item.id)?.resourceName
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("DEBUG", systemImage: "hammer.fill")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.questAmber)
                Spacer()
                Text("humanoid_v1")
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(.textSecondary)
            }

            HStack(alignment: .top, spacing: 10) {
                renderPanel(title: "Legacy", subtitle: "Production fallback") {
                    HeroSpriteView(
                        hero: hero,
                        appearance: appearance,
                        equipped: equipped,
                        size: size,
                        isAnimated: false
                    )
                    .frame(height: size)
                }

                renderPanel(
                    title: "Modular",
                    subtitle: plan.path == .modular ? "8 anatomy parts" : "Fallback active"
                ) {
                    modularOrFallback
                        .frame(height: size)
                }
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: plan.path == .modular ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                    .foregroundStyle(plan.path == .modular ? AnyShapeStyle(Color.gemEmerald) : AnyShapeStyle(Color.questAmber))
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.path == .modular ? "Modular anatomy path active" : "Legacy fallback active")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.textPrimary)
                    Text(statusDetail)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dungeonStone.opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dungeonAsh, lineWidth: 1))
        )
    }

    @ViewBuilder
    private var modularOrFallback: some View {
        if plan.path == .modular,
           let image = ModularCharacterPreviewRenderer.shared.frame(
                race: race,
                variant: clampedVariant,
                animation: "Idle",
                frameIndex: frameIndex,
                weaponResource: weaponResource,
                shieldResource: shieldResource,
                titanWeapon: hero.titanWeaponUnlocked
           ) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            HeroSpriteView(
                hero: hero,
                appearance: appearance,
                equipped: equipped,
                size: size,
                isAnimated: false
            )
        }
    }

    private var statusDetail: String {
        if plan.path == .modular {
            return "Valkyrie v1 • athletic • anatomy manifests + legacy accessory passthrough"
        }
        return plan.reasons.joined(separator: " • ")
    }

    private func renderPanel<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 6) {
            content()
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.textPrimary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.dungeonVoid.opacity(0.42))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh.opacity(0.8), lineWidth: 1))
        )
    }
}

#Preview("Valkyrie v1 • modular") {
    ModularCharacterDebugPreview(hero: Hero())
        .padding()
        .background(Color.dungeonVoid)
        .preferredColorScheme(.dark)
}

#Preview("Valkyrie v2 • fallback") {
    ModularCharacterDebugPreview(hero: Hero(), variant: 2)
        .padding()
        .background(Color.dungeonVoid)
        .preferredColorScheme(.dark)
}
#endif

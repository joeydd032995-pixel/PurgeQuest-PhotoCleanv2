import Foundation

/// First production-shaped anatomy migration onto `humanoid_v1`.
///
/// Valkyrie v1 is intentionally the only modular set in this vertical slice.
/// The existing PNGs are reused as-is and remain visually paired with their
/// original SCML pose data. Face, weapon, shield, and FX are not anatomy and
/// stay outside this recipe so the DEBUG renderer can treat them as legacy
/// passthrough layers while production rendering remains unchanged.
nonisolated enum ValkyrieV1ModularAssetSet {
    static let race: HeroRace = .valkyrie
    static let variant = 1
    static let profile: BodyProfile = .athletic
    static let artBase = "valkyrie_v1"

    private static let anatomy: [(slot: CharacterSlot, stem: String, coverage: [String])] = [
        (.head, "head", ["head"]),
        (.torso, "body", ["torso"]),
        (.leftArm, "left_arm", ["arm.left"]),
        (.rightArm, "right_arm", ["arm.right"]),
        (.leftHand, "left_hand", ["hand.left"]),
        (.rightHand, "right_hand", ["hand.right"]),
        (.leftLeg, "left_leg", ["leg.left"]),
        (.rightLeg, "right_leg", ["leg.right"])
    ]

    static let manifests: [PartManifest] = anatomy.map { entry in
        PartManifest(
            id: "anatomy.valkyrie.v1.\(entry.stem)",
            resourceBaseName: "\(artBase)_\(entry.stem)",
            slot: entry.slot,
            sourceRace: race,
            referenceProfile: profile,
            nativeProfiles: [profile],
            adaptedProfiles: [.standard, .slender],
            scaleXRange: .init(min: 0.85, max: 1.15),
            scaleYRange: .init(min: 0.85, max: 1.15),
            coverageTags: entry.coverage,
            representation: .modular
        )
    }

    static let recipe = ModularCharacterRecipe(
        ancestry: race,
        bodyProfile: profile,
        parts: manifests.map { CharacterPartSelection(slot: $0.slot, partID: $0.id) }
    )

    static let renderPlan = CharacterRenderPlanner.plan(for: recipe, manifests: manifests)

    private static let manifestsByStem: [String: PartManifest] = Dictionary(
        uniqueKeysWithValues: manifests.map { manifest in
            (resourceStem(manifest.resourceBaseName), manifest)
        }
    )

    static func manifest(forSCMLFileName fileName: String) -> PartManifest? {
        manifestsByStem[normalizedStem(fileName)]
    }

    static func resourceBaseName(forSCMLFileName fileName: String) -> String? {
        manifest(forSCMLFileName: fileName)?.resourceBaseName
    }

    /// Only Valkyrie v1 is authorized to take the modular preview path in
    /// this phase. Every other request explicitly returns the legacy path.
    static func previewPlan(race requestedRace: HeroRace, variant requestedVariant: Int) -> CharacterRenderPlan {
        guard requestedRace == race else {
            return .init(path: .legacy, reasons: ["preview-race:\(requestedRace.rawValue)"])
        }
        guard requestedVariant == variant else {
            return .init(path: .legacy, reasons: ["preview-variant:\(requestedVariant)"])
        }
        return renderPlan
    }

    static func normalizedStem(_ fileName: String) -> String {
        let stem = (fileName as NSString).deletingPathExtension
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
        return resourceStem(stem)
    }

    private static func resourceStem(_ resourceBaseName: String) -> String {
        let prefix = artBase + "_"
        if resourceBaseName.hasPrefix(prefix) {
            return String(resourceBaseName.dropFirst(prefix.count))
        }
        return resourceBaseName
    }
}

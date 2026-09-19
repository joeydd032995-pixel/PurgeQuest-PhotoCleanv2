import Foundation

nonisolated enum BodyProfile: String, CaseIterable, Codable, Sendable {
    case slender
    case standard
    case athletic
    case skeletal
    case brute

    var metrics: BodyProfileMetrics {
        switch self {
        case .slender:
            return .init(shoulderWidth: 0.90, torsoWidth: 0.95, armLength: 1.02, armThickness: 0.90, legLength: 1.04, legThickness: 0.92, headScale: 0.96)
        case .standard:
            return .init(shoulderWidth: 1.00, torsoWidth: 1.00, armLength: 1.00, armThickness: 1.00, legLength: 1.00, legThickness: 1.00, headScale: 1.00)
        case .athletic:
            return .init(shoulderWidth: 1.10, torsoWidth: 1.04, armLength: 1.05, armThickness: 1.08, legLength: 1.02, legThickness: 1.05, headScale: 1.00)
        case .skeletal:
            return .init(shoulderWidth: 0.94, torsoWidth: 0.90, armLength: 1.00, armThickness: 0.78, legLength: 1.02, legThickness: 0.76, headScale: 0.98)
        case .brute:
            return .init(shoulderWidth: 1.24, torsoWidth: 1.16, armLength: 1.06, armThickness: 1.18, legLength: 0.98, legThickness: 1.16, headScale: 1.08)
        }
    }
}

nonisolated struct BodyProfileMetrics: Codable, Equatable, Sendable {
    let shoulderWidth: Double
    let torsoWidth: Double
    let armLength: Double
    let armThickness: Double
    let legLength: Double
    let legThickness: Double
    let headScale: Double
}

nonisolated enum CharacterSlot: String, CaseIterable, Codable, Sendable {
    case head
    case torso
    case leftArm
    case rightArm
    case leftHand
    case rightHand
    case leftLeg
    case rightLeg
    case racialFeature
    case helmet
    case leftShoulder
    case rightShoulder
    case chestArmor
    case leftGauntlet
    case rightGauntlet
    case waistArmor
    case leftLegArmor
    case rightLegArmor
    case leftBoot
    case rightBoot
    case mainHand
    case offHand
    case back
    case rearFX
    case frontFX
}

nonisolated enum CharacterPartRepresentation: String, Codable, Sendable {
    case modular
    case legacyCombined
}

nonisolated enum CompatibilityLevel: String, Codable, Sendable {
    case native
    case adapted
    case unsupported
}

nonisolated struct ScaleRange: Codable, Equatable, Sendable {
    let min: Double
    let max: Double

    init(min: Double = 0.90, max: Double = 1.10) {
        self.min = min
        self.max = max
    }

    func contains(_ value: Double) -> Bool {
        value >= min && value <= max
    }
}

nonisolated struct PartFitOverride: Codable, Equatable, Sendable {
    let scaleX: Double
    let scaleY: Double
    let offsetX: Double
    let offsetY: Double

    init(scaleX: Double = 1, scaleY: Double = 1, offsetX: Double = 0, offsetY: Double = 0) {
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
}

nonisolated struct PartFitTransform: Codable, Equatable, Sendable {
    let scaleX: Double
    let scaleY: Double
    let offsetX: Double
    let offsetY: Double
}

nonisolated enum MaterialRegion: String, CaseIterable, Codable, Sendable {
    case skin
    case hair
    case eyes
    case primary
    case secondary
    case trim
    case leather
    case emissive
}

nonisolated struct MaterialRGBA: Codable, Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
        self.alpha = Self.clamp(alpha)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            red: try container.decode(Double.self, forKey: .red),
            green: try container.decode(Double.self, forKey: .green),
            blue: try container.decode(Double.self, forKey: .blue),
            alpha: try container.decode(Double.self, forKey: .alpha)
        )
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

nonisolated struct MaterialSelection: Codable, Equatable, Sendable {
    let id: String
    let color: MaterialRGBA
}

nonisolated struct CharacterMaterialSet: Codable, Equatable, Sendable {
    var skin: MaterialSelection?
    var hair: MaterialSelection?
    var eyes: MaterialSelection?
    var armorPrimary: MaterialSelection?
    var armorSecondary: MaterialSelection?
    var armorTrim: MaterialSelection?
    var leather: MaterialSelection?
    var emissive: MaterialSelection?

    init(
        skin: MaterialSelection? = nil,
        hair: MaterialSelection? = nil,
        eyes: MaterialSelection? = nil,
        armorPrimary: MaterialSelection? = nil,
        armorSecondary: MaterialSelection? = nil,
        armorTrim: MaterialSelection? = nil,
        leather: MaterialSelection? = nil,
        emissive: MaterialSelection? = nil
    ) {
        self.skin = skin
        self.hair = hair
        self.eyes = eyes
        self.armorPrimary = armorPrimary
        self.armorSecondary = armorSecondary
        self.armorTrim = armorTrim
        self.leather = leather
        self.emissive = emissive
    }
}

nonisolated struct CharacterPartSelection: Codable, Equatable, Sendable {
    let slot: CharacterSlot
    let partID: String
}

nonisolated struct PartManifest: Codable, Equatable, Sendable {
    let id: String
    let resourceBaseName: String
    let slot: CharacterSlot
    let rigID: String
    let sourceRace: HeroRace?
    let referenceProfile: BodyProfile
    let nativeProfiles: [BodyProfile]
    let adaptedProfiles: [BodyProfile]
    let scaleXRange: ScaleRange
    let scaleYRange: ScaleRange
    let profileOverrides: [String: PartFitOverride]
    let coverageTags: [String]
    let materialRegions: [MaterialRegion]
    let representation: CharacterPartRepresentation

    init(
        id: String,
        resourceBaseName: String,
        slot: CharacterSlot,
        rigID: String = ModularCharacterRecipe.canonicalRigID,
        sourceRace: HeroRace? = nil,
        referenceProfile: BodyProfile = .standard,
        nativeProfiles: [BodyProfile] = [.standard],
        adaptedProfiles: [BodyProfile] = [],
        scaleXRange: ScaleRange = .init(),
        scaleYRange: ScaleRange = .init(),
        profileOverrides: [String: PartFitOverride] = [:],
        coverageTags: [String] = [],
        materialRegions: [MaterialRegion] = [],
        representation: CharacterPartRepresentation = .modular
    ) {
        self.id = id
        self.resourceBaseName = resourceBaseName
        self.slot = slot
        self.rigID = rigID
        self.sourceRace = sourceRace
        self.referenceProfile = referenceProfile
        self.nativeProfiles = nativeProfiles
        self.adaptedProfiles = adaptedProfiles
        self.scaleXRange = scaleXRange
        self.scaleYRange = scaleYRange
        self.profileOverrides = profileOverrides
        self.coverageTags = coverageTags
        self.materialRegions = materialRegions
        self.representation = representation
    }
}

nonisolated struct ModularCharacterRecipe: Codable, Equatable, Sendable {
    static let canonicalRigID = "humanoid_v1"

    let ancestry: HeroRace
    let rigID: String
    let bodyProfile: BodyProfile
    let parts: [CharacterPartSelection]
    let materials: CharacterMaterialSet

    init(
        ancestry: HeroRace,
        rigID: String = ModularCharacterRecipe.canonicalRigID,
        bodyProfile: BodyProfile,
        parts: [CharacterPartSelection],
        materials: CharacterMaterialSet = .init()
    ) {
        self.ancestry = ancestry
        self.rigID = rigID
        self.bodyProfile = bodyProfile
        self.parts = parts
        self.materials = materials
    }

    func partID(for slot: CharacterSlot) -> String? {
        parts.first(where: { $0.slot == slot })?.partID
    }

    var renderFingerprint: String {
        let partKey = parts
            .sorted { $0.slot.rawValue < $1.slot.rawValue }
            .map { Self.fingerprintField($0.slot.rawValue) + Self.fingerprintField($0.partID) }
            .joined()
        return [
            Self.fingerprintField(rigID),
            Self.fingerprintField(ancestry.rawValue),
            Self.fingerprintField(bodyProfile.rawValue),
            partKey,
            Self.fingerprintField(Self.materialFingerprint(materials))
        ].joined()
    }

    private static func fingerprintField(_ value: String) -> String {
        "\(value.utf8.count):\(value)"
    }

    private static func materialFingerprint(_ materials: CharacterMaterialSet) -> String {
        let entries: [(String, MaterialSelection?)] = [
            ("skin", materials.skin),
            ("hair", materials.hair),
            ("eyes", materials.eyes),
            ("primary", materials.armorPrimary),
            ("secondary", materials.armorSecondary),
            ("trim", materials.armorTrim),
            ("leather", materials.leather),
            ("emissive", materials.emissive)
        ]
        return entries.map { key, value in
            guard let value else { return "\(key)=-" }
            let c = value.color
            return "\(key)=\(value.id):\(c.red),\(c.green),\(c.blue),\(c.alpha)"
        }.joined(separator: "|")
    }
}

nonisolated enum PartFitter {
    static func fit(_ manifest: PartManifest, to targetProfile: BodyProfile) -> PartFitTransform? {
        if let override = manifest.profileOverrides[targetProfile.rawValue] {
            guard manifest.scaleXRange.contains(override.scaleX), manifest.scaleYRange.contains(override.scaleY) else {
                return nil
            }
            return .init(scaleX: override.scaleX, scaleY: override.scaleY, offsetX: override.offsetX, offsetY: override.offsetY)
        }

        let source = manifest.referenceProfile.metrics
        let target = targetProfile.metrics
        let pair = scalePair(for: manifest.slot, source: source, target: target)
        guard manifest.scaleXRange.contains(pair.x), manifest.scaleYRange.contains(pair.y) else { return nil }
        return .init(scaleX: pair.x, scaleY: pair.y, offsetX: 0, offsetY: 0)
    }

    private static func scalePair(
        for slot: CharacterSlot,
        source: BodyProfileMetrics,
        target: BodyProfileMetrics
    ) -> (x: Double, y: Double) {
        switch slot {
        case .head, .helmet:
            let scale = target.headScale / source.headScale
            return (scale, scale)
        case .torso, .chestArmor, .waistArmor:
            return (target.torsoWidth / source.torsoWidth, 1)
        case .leftShoulder, .rightShoulder:
            let scale = target.shoulderWidth / source.shoulderWidth
            return (scale, scale)
        case .leftArm, .rightArm, .leftGauntlet, .rightGauntlet:
            return (target.armThickness / source.armThickness, target.armLength / source.armLength)
        case .leftHand, .rightHand:
            let scale = target.armThickness / source.armThickness
            return (scale, scale)
        case .leftLeg, .rightLeg, .leftLegArmor, .rightLegArmor, .leftBoot, .rightBoot:
            return (target.legThickness / source.legThickness, target.legLength / source.legLength)
        case .racialFeature, .mainHand, .offHand, .back, .rearFX, .frontFX:
            return (1, 1)
        }
    }
}

nonisolated enum CharacterCompatibilityResolver {
    static func level(for manifest: PartManifest, recipe: ModularCharacterRecipe) -> CompatibilityLevel {
        guard manifest.rigID == recipe.rigID else { return .unsupported }
        guard PartFitter.fit(manifest, to: recipe.bodyProfile) != nil else { return .unsupported }
        if manifest.nativeProfiles.contains(recipe.bodyProfile) { return .native }
        if manifest.adaptedProfiles.contains(recipe.bodyProfile) { return .adapted }
        return .unsupported
    }
}

nonisolated struct CharacterRenderPlan: Equatable, Sendable {
    enum Path: String, Equatable, Sendable {
        case modular
        case legacy
    }

    let path: Path
    let reasons: [String]
}

nonisolated enum CharacterRenderPlanner {
    static let mandatoryAnatomySlots: Set<CharacterSlot> = [
        .head, .torso, .leftArm, .rightArm,
        .leftHand, .rightHand, .leftLeg, .rightLeg
    ]

    static func plan(for recipe: ModularCharacterRecipe, manifests: [PartManifest]) -> CharacterRenderPlan {
        var reasons: [String] = []
        var manifestsByID: [String: PartManifest] = [:]
        var ambiguousManifestIDs = Set<String>()
        for manifest in manifests {
            if manifestsByID[manifest.id] != nil {
                ambiguousManifestIDs.insert(manifest.id)
            } else {
                manifestsByID[manifest.id] = manifest
            }
        }

        let selectedSlots = recipe.parts.map(\.slot)
        let duplicateSlots = Dictionary(grouping: selectedSlots, by: { $0 })
            .filter { $0.value.count > 1 }
            .keys
        reasons.append(contentsOf: duplicateSlots.map { "duplicate-slot:\($0.rawValue)" })

        let missingSlots = mandatoryAnatomySlots.subtracting(selectedSlots)
        reasons.append(contentsOf: missingSlots.map { "missing-slot:\($0.rawValue)" })

        for selection in recipe.parts {
            guard !ambiguousManifestIDs.contains(selection.partID) else {
                reasons.append("ambiguous:\(selection.partID)")
                continue
            }
            guard let manifest = manifestsByID[selection.partID] else {
                reasons.append("missing:\(selection.partID)")
                continue
            }
            if manifest.slot != selection.slot {
                reasons.append("slot-mismatch:\(selection.slot.rawValue):\(selection.partID)")
            }
            if manifest.representation != .modular {
                reasons.append("legacy:\(selection.partID)")
            }
            if CharacterCompatibilityResolver.level(for: manifest, recipe: recipe) == .unsupported {
                reasons.append("unsupported:\(selection.partID)")
            }
        }

        return reasons.isEmpty
            ? .init(path: .modular, reasons: [])
            : .init(path: .legacy, reasons: reasons.sorted())
    }
}

nonisolated struct LegacyCharacterMigration: Equatable, Sendable {
    let recipe: ModularCharacterRecipe
    let manifests: [PartManifest]
}

nonisolated enum LegacyCharacterRecipeFactory {
    static func make(from appearance: HeroAppearance, fallbackRace: HeroRace) -> LegacyCharacterMigration {
        let race = appearance.race ?? fallbackRace
        let variant = min(max(appearance.paintVariant, 1), race.variantCount)
        let base = race.artBase(variant: variant)
        let profile = race.defaultBodyProfile
        let slots: [(CharacterSlot, String)] = [
            (.head, "head"),
            (.torso, "body"),
            (.leftArm, "left_arm"),
            (.rightArm, "right_arm"),
            (.leftHand, "left_hand"),
            (.rightHand, "right_hand"),
            (.leftLeg, "left_leg"),
            (.rightLeg, "right_leg")
        ]

        let manifests = slots.map { slot, stem in
            PartManifest(
                id: "legacy.\(base).\(stem)",
                resourceBaseName: "\(base)_\(stem)",
                slot: slot,
                sourceRace: race,
                referenceProfile: profile,
                nativeProfiles: [profile],
                scaleXRange: .init(min: 0.75, max: 1.30),
                scaleYRange: .init(min: 0.75, max: 1.30),
                representation: .legacyCombined
            )
        }
        let parts = manifests.map { CharacterPartSelection(slot: $0.slot, partID: $0.id) }
        let recipe = ModularCharacterRecipe(
            ancestry: race,
            bodyProfile: profile,
            parts: parts
        )
        return .init(recipe: recipe, manifests: manifests)
    }
}

nonisolated extension HeroRace {
    var defaultBodyProfile: BodyProfile {
        switch self {
        case .elven, .seer, .lostSouls:
            return .slender
        case .valkyrie, .vampyri:
            return .athletic
        case .scarredOnes:
            return .standard
        case .skeletalUndead:
            return .skeletal
        case .golem:
            return .brute
        }
    }
}

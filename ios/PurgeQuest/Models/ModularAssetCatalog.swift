//
//  ModularAssetCatalog.swift
//  PurgeQuest
//
//  Decodes the two generated manifests bundled under Art/Modular
//  (tools/modular_assets): modular_races_manifest.json (separated anatomy /
//  armor / headgear layers with masks and fit tables) and
//  modular_gear_manifest.json (held-gear grips, per-pack holds, head fits).
//  Loading never throws: a missing or undecodable manifest yields an empty
//  catalog, so every recipe resolves to the legacy renderer instead of a
//  blank or partial hero.
//

import Foundation

nonisolated struct StringAnchors: Codable, Equatable, Sendable {
    /// Bow tip positions in bow-image pixels (y-down).
    let top: [Double]
    let bottom: [Double]
}

nonisolated struct HeadFit: Codable, Equatable, Sendable {
    /// Head-PNG pixels: horizontal centre, brim line, and the width a headpiece should span.
    let cx: Double
    let baseY: Double
    let widthPx: Double
    let headPngSize: [Double]
}

nonisolated struct HeadpieceNominal: Codable, Equatable, Sendable {
    /// Headpiece art is authored with its brim line at (anchorU, anchorV) and `width` px of dome at that line.
    let width: Double
    let anchorU: Double
    let anchorV: Double
}

/// Per-art-pack anchor data. `hold` is where the pack's own baked weapon/shield is gripped, in SCML
/// units relative to the anchor pivot (y-down); `pivotPx` is that pivot measured from the image's top-left.
nonisolated struct PackAnchors: Codable, Equatable, Sendable {
    let weaponAnchor: String
    let weaponPivotPx: [Double]
    let weaponHold: [Double]
    let shieldAnchor: String
    let shieldPivotPx: [Double]
    let shieldHold: [Double]
    let headFit: HeadFit
    /// Arrow-tail (nock) position in arrow-image pixels; present only on bow packs.
    let arrowNock: [Double]?
}

nonisolated enum HeldGearKind: String, Codable, Sendable {
    case sword, bow, staff, hammer, shield, headpiece
}

nonisolated struct HeldGearEntry: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let name: String
    let kind: HeldGearKind
    /// mainHand, offHand, or head.
    let slot: String
    let resourceName: String
    let group: String
    let imageWidth: Double
    let imageHeight: Double
    /// Grip point in image pixels (y-down).
    let gripPx: [Double]
    let scale: Double
    let rotationDegrees: Double
    /// front (drawn last) or overHead (headpieces: on the bare head, under the face overlay).
    let layer: String
    let supportedPacks: [String]
    let maskResources: [String: String]
    let regionLuma: [String: Double]
    let stringAnchors: StringAnchors?
    /// Opaque pixel bounds [x0, y0, x1, y1] in image pixels (headpieces use it so empty margins don't enlarge the canvas).
    let contentBox: [Double]?
    let verification: AssetVerificationRecord

    private enum CodingKeys: String, CodingKey {
        case id, name, kind, slot, resourceName, group, imageWidth, imageHeight, gripPx, scale
        case rotationDegrees, layer, supportedPacks, maskResources, regionLuma, stringAnchors, contentBox, verification
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        kind = try c.decode(HeldGearKind.self, forKey: .kind)
        slot = try c.decode(String.self, forKey: .slot)
        resourceName = try c.decode(String.self, forKey: .resourceName)
        group = (try? c.decodeIfPresent(String.self, forKey: .group)) ?? ""
        imageWidth = try c.decode(Double.self, forKey: .imageWidth)
        imageHeight = try c.decode(Double.self, forKey: .imageHeight)
        gripPx = try c.decode([Double].self, forKey: .gripPx)
        scale = (try? c.decodeIfPresent(Double.self, forKey: .scale)) ?? 1
        rotationDegrees = (try? c.decodeIfPresent(Double.self, forKey: .rotationDegrees)) ?? 0
        layer = (try? c.decodeIfPresent(String.self, forKey: .layer)) ?? "front"
        supportedPacks = try c.decode([String].self, forKey: .supportedPacks)
        maskResources = (try? c.decodeIfPresent([String: String].self, forKey: .maskResources)) ?? [:]
        regionLuma = (try? c.decodeIfPresent([String: Double].self, forKey: .regionLuma)) ?? [:]
        stringAnchors = try? c.decodeIfPresent(StringAnchors.self, forKey: .stringAnchors)
        contentBox = try? c.decodeIfPresent([Double].self, forKey: .contentBox)
        verification = (try? c.decodeIfPresent(AssetVerificationRecord.self, forKey: .verification)) ?? .init(status: .mapped)
    }
}

nonisolated struct ModularGearManifest: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let titanScale: Double
    let headpieceNominal: HeadpieceNominal?
    let packs: [String: PackAnchors]
    let items: [HeldGearEntry]
}

nonisolated struct ModularRacesManifest: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let rigID: String
    let parts: [PartManifest]
}

nonisolated final class ModularAssetCatalog: Sendable {
    let races: ModularRacesManifest?
    let gear: ModularGearManifest?
    private let gearByID: [String: HeldGearEntry]
    private let partsByPack: [String: [PartManifest]]

    init(racesData: Data?, gearData: Data?) {
        let decoder = JSONDecoder()
        races = racesData.flatMap { try? decoder.decode(ModularRacesManifest.self, from: $0) }
        gear = gearData.flatMap { try? decoder.decode(ModularGearManifest.self, from: $0) }
        gearByID = Dictionary((gear?.items ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        partsByPack = Dictionary(grouping: races?.parts ?? [], by: { $0.pack ?? "" })
    }

    static let empty = ModularAssetCatalog(racesData: nil, gearData: nil)

    /// Bundled catalog. Read once; absent resources produce an empty (all-legacy) catalog.
    static let shared: ModularAssetCatalog = load(bundle: .main)

    static func load(bundle: Bundle) -> ModularAssetCatalog {
        func data(_ name: String) -> Data? {
            bundle.url(forResource: name, withExtension: "json").flatMap { try? Data(contentsOf: $0) }
        }
        return ModularAssetCatalog(racesData: data("modular_races_manifest"), gearData: data("modular_gear_manifest"))
    }

    var parts: [PartManifest] { races?.parts ?? [] }
    var gearItems: [HeldGearEntry] { gear?.items ?? [] }
    var titanScale: Double { gear?.titanScale ?? HeldGearFit.titanScale }

    func gearItem(id: String) -> HeldGearEntry? { gearByID[id] }
    func anchors(pack: String) -> PackAnchors? { gear?.packs[pack] }
    func parts(forPack pack: String) -> [PartManifest] { partsByPack[pack] ?? [] }
}

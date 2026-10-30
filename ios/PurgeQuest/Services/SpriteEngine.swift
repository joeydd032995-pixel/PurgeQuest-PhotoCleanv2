//
//  SpriteEngine.swift
//  PurgeQuest
//
//  Renders the illustrated race sprites. Each race pack ships a Spriter
//  (SCML) project describing how layered part PNGs (body, head, faces, arms,
//  hands, legs, weapon, shield, FX) are placed per animation frame. The
//  projects are skeletal: every part attaches to a bone, and each bone/part
//  stores only its offset and angle relative to its parent. The engine
//  parses that project, resolves the full parent chain into world-space
//  placements, composites parts into frames, applies the hero's recolor
//  choices (hue shifts + armor dye), and swaps the baked weapon/shield for
//  whatever the player has equipped.
//

import UIKit
import CoreImage
import SwiftUI

// MARK: - Document model

nonisolated struct SpriteFileDef {
    let name: String
    let width: CGFloat
    let height: CGFloat
    /// Default pivot (fractions of the image, y-up) when a placement omits it.
    let pivotX: CGFloat
    let pivotY: CGFloat
}

nonisolated struct SpritePlacement {
    let file: SpriteFileDef
    /// World-space position of the part's pivot (Spriter y-up space).
    let x: CGFloat
    let y: CGFloat
    /// World-space angle in degrees, counter-clockwise in y-up space.
    let angle: CGFloat
    let pivotX: CGFloat
    let pivotY: CGFloat
    let zIndex: Int
    let alpha: CGFloat
}

nonisolated struct SpriteAnimation {
    let name: String
    let frames: [[SpritePlacement]]
    var frameCount: Int { frames.count }
}

/// One race's parsed animation project. `origin` is the world-space point
/// mapped to the canvas's bottom-left corner.
nonisolated final class SpriterDocument {
    let animations: [String: SpriteAnimation]
    let canvasSize: CGSize
    let origin: CGPoint
    /// Transparent margin around the union of all visible parts.
    static let canvasPadding: CGFloat = 20

    init(animations: [String: SpriteAnimation], canvasSize: CGSize, origin: CGPoint) {
        self.animations = animations
        self.canvasSize = canvasSize
        self.origin = origin
    }

    /// Loads and parses the race's `<artBase>.scml` from the app bundle.
    static func load(race: HeroRace, variant: Int) -> SpriterDocument? {
        let base = race.artBase(variant: variant)
        guard let url = Bundle.main.url(forResource: base, withExtension: "scml"),
              let data = try? Data(contentsOf: url) else { return nil }
        return SCMLParser(data: data).parse()
    }

    /// Converts a world-space point (Spriter y-up) into canvas coordinates.
    func screenPoint(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x - origin.x, y: canvasSize.height - (y - origin.y))
    }
}

// MARK: - SCML parsing

nonisolated private struct ScmlObject {
    let folder: Int
    let file: Int
    let x: CGFloat
    let y: CGFloat
    let angle: CGFloat
    let pivotX: CGFloat
    let pivotY: CGFloat
    let alpha: CGFloat
}

nonisolated private struct ScmlBone {
    let x: CGFloat
    let y: CGFloat
    let angle: CGFloat
}

/// A mainline bone reference: which bone timeline key to sample, and which
/// earlier bone (by id) it attaches to.
nonisolated private struct MainlineBone {
    let id: Int
    let timeline: Int
    let key: Int
    let parent: Int?
}

/// A mainline object reference: which sprite timeline key to sample, which
/// bone it attaches to, and its draw order.
nonisolated private struct MainlineRef {
    let timeline: Int
    let key: Int
    let parent: Int?
    let zIndex: Int
}

/// One mainline key — the bones and object refs that make up one frame.
nonisolated private struct MainlineFrame {
    var bones: [MainlineBone] = []
    var objects: [MainlineRef] = []
}

nonisolated private struct SCMLParser: @unchecked Sendable {
    private let data: Data

    init(data: Data) { self.data = data }

    func parse() -> SpriterDocument? {
        let delegate = ParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse(), !delegate.animations.isEmpty else { return nil }

        // Union bounds across every visible placement, accounting for each
        // part's world rotation. Hidden parts (alpha 0) and the slash effect
        // are excluded so the canvas hugs the character.
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for animation in delegate.animations.values {
            for frame in animation.frames {
                for p in frame where p.alpha > 0.01 {
                    if p.file.name.lowercased().hasPrefix("slashfx") { continue }
                    let rad = p.angle * .pi / 180
                    let cosA = cos(rad)
                    let sinA = sin(rad)
                    // Image rect corners relative to the pivot, y-up.
                    let corners: [(CGFloat, CGFloat)] = [
                        (-p.pivotX * p.file.width, -p.pivotY * p.file.height),
                        ((1 - p.pivotX) * p.file.width, -p.pivotY * p.file.height),
                        ((1 - p.pivotX) * p.file.width, (1 - p.pivotY) * p.file.height),
                        (-p.pivotX * p.file.width, (1 - p.pivotY) * p.file.height)
                    ]
                    for (cx, cy) in corners {
                        let x = p.x + cx * cosA - cy * sinA
                        let y = p.y + cx * sinA + cy * cosA
                        minX = min(minX, x)
                        maxX = max(maxX, x)
                        minY = min(minY, y)
                        maxY = max(maxY, y)
                    }
                }
            }
        }
        guard minX.isFinite, minY.isFinite else { return nil }
        let pad = SpriterDocument.canvasPadding
        let origin = CGPoint(x: minX - pad, y: minY - pad)
        let size = CGSize(width: (maxX + pad) - origin.x, height: (maxY + pad) - origin.y)
        return SpriterDocument(animations: delegate.animations, canvasSize: size, origin: origin)
    }
}

nonisolated private final class ParserDelegate: NSObject, XMLParserDelegate {
    var folders: [Int: [Int: SpriteFileDef]] = [:]
    var animations: [String: SpriteAnimation] = [:]

    private var stack: [String] = []
    private var folderID: Int = 0
    private var animationName: String?
    private var mainlineFrames: [MainlineFrame] = []
    private var currentFrame = MainlineFrame()
    private var inMainline = false
    private var boneTimelines: [Int: [Int: ScmlBone]] = [:]
    private var timelines: [Int: [Int: ScmlObject]] = [:]
    private var currentTimelineID: Int?
    private var currentTimelineKey: Int?

    private func attr(_ attributes: [String: String], _ key: String) -> String? {
        attributes[key] ?? attributes[key.replacingOccurrences(of: "_", with: "-")]
    }

    private func num(_ attributes: [String: String], _ key: String, _ fallback: CGFloat) -> CGFloat {
        guard let raw = attr(attributes, key), let value = Double(raw), value.isFinite else { return fallback }
        return CGFloat(value)
    }

    private func int(_ attributes: [String: String], _ key: String, _ fallback: Int) -> Int {
        guard let raw = attr(attributes, key), let value = Int(raw) else { return fallback }
        return value
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        stack.append(name)
        switch name {
        case "folder":
            folderID = int(attributes, "id", 0)
        case "file":
            let fileID = int(attributes, "id", 0)
            let def = SpriteFileDef(
                name: attr(attributes, "name") ?? "",
                width: num(attributes, "width", 1),
                height: num(attributes, "height", 1),
                pivotX: num(attributes, "pivot_x", 0),
                pivotY: num(attributes, "pivot_y", 1)
            )
            folders[folderID, default: [:]][fileID] = def
        case "animation":
            animationName = attr(attributes, "name")
            mainlineFrames = []
            boneTimelines = [:]
            timelines = [:]
        case "mainline":
            inMainline = true
        case "timeline":
            currentTimelineID = int(attributes, "id", -1)
        case "key":
            if inMainline {
                currentFrame = MainlineFrame()
            } else {
                currentTimelineKey = int(attributes, "id", -1)
            }
        case "bone_ref":
            guard inMainline else { break }
            currentFrame.bones.append(MainlineBone(
                id: int(attributes, "id", -1),
                timeline: int(attributes, "timeline", -1),
                key: int(attributes, "key", -1),
                parent: attr(attributes, "parent").flatMap { Int($0) }
            ))
        case "object_ref":
            guard inMainline else { break }
            currentFrame.objects.append(MainlineRef(
                timeline: int(attributes, "timeline", -1),
                key: int(attributes, "key", -1),
                parent: attr(attributes, "parent").flatMap { Int($0) },
                zIndex: int(attributes, "z_index", 0)
            ))
        case "bone":
            guard let tl = currentTimelineID, let keyID = currentTimelineKey else { break }
            boneTimelines[tl, default: [:]][keyID] = ScmlBone(
                x: num(attributes, "x", 0),
                y: num(attributes, "y", 0),
                angle: num(attributes, "angle", 0)
            )
        case "object":
            guard let tl = currentTimelineID, let keyID = currentTimelineKey else { break }
            let obj = ScmlObject(
                folder: int(attributes, "folder", 0),
                file: int(attributes, "file", 0),
                x: num(attributes, "x", 0),
                y: num(attributes, "y", 0),
                angle: num(attributes, "angle", 0),
                pivotX: num(attributes, "pivot_x", CGFloat.nan),
                pivotY: num(attributes, "pivot_y", CGFloat.nan),
                alpha: num(attributes, "a", 1)
            )
            timelines[tl, default: [:]][keyID] = obj
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        switch name {
        case "mainline":
            inMainline = false
        case "key":
            if inMainline {
                mainlineFrames.append(currentFrame)
                currentFrame = MainlineFrame()
            }
        case "animation":
            finishAnimation()
        default:
            break
        }
        if !stack.isEmpty { stack.removeLast() }
    }

    private func finishAnimation() {
        guard let name = animationName, !mainlineFrames.isEmpty else {
            animationName = nil
            return
        }
        var frames: [[SpritePlacement]] = []
        for mainline in mainlineFrames {
            // Resolve the bone skeleton first. SCML lists parents before
            // children, so one ordered pass memoizes every world transform.
            var boneWorlds: [Int: (position: CGPoint, angle: CGFloat)] = [:]
            for ref in mainline.bones {
                let bone = boneTimelines[ref.timeline]?[ref.key] ?? ScmlBone(x: 0, y: 0, angle: 0)
                let world: (position: CGPoint, angle: CGFloat)
                if let parentID = ref.parent, let parent = boneWorlds[parentID] {
                    world = Self.childWorld(
                        localX: bone.x, localY: bone.y,
                        parentPosition: parent.position, parentAngle: parent.angle,
                        ownAngle: bone.angle
                    )
                } else {
                    world = (CGPoint(x: bone.x, y: bone.y), bone.angle)
                }
                boneWorlds[ref.id] = world
            }

            let placements: [SpritePlacement] = mainline.objects.compactMap { ref in
                guard let object = timelines[ref.timeline]?[ref.key],
                      let def = folders[object.folder]?[object.file] else { return nil }
                let pivotX = object.pivotX.isFinite ? object.pivotX : def.pivotX
                let pivotY = object.pivotY.isFinite ? object.pivotY : def.pivotY
                let world: (position: CGPoint, angle: CGFloat)
                if let parentID = ref.parent, let parent = boneWorlds[parentID] {
                    world = Self.childWorld(
                        localX: object.x, localY: object.y,
                        parentPosition: parent.position, parentAngle: parent.angle,
                        ownAngle: object.angle
                    )
                } else {
                    world = (CGPoint(x: object.x, y: object.y), object.angle)
                }
                return SpritePlacement(
                    file: def,
                    x: world.position.x,
                    y: world.position.y,
                    angle: world.angle,
                    pivotX: pivotX,
                    pivotY: pivotY,
                    zIndex: ref.zIndex,
                    alpha: object.alpha
                )
            }
            if !placements.isEmpty { frames.append(placements) }
        }
        if !frames.isEmpty {
            animations[name] = SpriteAnimation(name: name, frames: frames)
        }
        animationName = nil
        mainlineFrames = []
        boneTimelines = [:]
        timelines = [:]
    }

    /// Applies a parent's world transform to a child's local offset and
    /// relative angle. Spriter stores counter-clockwise degrees in y-up space.
    private static func childWorld(
        localX: CGFloat,
        localY: CGFloat,
        parentPosition: CGPoint,
        parentAngle: CGFloat,
        ownAngle: CGFloat
    ) -> (position: CGPoint, angle: CGFloat) {
        let rad = parentAngle * .pi / 180
        let cosA = cos(rad)
        let sinA = sin(rad)
        let x = parentPosition.x + localX * cosA - localY * sinA
        let y = parentPosition.y + localX * sinA + localY * cosA
        return (CGPoint(x: x, y: y), parentAngle + ownAngle)
    }
}

// MARK: - Loadout

/// What the hero holds and wears over the race art, by catalog id. Resolved against the bundled
/// modular gear manifest; ids the manifest doesn't know fall back to the legacy generic anchor.
nonisolated struct SpriteLoadout: Equatable, Sendable {
    var weaponID: String? = nil
    var shieldID: String? = nil
    var headID: String? = nil
    var titanWeapon: Bool = false
    var gearMaterials: CharacterMaterialSet? = nil

    static let none = SpriteLoadout()
}

/// A rendered frame plus how far its canvas extends beyond the pack's base canvas (a Titan blade
/// enlarges it). The view keeps the character's size constant and lets the blade overflow.
final class SpriteFrame {
    let image: UIImage
    let layout: SpriteCanvasLayout
    init(image: UIImage, layout: SpriteCanvasLayout) {
        self.image = image
        self.layout = layout
    }
}

// MARK: - Renderer

@MainActor
final class SpriteRenderer {
    static let shared = SpriteRenderer()

    private struct ResolvedItem {
        let resource: String
        let placement: HeldGearPlacement
        let entry: HeldGearEntry?
        /// Image-pixel size used to build the local draw rect.
        let imageSize: CGSize
    }

    private struct ResolvedLoadout {
        var weapon: ResolvedItem?
        var shield: ResolvedItem?
        var head: ResolvedItem?
        /// Titan with nothing equipped: the pack's own weapon scaled about its grip.
        var bakedTitan: HeldGearPlacement?
        var gearMaterials: CharacterMaterialSet?

        var hidesBakedWeapon: Bool { weapon != nil || bakedTitan != nil }
        var key: String {
            let w = weapon.map { "\($0.resource)@\($0.placement.scale)" } ?? (bakedTitan.map { "baked@\($0.scale)" } ?? "-")
            let sh = shield.map { $0.resource } ?? "-"
            let hd = head.map { $0.resource } ?? "-"
            return "\(w)|\(sh)|\(hd)|\(MaterialPalette.fingerprint(gearMaterials))"
        }
    }

    private let catalog: ModularAssetCatalog
    private var documents: [String: SpriterDocument] = [:]
    private var partImages: [String: UIImage] = [:]
    private var tintedImages: [String: UIImage] = [:]
    private var recoloredImages: [String: UIImage] = [:]
    private var canvases: [String: (origin: CGPoint, size: CGSize)] = [:]
    private var modularPartCache: [String: [String: [PartManifest]]?] = [:]
    private let frameCache = NSCache<NSString, SpriteFrame>()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let recolorer = MaterialRecolorer()

    init(catalog: ModularAssetCatalog = .shared) {
        self.catalog = catalog
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.purgeCaches() }
        }
    }

    /// Drops every rebuildable image cache (memory warning). Documents stay: they are small and re-parsing is slow.
    func purgeCaches() {
        frameCache.removeAllObjects()
        partImages.removeAll()
        tintedImages.removeAll()
        recoloredImages.removeAll()
    }

    /// Normalizes an SCML file name ("Face 01.png") into its bundled base
    /// name ("valkyrie_v1_face_01").
    static func partBaseName(race: HeroRace, variant: Int, fileName: String) -> String {
        let stem = (fileName as NSString).deletingPathExtension
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
        return "\(race.artBase(variant: variant))_\(stem)"
    }

    // MARK: Documents & assets

    func document(race: HeroRace, variant: Int) -> SpriterDocument? {
        let key = race.artBase(variant: variant)
        if let cached = documents[key] { return cached }
        guard let doc = SpriterDocument.load(race: race, variant: variant) else { return nil }
        documents[key] = doc
        return doc
    }

    func frameCount(race: HeroRace, variant: Int, animation: String) -> Int {
        document(race: race, variant: variant)?.animations[animation]?.frameCount ?? 0
    }

    func canvasSize(race: HeroRace, variant: Int) -> CGSize? {
        document(race: race, variant: variant)?.canvasSize
    }

    /// The attack animation this variant actually ships ("Shooting" or "Slashing").
    func attackAnimation(race: HeroRace, variant: Int) -> String {
        let preferred = race.attackAnimationName(variant: variant)
        if frameCount(race: race, variant: variant, animation: preferred) > 0 { return preferred }
        return frameCount(race: race, variant: variant, animation: "Slashing") > 0 ? "Slashing" : preferred
    }

    private func image(base: String) -> UIImage? {
        if let cached = partImages[base] { return cached }
        guard let url = Bundle.main.url(forResource: base, withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        partImages[base] = image
        return image
    }

    // MARK: Recoloring (legacy whole-part tint, used until a layer ships masks)

    private func hueRotated(_ image: UIImage, shift: Double) -> UIImage {
        guard shift != 0, let source = image.ciImage ?? CIImage(image: image) else { return image }
        guard let filter = CIFilter(name: "CIHueAdjustment") else { return image }
        filter.setValue(source, forKey: kCIInputImageKey)
        filter.setValue(NSNumber(value: shift * Double.pi), forKey: kCIInputAngleKey)
        guard let output = filter.outputImage else { return image }
        let extent = output.extent.integral
        guard let cg = ciContext.createCGImage(output, from: extent) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }

    private func dyed(_ image: UIImage, dye: ArmorDye, strength: CGFloat = 0.45) -> UIImage {
        guard dye != .none else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: image.size, format: format).image { ctx in
            image.draw(at: .zero)
            let cg = ctx.cgContext
            cg.setBlendMode(.sourceAtop)
            cg.setFillColor(UIColor(dye.color).withAlphaComponent(strength).cgColor)
            cg.fill(CGRect(origin: .zero, size: image.size))
        }
    }

    private func isArmorPart(_ stem: String) -> Bool {
        switch stem {
        case "body", "left_arm", "right_arm", "left_hand", "right_hand", "left_leg", "right_leg":
            return true
        default:
            return false
        }
    }

    /// Applies the appearance's recolor choices to one part, cached.
    private func processedPart(race: HeroRace, variant: Int, fileDef: SpriteFileDef, appearance: HeroAppearance) -> UIImage? {
        let stem = (fileDef.name as NSString).deletingPathExtension
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
        let base = Self.partBaseName(race: race, variant: variant, fileName: fileDef.name)
        let tintKey = "\(base)|\(appearance.skinHueShift)|\(appearance.eyeHueShift)|\(appearance.hairHueShift)|\(appearance.armorDye.rawValue)"
        if let cached = tintedImages[tintKey] { return cached }
        guard var image = image(base: base) else { return nil }

        switch race.palette {
        case .flesh:
            if stem == "head" {
                image = hueRotated(image, shift: appearance.hairHueShift)
            } else if stem.hasPrefix("face") {
                image = hueRotated(image, shift: appearance.eyeHueShift)
                image = hueRotated(image, shift: appearance.skinHueShift)
            } else if isArmorPart(stem) {
                image = dyed(image, dye: appearance.armorDye)
            }
        case .bone, .stone:
            // Bone/stone creatures recolor as a whole via the skin slider.
            image = hueRotated(image, shift: appearance.skinHueShift)
            if isArmorPart(stem) {
                image = dyed(image, dye: appearance.armorDye)
            }
        }
        tintedImages[tintKey] = image
        return image
    }

    // MARK: Masked recolor (held gear and modular layers)

    /// Layer image recolored through its masks, or the plain image when nothing is coloured.
    private func maskedImage(resource: String, maskResources: [String: String], regionLuma: [String: Double], colors: CharacterMaterialSet?) -> UIImage? {
        guard let base = image(base: resource) else { return nil }
        guard let colors, !maskResources.isEmpty else { return base }
        let key = "\(resource)|\(MaterialPalette.fingerprint(colors))"
        if let cached = recoloredImages[key] { return cached }
        let regions: [MaterialRecolorer.Region] = maskResources.compactMap { name, maskName in
            guard let region = MaterialRegion(rawValue: name), let mask = image(base: maskName) else { return nil }
            return MaterialRecolorer.Region(region: region, mask: mask, referenceLuma: regionLuma[name])
        }
        let out = recolorer.recolor(base, regions: regions, colors: colors)
        recoloredImages[key] = out
        return out
    }

    // MARK: Geometry

    /// Draws `image` into `rect` (SCML units, y-down) relative to the placement's pivot, rotated with the part.
    private func drawRelative(_ image: UIImage, placement: SpritePlacement, rect: CGRect, extraRotation: CGFloat = 0, doc: SpriterDocument, in cg: CGContext) {
        let pivot = doc.screenPoint(placement.x, placement.y)
        cg.saveGState()
        cg.translateBy(x: pivot.x, y: pivot.y)
        cg.rotate(by: -(placement.angle + extraRotation) * .pi / 180)
        image.draw(in: rect)
        cg.restoreGState()
    }

    private func draw(_ image: UIImage, for placement: SpritePlacement, doc: SpriterDocument, in cg: CGContext) {
        let w = placement.file.width
        let h = placement.file.height
        drawRelative(image, placement: placement,
                     rect: CGRect(x: -placement.pivotX * w, y: -(1 - placement.pivotY) * h, width: w, height: h),
                     doc: doc, in: cg)
    }

    /// Anchor-relative rect of a held item: grip on the hold at the item's scale (see HeldGearFit).
    private func itemRect(_ item: ResolvedItem, anchor: SpritePlacement) -> CGRect {
        let pivotX = anchor.pivotX * anchor.file.width
        let pivotY = (1 - anchor.pivotY) * anchor.file.height
        let s = CGFloat(item.placement.scale)
        return CGRect(x: CGFloat(item.placement.offsetX) - s * pivotX,
                      y: CGFloat(item.placement.offsetY) - s * pivotY,
                      width: s * item.imageSize.width, height: s * item.imageSize.height)
    }

    /// Pivot-relative rect of a headpiece on a pack's head. `tight` limits it to the art's opaque bounds
    /// (used for canvas growth so transparent margins never enlarge the frame).
    private func headRect(_ item: ResolvedItem, head: SpritePlacement, fit: HeadFit, nominal: HeadpieceNominal, tight: Bool = false) -> CGRect {
        let k = CGFloat(fit.widthPx / nominal.width)
        let f = head.file.width / CGFloat(fit.headPngSize.first ?? Double(head.file.width))
        let left = (CGFloat(fit.cx) - k * CGFloat(nominal.anchorU)) * f - head.pivotX * head.file.width
        let top = (CGFloat(fit.baseY) - k * CGFloat(nominal.anchorV)) * f - (1 - head.pivotY) * head.file.height
        if tight, let box = item.entry?.contentBox, box.count == 4 {
            return CGRect(x: left + CGFloat(box[0]) * k * f, y: top + CGFloat(box[1]) * k * f,
                          width: CGFloat(box[2] - box[0] + 1) * k * f, height: CGFloat(box[3] - box[1] + 1) * k * f)
        }
        return CGRect(x: left, y: top, width: item.imageSize.width * k * f, height: item.imageSize.height * k * f)
    }

    /// The race's bare head (anatomy layer, or the original head when it is already skin/bone/stone), skin-tinted.
    private func bareHead(pack: String, appearance: HeroAppearance) -> UIImage? {
        guard let layer = catalog.parts(forPack: pack).first(where: { $0.part == "head" && $0.kind == "anatomy" }),
              let image = image(base: layer.resourceBaseName) else { return nil }
        return hueRotated(image, shift: appearance.skinHueShift)
    }

    /// World-space (y-up) bounds of a pivot-relative, y-down rect on a placement.
    private func worldBounds(of rect: CGRect, placement p: SpritePlacement, extraRotation: CGFloat = 0) -> CGRect {
        let r = (p.angle + extraRotation) * .pi / 180
        let c = cos(r), sn = sin(r)
        var minX = CGFloat.greatestFiniteMagnitude, maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        for (lx, ly) in [(rect.minX, rect.minY), (rect.maxX, rect.minY), (rect.maxX, rect.maxY), (rect.minX, rect.maxY)] {
            let upY = -ly
            let x = p.x + lx * c - upY * sn
            let y = p.y + lx * sn + upY * c
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func weaponAnchor(_ frame: [SpritePlacement]) -> SpritePlacement? {
        frame.first { $0.file.name.lowercased().hasPrefix("sword") || $0.file.name.lowercased().hasPrefix("bow") }
    }

    private func shieldAnchor(_ frame: [SpritePlacement]) -> SpritePlacement? {
        frame.first { $0.file.name.lowercased().hasPrefix("shield") }
            ?? frame.first { $0.file.name.lowercased().contains("left hand") }
    }

    /// The pack's base canvas united with every held item's rect across all frames (a swapped item is drawn at
    /// its anchor even when the baked one is hidden, and Titan doubles it), so nothing clips in any animation.
    private func canvas(doc: SpriterDocument, pack: String, resolved: ResolvedLoadout) -> (origin: CGPoint, size: CGSize) {
        guard resolved.weapon != nil || resolved.shield != nil || resolved.head != nil || resolved.bakedTitan != nil else {
            return (doc.origin, doc.canvasSize)
        }
        let key = "\(pack)|\(resolved.key)"
        if let cached = canvases[key] { return cached }
        let pad = SpriterDocument.canvasPadding
        var minX = doc.origin.x + pad, minY = doc.origin.y + pad
        var maxX = doc.origin.x + doc.canvasSize.width - pad, maxY = doc.origin.y + doc.canvasSize.height - pad
        func include(_ r: CGRect) {
            minX = min(minX, r.minX); minY = min(minY, r.minY); maxX = max(maxX, r.maxX); maxY = max(maxY, r.maxY)
        }
        let anchors = catalog.anchors(pack: pack)
        let nominal = catalog.gear?.headpieceNominal
        for animation in doc.animations.values {
            for frame in animation.frames {
                if let item = resolved.weapon ?? bakedItem(resolved, frame: frame), let a = weaponAnchor(frame) {
                    include(worldBounds(of: itemRect(item, anchor: a), placement: a, extraRotation: CGFloat(item.placement.rotationDegrees)))
                }
                if let item = resolved.shield, let a = shieldAnchor(frame) {
                    include(worldBounds(of: itemRect(item, anchor: a), placement: a, extraRotation: CGFloat(item.placement.rotationDegrees)))
                }
                if let item = resolved.head, let fit = anchors?.headFit, let nominal,
                   let head = frame.first(where: { $0.file.name.lowercased().hasPrefix("head") }) {
                    include(worldBounds(of: headRect(item, head: head, fit: fit, nominal: nominal, tight: true), placement: head))
                }
            }
        }
        let origin = CGPoint(x: minX - pad, y: minY - pad)
        let result = (origin: origin, size: CGSize(width: maxX + pad - origin.x, height: maxY + pad - origin.y))
        canvases[key] = result
        return result
    }

    /// The baked weapon as a held item (Titan with nothing equipped).
    private func bakedItem(_ resolved: ResolvedLoadout, frame: [SpritePlacement]) -> ResolvedItem? {
        guard let titan = resolved.bakedTitan, let a = weaponAnchor(frame) else { return nil }
        return ResolvedItem(resource: "", placement: titan, entry: nil, imageSize: CGSize(width: a.file.width, height: a.file.height))
    }

    // MARK: Loadout resolution

    private func resolve(_ loadout: SpriteLoadout, race: HeroRace, pack: String) -> ResolvedLoadout {
        var out = ResolvedLoadout(weapon: nil, shield: nil, head: nil, bakedTitan: nil, gearMaterials: loadout.gearMaterials)
        let anchors = catalog.anchors(pack: pack)

        func resolveItem(_ id: String?, wants: (HeldGearKind) -> Bool, titan: Bool) -> ResolvedItem? {
            guard let id else { return nil }
            if let entry = catalog.gearItem(id: id) {
                guard wants(entry.kind), let anchors,
                      let placement = HeldGearFit.placement(item: entry, anchors: anchors, pack: pack, titan: titan) else { return nil }
                return ResolvedItem(resource: entry.resourceName, placement: placement, entry: entry,
                                    imageSize: CGSize(width: entry.imageWidth, height: entry.imageHeight))
            }
            // Not in the manifest (older catalog entry): legacy generic anchor, no fit data.
            guard let legacy = GearCatalog.design(id: id)?.resourceName, let img = image(base: legacy) else { return nil }
            let scale = titan ? HeldGearFit.titanScale : 1
            return ResolvedItem(resource: legacy, placement: HeldGearPlacement(scale: scale, offsetX: 0, offsetY: 0, rotationDegrees: 0),
                                entry: nil, imageSize: img.size)
        }

        out.weapon = resolveItem(loadout.weaponID, wants: { $0 != .shield && $0 != .headpiece }, titan: loadout.titanWeapon)
        out.shield = resolveItem(loadout.shieldID, wants: { $0 == .shield }, titan: false)
        out.head = resolveItem(loadout.headID, wants: { $0 == .headpiece }, titan: false)
        if out.weapon == nil, loadout.titanWeapon, let anchors {
            out.bakedTitan = HeldGearFit.bakedWeaponPlacement(anchors: anchors, titan: true)
        }
        return out
    }

    // MARK: Modular path (verified recipes only)

    /// Layers per original part stem when this pack's full recipe is verified; nil keeps the legacy renderer.
    private func modularParts(race: HeroRace, variant: Int, pack: String, appearance: HeroAppearance) -> [String: [PartManifest]]? {
        let key = "\(pack)|\(appearance.materials.map { MaterialPalette.fingerprint($0) } ?? "-")"
        if let cached = modularPartCache[key] { return cached }
        var result: [String: [PartManifest]]? = nil
        let layers = catalog.parts(forPack: pack).filter { $0.kind != "face" }
        if !layers.isEmpty {
            let recipe = ModularCharacterRecipe(
                ancestry: race, bodyProfile: race.defaultBodyProfile,
                parts: layers.map { CharacterPartSelection(slot: $0.slot, partID: $0.id) },
                materials: appearance.materials ?? CharacterMaterialSet()
            )
            if CharacterRenderPlanner.plan(for: recipe, manifests: layers).path == .modular {
                let order = ["anatomy": 0, "armor": 1, "headgear": 1]
                result = Dictionary(grouping: layers, by: { $0.part ?? "" })
                    .mapValues { $0.sorted { (order[$0.kind ?? ""] ?? 1) < (order[$1.kind ?? ""] ?? 1) } }
            }
        }
        modularPartCache[key] = .some(result)
        return result
    }

    // MARK: Compositing

    /// Renders one composited frame. Cached aggressively — idle loops hit the cache after the first pass.
    func frame(
        race: HeroRace,
        variant: Int,
        animation: String,
        frameIndex: Int,
        appearance: HeroAppearance,
        loadout: SpriteLoadout = .none
    ) -> SpriteFrame? {
        guard let doc = document(race: race, variant: variant),
              let anim = doc.animations[animation], !anim.frames.isEmpty else { return nil }
        let clampedVariant = min(max(variant, 1), race.variantCount)
        let pack = race.artBase(variant: clampedVariant)
        let resolved = resolve(loadout, race: race, pack: pack)
        let modular = modularParts(race: race, variant: clampedVariant, pack: pack, appearance: appearance)
        let key = "\(pack)|\(animation)|\(frameIndex)|\(appearance.skinHueShift)|\(appearance.eyeHueShift)|\(appearance.hairHueShift)|\(appearance.armorDye.rawValue)|\(resolved.key)|\(modular == nil ? "legacy" : "modular")|\(MaterialPalette.fingerprint(appearance.materials))"
        if let cached = frameCache.object(forKey: key as NSString) { return cached }

        let index = ((frameIndex % anim.frames.count) + anim.frames.count) % anim.frames.count
        let placements = anim.frames[index]
        let extent = canvas(doc: doc, pack: pack, resolved: resolved)
        let layout = SpriteCanvasLayout.around(
            baseOrigin: (Double(doc.origin.x), Double(doc.origin.y)), baseSize: (Double(doc.canvasSize.width), Double(doc.canvasSize.height)),
            frameOrigin: (Double(extent.origin.x), Double(extent.origin.y)), frameSize: (Double(extent.size.width), Double(extent.size.height)))
        // Draw through a document whose origin/size match the (possibly enlarged) canvas.
        let drawDoc = (extent.origin == doc.origin && extent.size == doc.canvasSize)
            ? doc : SpriterDocument(animations: doc.animations, canvasSize: extent.size, origin: extent.origin)

        let headpiece: (bare: UIImage, image: UIImage, item: ResolvedItem, fit: HeadFit, nominal: HeadpieceNominal)? = {
            guard let item = resolved.head, let entry = item.entry, let nominal = catalog.gear?.headpieceNominal,
                  let fit = catalog.anchors(pack: pack)?.headFit, let bare = bareHead(pack: pack, appearance: appearance),
                  let art = maskedImage(resource: entry.resourceName, maskResources: entry.maskResources,
                                        regionLuma: entry.regionLuma, colors: resolved.gearMaterials) else { return nil }
            return (bare, art, item, fit, nominal)
        }()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 0.5
        format.opaque = false
        let rendered = UIGraphicsImageRenderer(size: extent.size, format: format).image { ctx in
            let cg = ctx.cgContext

            for placement in placements.sorted(by: { $0.zIndex < $1.zIndex }) {
                let fileName = placement.file.name.lowercased()
                if placement.alpha < 0.01 { continue }
                // The arrow stays: a swapped bow still fires.
                if resolved.hidesBakedWeapon && (fileName.hasPrefix("sword") || fileName.hasPrefix("bow")) { continue }
                if resolved.shield != nil && fileName.hasPrefix("shield") { continue }
                if fileName.hasPrefix("slashfx") { continue }
                let stem = (fileName as NSString).deletingPathExtension.replacingOccurrences(of: " ", with: "_")
                // A headpiece sits on the bare head, not on top of the baked helmet/hair, and under the face overlay.
                if stem == "head", let hat = headpiece {
                    draw(hat.bare, for: placement, doc: drawDoc, in: cg)
                    drawRelative(hat.image, placement: placement, rect: headRect(hat.item, head: placement, fit: hat.fit, nominal: hat.nominal),
                                 doc: drawDoc, in: cg)
                    continue
                }
                if let layers = modular?[stem] {
                    for layer in layers {
                        if let img = maskedImage(resource: layer.resourceBaseName, maskResources: layer.maskResources,
                                                 regionLuma: layer.regionLuma, colors: appearance.materials) {
                            draw(img, for: placement, doc: drawDoc, in: cg)
                        }
                    }
                    continue
                }
                guard let part = processedPart(race: race, variant: clampedVariant, fileDef: placement.file, appearance: appearance) else { continue }
                draw(part, for: placement, doc: drawDoc, in: cg)
            }

            if let weapon = resolved.weapon, let anchor = weaponAnchor(placements) {
                let img = maskedImage(resource: weapon.resource, maskResources: weapon.entry?.maskResources ?? [:],
                                      regionLuma: weapon.entry?.regionLuma ?? [:], colors: resolved.gearMaterials)
                if let img {
                    drawRelative(img, placement: anchor, rect: itemRect(weapon, anchor: anchor),
                                 extraRotation: CGFloat(weapon.placement.rotationDegrees), doc: drawDoc, in: cg)
                    drawBowString(weapon: weapon, anchor: anchor, placements: placements, pack: pack, doc: drawDoc, in: cg)
                }
            } else if let titan = resolved.bakedTitan, let anchor = weaponAnchor(placements),
                      let img = image(base: Self.partBaseName(race: race, variant: clampedVariant, fileName: anchor.file.name)) {
                let item = ResolvedItem(resource: "", placement: titan, entry: nil, imageSize: CGSize(width: anchor.file.width, height: anchor.file.height))
                drawRelative(img, placement: anchor, rect: itemRect(item, anchor: anchor), doc: drawDoc, in: cg)
            }

            if let shield = resolved.shield, let anchor = shieldAnchor(placements),
               let img = maskedImage(resource: shield.resource, maskResources: shield.entry?.maskResources ?? [:],
                                     regionLuma: shield.entry?.regionLuma ?? [:], colors: resolved.gearMaterials) {
                drawRelative(img, placement: anchor, rect: itemRect(shield, anchor: anchor),
                             extraRotation: CGFloat(shield.placement.rotationDegrees), doc: drawDoc, in: cg)
            }
        }
        let result = SpriteFrame(image: rendered, layout: layout)
        frameCache.setObject(result, forKey: key as NSString)
        return result
    }

    /// The Recurve's art has no string. Draw one from the bow tips, through the nock while the arrow is drawn.
    private func drawBowString(weapon: ResolvedItem, anchor: SpritePlacement, placements: [SpritePlacement], pack: String,
                               doc: SpriterDocument, in cg: CGContext) {
        guard let entry = weapon.entry, entry.kind == .bow, let strings = entry.stringAnchors,
              strings.top.count == 2, strings.bottom.count == 2 else { return }
        let pivotX = anchor.pivotX * anchor.file.width
        let pivotY = (1 - anchor.pivotY) * anchor.file.height
        let s = CGFloat(weapon.placement.scale)
        func point(_ u: Double, _ v: Double, on p: SpritePlacement, local: (CGFloat, CGFloat)) -> CGPoint {
            let pivot = doc.screenPoint(p.x, p.y)
            let r = p.angle * .pi / 180
            return CGPoint(x: pivot.x + local.0 * cos(r) + local.1 * sin(r), y: pivot.y - local.0 * sin(r) + local.1 * cos(r))
        }
        func bowPoint(_ uv: [Double]) -> CGPoint {
            point(uv[0], uv[1], on: anchor, local: (s * (CGFloat(uv[0]) - pivotX) + CGFloat(weapon.placement.offsetX),
                                                    s * (CGFloat(uv[1]) - pivotY) + CGFloat(weapon.placement.offsetY)))
        }
        var path = [bowPoint(strings.top)]
        if let nock = catalog.anchors(pack: pack)?.arrowNock, nock.count == 2,
           let arrow = placements.first(where: { $0.file.name.lowercased().hasPrefix("arrow") && $0.alpha > 0.01 }) {
            let local = (CGFloat(nock[0]) - arrow.pivotX * arrow.file.width, CGFloat(nock[1]) - (1 - arrow.pivotY) * arrow.file.height)
            path.append(point(nock[0], nock[1], on: arrow, local: local))
        }
        path.append(bowPoint(strings.bottom))
        cg.saveGState()
        cg.setStrokeColor(UIColor(red: 0.93, green: 0.90, blue: 0.78, alpha: 1).cgColor)
        cg.setLineWidth(3)
        cg.setLineCap(.round)
        cg.setLineJoin(.round)
        cg.addLines(between: path)
        cg.strokePath()
        cg.restoreGState()
    }
}

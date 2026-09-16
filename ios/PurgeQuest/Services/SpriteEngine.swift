//
//  SpriteEngine.swift
//  PurgeQuest
//
//  Renders the illustrated race sprites. Each race pack ships a Spriter
//  (SCML) project describing how layered part PNGs (body, head, faces, arms,
//  hands, legs, weapon, shield, FX) are placed per animation frame. The
//  engine parses that project, composites parts into frames, applies the
//  hero's recolor choices (hue shifts + armor dye), and swaps the baked
//  weapon/shield for whatever the player has equipped.
//

import UIKit
import CoreImage
import SwiftUI

// MARK: - Document model

nonisolated struct SpriteFileDef {
    let name: String
    let width: CGFloat
    let height: CGFloat
}

nonisolated struct SpritePlacement {
    let file: SpriteFileDef
    let x: CGFloat
    let y: CGFloat
    let angle: CGFloat
    let pivotX: CGFloat
    let pivotY: CGFloat
    let zIndex: Int
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

    init(animations: [String: SpriteAnimation], canvasSize: CGSize, origin: CGPoint) {
        self.animations = animations
        self.canvasSize = canvasSize
        self.origin = origin
    }

    /// Loads and parses `<race>_v<variant>.scml` from the app bundle.
    static func load(race: HeroRace, variant: Int) -> SpriterDocument? {
        let base = "\(race.rawValue)_v\(variant)"
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

private struct ScmlObject {
    let folder: Int
    let file: Int
    let x: CGFloat
    let y: CGFloat
    let angle: CGFloat
    let pivotX: CGFloat
    let pivotY: CGFloat
}

private struct MainlineRef {
    let timeline: Int
    let key: Int
    let zIndex: Int
}

nonisolated private struct SCMLParser: @unchecked Sendable {
    private let data: Data

    init(data: Data) { self.data = data }

    func parse() -> SpriterDocument? {
        let delegate = ParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse(), !delegate.animations.isEmpty else { return nil }

        // Union bounds across every placement, in Spriter's y-up world space.
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for animation in delegate.animations.values {
            for frame in animation.frames {
                for p in frame {
                    let left = p.x - p.pivotX * p.file.width
                    let bottom = p.y - p.pivotY * p.file.height
                    let top = p.y + (1 - p.pivotY) * p.file.height
                    minX = min(minX, left)
                    maxX = max(maxX, left + p.file.width)
                    minY = min(minY, bottom)
                    maxY = max(maxY, top)
                }
            }
        }
        guard minX.isFinite, minY.isFinite else { return nil }
        let pad: CGFloat = 40
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
    private var mainlineFrames: [[MainlineRef]] = []
    private var timelines: [Int: [Int: ScmlObject]] = [:]
    private var currentTimelineID: Int?
    private var currentTimelineKey: Int?
    private var pendingObjectRefs: [MainlineRef] = []

    private func attr(_ attributes: [String: String], _ key: String) -> String? {
        attributes[key] ?? attributes[key.replacingOccurrences(of: "_", with: "-")]
    }

    private func num(_ attributes: [String: String], _ key: String, _ fallback: CGFloat) -> CGFloat {
        guard let raw = attr(attributes, key), let value = Double(raw), value.isFinite else { return fallback }
        return CGFloat(value)
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        stack.append(name)
        switch name {
        case "folder":
            folderID = Int(attr(attributes, "id") ?? "0") ?? 0
        case "file":
            let fileID = Int(attr(attributes, "id") ?? "0") ?? 0
            let def = SpriteFileDef(
                name: attr(attributes, "name") ?? "",
                width: num(attributes, "width", 1),
                height: num(attributes, "height", 1)
            )
            folders[folderID, default: [:]][fileID] = def
        case "animation":
            animationName = attr(attributes, "name")
            mainlineFrames = []
            timelines = [:]
        case "timeline":
            currentTimelineID = Int(attr(attributes, "id") ?? "-1")
        case "key":
            if stack.contains("mainline") {
                pendingObjectRefs = []
            } else {
                currentTimelineKey = Int(attr(attributes, "id") ?? "-1")
            }
        case "object_ref":
            let ref = MainlineRef(
                timeline: Int(attr(attributes, "timeline") ?? "-1") ?? -1,
                key: Int(attr(attributes, "key") ?? "-1") ?? -1,
                zIndex: Int(attr(attributes, "z_index") ?? "0") ?? 0
            )
            pendingObjectRefs.append(ref)
        case "object":
            guard let tl = currentTimelineID, let keyID = currentTimelineKey else { break }
            let obj = ScmlObject(
                folder: Int(attr(attributes, "folder") ?? "0") ?? 0,
                file: Int(attr(attributes, "file") ?? "0") ?? 0,
                x: num(attributes, "x", 0),
                y: num(attributes, "y", 0),
                angle: num(attributes, "angle", 0),
                pivotX: num(attributes, "pivot_x", CGFloat.nan),
                pivotY: num(attributes, "pivot_y", CGFloat.nan)
            )
            timelines[tl, default: [:]][keyID] = obj
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        switch name {
        case "key":
            if stack.contains("mainline") && pendingObjectRefs.isEmpty == false {
                mainlineFrames.append(pendingObjectRefs)
                pendingObjectRefs = []
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
        for refs in mainlineFrames {
            let placements: [SpritePlacement] = refs.compactMap { ref in
                guard let object = timelines[ref.timeline]?[ref.key],
                      let def = folders[object.folder]?[object.file] else { return nil }
                let pivotX = object.pivotX.isFinite ? object.pivotX : 0
                let pivotY = object.pivotY.isFinite ? object.pivotY : 1
                return SpritePlacement(
                    file: def,
                    x: object.x,
                    y: object.y,
                    angle: object.angle,
                    pivotX: pivotX,
                    pivotY: pivotY,
                    zIndex: ref.zIndex
                )
            }
            if !placements.isEmpty { frames.append(placements) }
        }
        if !frames.isEmpty {
            animations[name] = SpriteAnimation(name: name, frames: frames)
        }
        animationName = nil
        mainlineFrames = []
        timelines = [:]
    }
}

// MARK: - Renderer

@MainActor
final class SpriteRenderer {
    static let shared = SpriteRenderer()

    private var documents: [String: SpriterDocument] = [:]
    private var partImages: [String: UIImage] = [:]
    private var tintedImages: [String: UIImage] = [:]
    private let frameCache = NSCache<NSString, UIImage>()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    /// Normalizes an SCML file name ("Face 01.png") into its bundled base
    /// name ("valkyrie_v1_face_01").
    static func partBaseName(race: HeroRace, variant: Int, fileName: String) -> String {
        let stem = (fileName as NSString).deletingPathExtension
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
        return "\(race.rawValue)_v\(variant)_\(stem)"
    }

    // MARK: Documents & assets

    func document(race: HeroRace, variant: Int) -> SpriterDocument? {
        let key = "\(race.rawValue)_v\(variant)"
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

    private func image(base: String) -> UIImage? {
        if let cached = partImages[base] { return cached }
        guard let url = Bundle.main.url(forResource: base, withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        partImages[base] = image
        return image
    }

    // MARK: Recoloring

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

    // MARK: Compositing

    private func draw(_ image: UIImage, for placement: SpritePlacement, doc: SpriterDocument, in cg: CGContext, extraScale: CGFloat = 1) {
        let w = placement.file.width * extraScale
        let h = placement.file.height * extraScale
        let pivot = doc.screenPoint(placement.x, placement.y)
        let left = pivot.x - placement.pivotX * w
        let top = pivot.y - (1 - placement.pivotY) * h

        cg.saveGState()
        cg.translateBy(x: pivot.x, y: pivot.y)
        cg.rotate(by: -placement.angle * .pi / 180)
        cg.translateBy(x: -pivot.x, y: -pivot.y)
        image.draw(in: CGRect(x: left, y: top, width: w, height: h))
        cg.restoreGState()
    }

    private func isWeaponFile(_ name: String) -> Bool {
        name.hasPrefix("sword") || name.hasPrefix("bow") || name.hasPrefix("arrow")
    }

    /// Renders one composited frame. Cached aggressively — idle loops hit the
    /// cache after the first pass.
    func frame(
        race: HeroRace,
        variant: Int,
        animation: String,
        frameIndex: Int,
        appearance: HeroAppearance,
        weaponResource: String? = nil,
        shieldResource: String? = nil,
        titanWeapon: Bool = false
    ) -> UIImage? {
        guard let doc = document(race: race, variant: variant),
              let anim = doc.animations[animation], !anim.frames.isEmpty else { return nil }
        let clampedVariant = min(max(variant, 1), 3)
        let key = "\(race.rawValue)_v\(clampedVariant)|\(animation)|\(frameIndex)|\(appearance.skinHueShift)|\(appearance.eyeHueShift)|\(appearance.hairHueShift)|\(appearance.armorDye.rawValue)|\(weaponResource ?? "-")|\(shieldResource ?? "-")|\(titanWeapon)"
        if let cached = frameCache.object(forKey: key as NSString) { return cached }

        let index = ((frameIndex % anim.frames.count) + anim.frames.count) % anim.frames.count
        let placements = anim.frames[index]

        let format = UIGraphicsImageRendererFormat()
        format.scale = 0.5
        format.opaque = false
        let rendered = UIGraphicsImageRenderer(size: doc.canvasSize, format: format).image { ctx in
            let cg = ctx.cgContext

            for placement in placements.sorted(by: { $0.zIndex < $1.zIndex }) {
                let fileName = placement.file.name.lowercased()
                if weaponResource != nil && isWeaponFile(fileName) { continue }
                if shieldResource != nil && fileName.hasPrefix("shield") { continue }
                if fileName.hasPrefix("slashfx") { continue }
                guard let part = processedPart(race: race, variant: clampedVariant, fileDef: placement.file, appearance: appearance) else { continue }
                draw(part, for: placement, doc: doc, in: cg)
            }

            if let weaponResource {
                if let weaponImage = image(base: weaponResource),
                   let anchor = placements.first(where: { isWeaponFile($0.file.name.lowercased()) }) {
                    draw(weaponImage, for: anchor, doc: doc, in: cg, extraScale: titanWeapon ? 1.4 : 1)
                }
            }
            if let shieldResource {
                if let shieldImage = image(base: shieldResource) {
                    let anchor = placements.first(where: { $0.file.name.lowercased().hasPrefix("shield") })
                        ?? placements.first(where: { $0.file.name.lowercased().contains("left hand") })
                    if let anchor {
                        draw(shieldImage, for: anchor, doc: doc, in: cg)
                    }
                }
            }
        }
        frameCache.setObject(rendered, forKey: key as NSString)
        return rendered
    }
}

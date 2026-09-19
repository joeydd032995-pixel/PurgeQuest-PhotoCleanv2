#if DEBUG && canImport(UIKit)
import UIKit

/// Development-only renderer used to validate the modular migration against
/// the existing Spriter output. It never participates in production hero
/// rendering. Valkyrie v1 anatomy is resolved through `PartManifest`; face,
/// weapon, shield, and other non-anatomy layers remain legacy passthroughs so
/// artists can compare the migrated anatomy without losing visual context.
@MainActor
final class ModularCharacterPreviewRenderer {
    static let shared = ModularCharacterPreviewRenderer()

    private let imageCache = NSCache<NSString, UIImage>()
    private let frameCache = NSCache<NSString, UIImage>()

    private init() {}

    func availability(race: HeroRace, variant: Int) -> CharacterRenderPlan {
        ValkyrieV1ModularAssetSet.previewPlan(race: race, variant: variant)
    }

    func frameCount(animation: String) -> Int {
        SpriteRenderer.shared.document(race: .valkyrie, variant: 1)?
            .animations[animation]?.frameCount ?? 0
    }

    func frame(
        race: HeroRace,
        variant: Int,
        animation: String,
        frameIndex: Int
    ) -> UIImage? {
        let plan = availability(race: race, variant: variant)
        guard plan.path == .modular else { return nil }
        guard let document = SpriteRenderer.shared.document(race: .valkyrie, variant: 1),
              let clip = document.animations[animation],
              !clip.frames.isEmpty else { return nil }

        let index = ((frameIndex % clip.frames.count) + clip.frames.count) % clip.frames.count
        let cacheKey = "\(ValkyrieV1ModularAssetSet.recipe.renderFingerprint)|\(animation)|\(index)"
        if let cached = frameCache.object(forKey: cacheKey as NSString) {
            return cached
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 0.5
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: document.canvasSize, format: format).image { context in
            for placement in clip.frames[index].sorted(by: { $0.zIndex < $1.zIndex }) {
                guard placement.alpha > 0.01 else { continue }
                let stem = ValkyrieV1ModularAssetSet.normalizedStem(placement.file.name)
                if stem.hasPrefix("slashfx") { continue }

                let manifest = ValkyrieV1ModularAssetSet.manifest(forSCMLFileName: placement.file.name)
                let resource = manifest?.resourceBaseName
                    ?? SpriteRenderer.partBaseName(race: .valkyrie, variant: 1, fileName: placement.file.name)
                guard let part = sourceImage(base: resource) else { continue }

                let fit: PartFitTransform
                if let manifest,
                   let resolved = PartFitter.fit(manifest, to: ValkyrieV1ModularAssetSet.recipe.bodyProfile) {
                    fit = resolved
                } else {
                    fit = .init(scaleX: 1, scaleY: 1, offsetX: 0, offsetY: 0)
                }
                draw(part, placement: placement, fit: fit, document: document, in: context.cgContext)
            }
        }

        frameCache.setObject(image, forKey: cacheKey as NSString, cost: image.pixelCost)
        return image
    }

    private func sourceImage(base: String) -> UIImage? {
        if let cached = imageCache.object(forKey: base as NSString) { return cached }
        guard let url = Bundle.main.url(forResource: base, withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        imageCache.setObject(image, forKey: base as NSString, cost: image.pixelCost)
        return image
    }

    private func draw(
        _ image: UIImage,
        placement: SpritePlacement,
        fit: PartFitTransform,
        document: SpriterDocument,
        in context: CGContext
    ) {
        let width = placement.file.width * CGFloat(fit.scaleX)
        let height = placement.file.height * CGFloat(fit.scaleY)
        let pivot = document.screenPoint(
            placement.x + CGFloat(fit.offsetX),
            placement.y + CGFloat(fit.offsetY)
        )
        let left = pivot.x - placement.pivotX * width
        let top = pivot.y - (1 - placement.pivotY) * height

        context.saveGState()
        context.translateBy(x: pivot.x, y: pivot.y)
        context.rotate(by: -placement.angle * .pi / 180)
        context.translateBy(x: -pivot.x, y: -pivot.y)
        image.draw(in: CGRect(x: left, y: top, width: width, height: height))
        context.restoreGState()
    }
}

private extension UIImage {
    var pixelCost: Int {
        let pixels = max(1, Int(size.width * scale)) * max(1, Int(size.height * scale))
        return pixels * 4
    }
}
#endif

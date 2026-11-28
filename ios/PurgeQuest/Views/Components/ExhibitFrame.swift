//
//  ExhibitFrame.swift
//  PurgeQuest
//
//  The frame a photo hangs in on the combat card (sub-plan 1.2, task 4): a bronze rim, a thin inner mat and
//  the photo, with a glass chip for its size and age in the corner. It replaces the dark text strip that
//  used to cover the lower part of the photo, so the photo is seen whole.
//

import SwiftUI

struct ExhibitFrame<Photo: View>: View {
    /// "12.4 MB · 2 yr ago", shown in a glass chip over the photo's lower corner; nil for none.
    let chip: String?
    let accent: Color
    /// 0...1: how far the photo has lifted off the frame, from the drag. 0 at rest.
    var lift: Double = 0
    /// Degrees the frame's lit edge swings with the card's tilt. 0 at rest.
    var highlightShift: Double = 0
    /// The family skin drawn on the rim, or nil for the plain frame (also the kill switch's fallback).
    var skin: FamilySkinKind? = nil
    /// Seeds the skin's cracks, chips and notches; the card's id.
    var skinSeed: String = ""
    /// 0...1: the Storage Behemoths' pressure cracks, from the drag. 0 at rest.
    var crack: Double = 0
    /// The combo on the front card's rim, or nil for none (the card behind, the duplicate card).
    var combo: ComboRimState? = nil
    /// 0...1: a brass glow around the frame while a Live Photo plays.
    var liveGlow: Double = 0
    @ViewBuilder let photo: () -> Photo

    private let outer: CGFloat = 12
    /// The plain rim is 4 pt; a family skin widens it (see `FamilySkinKind.extraRim`) so its treatment can be seen.
    private var rim: CGFloat { 4 + CGFloat(skin?.extraRim ?? 0) }

    var body: some View {
        // Every value is typed on its own line: one expression mixing Double, CGFloat and literals is more than the
        // compiler will type-check in reasonable time.
        let l = CGFloat(lift)
        let offset = LightSource.shadowOffset(depth: 3 + 7 * lift)
        let shadowX = CGFloat(offset.x)
        let shadowY = CGFloat(offset.y)
        let shadowRadius: CGFloat = 3 + 9 * l
        let shadowOpacity: Double = 0.30 * lift
        let scale: CGFloat = 1 + 0.03 * l
        photo()
            .clipShape(RoundedRectangle(cornerRadius: outer - rim))
            .overlay(RoundedRectangle(cornerRadius: outer - rim).stroke(Color.black.opacity(0.55), lineWidth: 1))
            .overlay(alignment: .bottomLeading) { chipView }
            .scaleEffect(scale)
            .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, x: shadowX, y: shadowY)
            .padding(rim)
            .background(frameBackground)
    }

    /// The bronze rim: the plate gradient, the accent and dark keylines, a faint lit edge that moves with the tilt,
    /// and a shadow that deepens as the photo lifts. Light and shadow both come from `LightSource`.
    private var frameBackground: some View {
        let l = CGFloat(lift)
        let offset = LightSource.shadowOffset(depth: 2 + 4 * lift)
        let shadowX = CGFloat(offset.x)
        let shadowY = CGFloat(offset.y)
        let shadowRadius: CGFloat = 5 + 8 * l
        let shadowOpacity: Double = 0.25 + 0.15 * lift
        let points = LightSource.highlightPoints(shiftDegrees: highlightShift)
        let litStart = UnitPoint(x: CGFloat(points.start.x), y: CGFloat(points.start.y))
        let litEnd = UnitPoint(x: CGFloat(points.end.x), y: CGFloat(points.end.y))
        let bevelColors: [Color] = [Color.white.opacity(0.45), Color.white.opacity(0), Color.black.opacity(0.25)]
        let bevel = LinearGradient(colors: bevelColors, startPoint: litStart, endPoint: litEnd)
        let litEdge = RoundedRectangle(cornerRadius: outer - 1).stroke(bevel, lineWidth: 1).padding(1)
        // The Video Phantoms' cool glow sits outside the frame; the frame is opaque, so it never reaches the photo.
        let glowColor: Color = skin == .phantoms ? accent.opacity(0.7) : Color.clear
        let glowRadius: CGFloat = skin == .phantoms ? 14 : 0
        // The combo's glow also reaches a little outside the frame, never inside it.
        let comboGlowAlpha: Double = (combo?.tier.glowAlpha ?? 0) * (combo?.shown ?? 0) * 0.8
        let liveGlowAlpha: Double = liveGlow * 0.8
        let comboGlow: Color = Color.questAmber.opacity(min(1, comboGlowAlpha + liveGlowAlpha))
        return RoundedRectangle(cornerRadius: outer)
            .fill(LinearGradient.goldPlate)
            .overlay(RoundedRectangle(cornerRadius: outer).stroke(accent.opacity(0.5), lineWidth: 1))
            .overlay(RoundedRectangle(cornerRadius: outer).stroke(Color.black.opacity(0.6), lineWidth: 0.5).padding(0.5))
            .overlay { skinLayer }
            .overlay { comboLayer }
            .overlay(litEdge)
            .shadow(color: comboGlow, radius: 7)
            .shadow(color: glowColor, radius: glowRadius)
            .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, x: shadowX, y: shadowY)
    }

    /// The combo's rim glow, line, pulse, sheen and cooling, drawn on the rim only.
    @ViewBuilder
    private var comboLayer: some View {
        if let combo {
            ComboRim(state: combo, outerRadius: outer, rim: rim)
        }
    }

    /// The family skin's rim treatment, clipped to the rim ring by the skin itself.
    @ViewBuilder
    private var skinLayer: some View {
        if let skin {
            SkinRim(kind: skin, seedKey: skinSeed, accent: accent, highlightShift: highlightShift, crack: crack,
                    outerRadius: outer, rim: rim)
        }
    }

    /// A blur of the photo under a dark tint, in the fixed on-glass colors, so it reads over any photo.
    @ViewBuilder
    private var chipView: some View {
        if let chip {
            chipText(chip)
        }
    }

    private func chipText(_ chip: String) -> some View {
        Text(chip)
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(Color.onGlass)
            .lineLimit(1)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background {
                ZStack {
                    BlurEffectView(style: .systemUltraThinMaterialDark)
                    Color.glassFill
                }
                .clipShape(Capsule())
            }
            .padding(8)
            .accessibilityHidden(true)
    }
}

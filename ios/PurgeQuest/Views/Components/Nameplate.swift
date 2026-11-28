//
//  Nameplate.swift
//  PurgeQuest
//
//  The plate under the photo on the combat card (sub-plan 1.2, task 4): the monster's name in the engraved
//  face, how rare it is and which family it belongs to, and one plain line saying why it was picked. It sits
//  on the card's own surface, not over the photo, so its colors are the theme's text colors and are checked
//  in Light and Dark. The name wraps to two lines and scales a little rather than being cut off.
//
//  A family skin gives it a tone (design section 5): letter spacing, the weight and small capitals of the family
//  line, a glow for the Video Phantoms, and a one-glyph jitter for Glitchborn. The tone never touches the text's
//  colors, so contrast stays what it is today.
//

import SwiftUI

struct Nameplate: View {
    let monster: MonsterType
    /// One plain sentence from the classification ("Why did this appear?"), or nil.
    let why: String?
    var needsCarefulReview: Bool = false
    /// The single card's own label already reads the monster out, so the plate is hidden from VoiceOver there.
    /// The duplicate card has no such label for the reason line, so it asks to be read.
    var readAloud: Bool = false
    /// The family skin's tone, or nil for the plain plate.
    var skin: FamilySkinKind? = nil
    /// Glitchborn only: one glyph of the name jitters during a flick. Set on the live front card, never under the gate.
    var jitters: Bool = false
    /// Seeds which glyph jitters; the card's id.
    var seedKey: String = ""
    /// The colour of the Phantoms' glow behind the name.
    var glowColor: Color = .clear

    var body: some View {
        let tone: NameplateTone? = skin?.nameplateTone
        VStack(alignment: .leading, spacing: 4) {
            nameView(tone: tone)
            Text(Wording.nameplateLine(rarity: monster.rarity.displayName, family: monster.family.displayName))
                .font(familyLineFont(tone: tone))
                .foregroundStyle(Color.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let why {
                Text(why)
                    .font(.footnote)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            if needsCarefulReview {
                Label("Review carefully", systemImage: "eye.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.textPrimary)
                    .accessibilityHint("This monster deserves a close look before deciding")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .accessibilityHidden(!readAloud)
    }

    // MARK: The name

    @ViewBuilder
    private func nameView(tone: NameplateTone?) -> some View {
        if jitters, skin == .glitch {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                styledName(tone: tone, at: timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            styledName(tone: tone, at: nil)
        }
    }

    private func styledName(tone: NameplateTone?, at time: Double?) -> some View {
        let tracking: CGFloat = CGFloat(tone?.tracking ?? 0)
        let glow: CGFloat = CGFloat(tone?.glow ?? 0)
        let glowOpacity: Double = glow > 0 ? 0.7 : 0
        return baseName(at: time)
            .font(.dungeonHeader)
            .tracking(tracking)
            .foregroundStyle(Color.textPrimary)
            .shadow(color: glowColor.opacity(glowOpacity), radius: glow)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The monster's name. During a Glitchborn flick one glyph sits a point and a half off the baseline; VoiceOver
    /// still reads the plain name, and nothing here is drawn when the gate is still.
    private func baseName(at time: Double?) -> Text {
        let name: String = monster.displayName
        guard let time,
              let glyph = GlitchTiming.jitterGlyph(time: time, nameLength: name.count, seed: SeededGeometry(key: seedKey)) else {
            return Text(verbatim: name)
        }
        let characters: [Character] = Array(name)
        let before = Text(verbatim: String(characters[..<glyph]))
        let moved = Text(verbatim: String(characters[glyph])).baselineOffset(1.5)
        let after = Text(verbatim: String(characters[(glyph + 1)...]))
        return Text("\(before)\(moved)\(after)")
    }

    // MARK: The family line

    private func familyLineFont(tone: NameplateTone?) -> Font {
        guard let tone else { return Font.caption.weight(.semibold) }
        let base: Font = Font.caption.weight(fontWeight(tone.weight))
        return tone.smallCapsEyebrow ? base.smallCaps() : base
    }

    /// Never thinner than regular at caption size: a family can sound drier without becoming hard to read.
    private func fontWeight(_ weight: NameplateTone.Weight) -> Font.Weight {
        switch weight {
        case .light, .regular: return .regular
        case .semibold:        return .semibold
        case .bold:            return .bold
        case .heavy:           return .heavy
        }
    }
}

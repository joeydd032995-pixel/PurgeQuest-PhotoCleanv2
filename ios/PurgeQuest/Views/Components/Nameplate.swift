//
//  Nameplate.swift
//  PurgeQuest
//
//  The plate under the photo on the combat card (sub-plan 1.2, task 4): the monster's name in the engraved
//  face, how rare it is and which family it belongs to, and one plain line saying why it was picked. It sits
//  on the card's own surface, not over the photo, so its colors are the theme's text colors and are checked
//  in Light and Dark. The name wraps to two lines and scales a little rather than being cut off.
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(monster.displayName)
                .font(.dungeonHeader)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
            Text(Wording.nameplateLine(rarity: monster.rarity.displayName, family: monster.family.displayName))
                .font(.caption.weight(.semibold))
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
}

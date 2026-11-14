//
//  GlossaryTip.swift
//  PurgeQuest
//
//  A one-line note that explains a game word the first time it is on screen: "Elite: a boss-tier monster
//  that pays more." It sits in the flow of the screen (never over the photo or the buttons), has one
//  44 pt control to dismiss it, and the screens that show it remember that the word was explained
//  (Glossary.swift), so it is never repeated.
//

import SwiftUI

struct GlossaryTip: View {
    let term: Glossary.Term
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.textSecondary)
                .accessibilityHidden(true)
            Text(Glossary.sentence(term))
                .font(.caption)
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismiss) {
                Text("Got it")
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.textSecondary)
            .accessibilityLabel("Got it, hide this note about \(Glossary.name(term))")
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.dungeonStone)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.dungeonAsh, lineWidth: 1))
        )
    }
}

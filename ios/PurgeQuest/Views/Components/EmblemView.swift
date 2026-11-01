//
//  EmblemView.swift
//  PurgeQuest
//
//  The PurgeQuest emblem: a winged gold shield, cut out with transparency so it
//  sits on the cream (Light) and green-black (Dark) canvases alike. In Dark it
//  gets a faint warm halo so the gold reads against the deep background.
//

import SwiftUI

struct EmblemView: View {
    /// Name of the image set in the asset catalog.
    static let assetName = "PurgeQuestEmblem"

    @Environment(\.colorScheme) private var colorScheme

    private var haloOpacity: Double { colorScheme == .dark ? 0.28 : 0 }

    var body: some View {
        Image(Self.assetName)
            .resizable()
            .scaledToFit()
            .shadow(color: Color.questAmber.opacity(haloOpacity), radius: 22)
            .accessibilityLabel("PurgeQuest emblem")
    }
}

/// "PurgeQuest" set in engraved Cinzel (lowercase renders as small capitals).
struct WordmarkView: View {
    var body: some View {
        Text("PurgeQuest")
            .font(.dungeonDisplay)
            .tracking(1)
            .foregroundStyle(Color.goldTitle)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityAddTraits(.isHeader)
    }
}

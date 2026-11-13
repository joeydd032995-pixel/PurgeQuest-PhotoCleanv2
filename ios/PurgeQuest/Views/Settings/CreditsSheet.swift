//
//  CreditsSheet.swift
//  PurgeQuest
//
//  The Credits screen (Settings > About): the art and the typeface that other people made for the app,
//  from `ThirdPartyCredits`. Cinzel's license, the SIL Open Font License, asks that its notice and its
//  text travel with the font, so the full text is here too, read from the `Cinzel-OFL` data asset.
//

import SwiftUI
import UIKit

struct CreditsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Credits")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("PurgeQuest uses art and a typeface that other people made. Thank you to them.")
                    .font(.callout)
                    .foregroundStyle(.textSecondary)

                card(title: "Art") {
                    ForEach(ThirdPartyCredits.art) { credit in
                        creditRow(credit)
                    }
                }

                card(title: "Typeface") {
                    creditRow(ThirdPartyCredits.font)
                    fontLicense
                }

                Button("Close") { dismiss() }
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .background(DungeonBackgroundView())
    }

    /// Cinzel's license, collapsed until the player opens it. The text is the official OFL.txt; if the asset
    /// were ever missing, the license's name still shows.
    private var fontLicense: some View {
        DisclosureGroup {
            Text(verbatim: cinzelLicenseText)
                .font(.caption2)
                .foregroundStyle(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
        } label: {
            Text(ThirdPartyCredits.fontLicenseName)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.questAmber)
        }
        .tint(.questAmber)
        .accessibilityIdentifier("credits.cinzel.license")
    }

    private var cinzelLicenseText: String {
        guard let asset = NSDataAsset(name: ThirdPartyCredits.fontLicenseAssetName) else {
            return ThirdPartyCredits.fontLicenseName
        }
        return String(decoding: asset.data, as: UTF8.self)
    }

    private func creditRow(_ credit: ThirdPartyCredit) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(credit.usedFor)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.textPrimary)
            Text(credit.name)
                .font(.callout)
                .foregroundStyle(.textSecondary)
            Text(credit.author)
                .font(.caption)
                .foregroundStyle(.questAmber)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.heavy))
                .tracking(0.6)
                .foregroundStyle(.textSecondary)
                .padding(.leading, 6)
            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.dungeonStone)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.dungeonAsh, lineWidth: 1))
            )
        }
    }
}

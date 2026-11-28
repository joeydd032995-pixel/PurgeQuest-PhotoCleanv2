//
//  DuplicateGroupCard.swift
//  PurgeQuest
//
//  One duplicate encounter: a carousel of the copies with the recommended
//  survivor starred, and an explicit Keep/Slay decision per copy. Nothing is
//  pre-decided — confirming requires the player's explicit choices.
//

import SwiftUI

struct DuplicateGroupCard: View {
    let group: DuplicateGroup
    let onConfirm: ([String: Bool]) -> Void

    /// Per-copy decision: false = keep, true = slay. Defaults to keep so a
    /// destructive action always requires an explicit tap.
    @State private var decisions: [String: Bool] = [:]
    @State private var selectedMemberID: String? = nil

    private var selectedMember: MediaItem? {
        if let id = selectedMemberID, let m = group.member(id: id) { return m }
        return group.representative
    }

    private var slayCount: Int {
        decisions.values.filter { $0 }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            carousel
            decisionControls
            confirmButton
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dungeonStone)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dungeonAsh, lineWidth: 1))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Duplicate group. \(group.members.count) copies of \(group.monsterType.displayName). Choose which copies to delete.")
    }

    // MARK: - Header

    /// The same nameplate as the single card, on the card's own surface. The reason line used to be near-white
    /// text on this surface, which measured 1.20:1 in Light; it now uses the theme's text color.
    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Nameplate(
                monster: group.monsterType,
                why: group.classification?.whyText,
                needsCarefulReview: group.classification?.requiresCarefulReview == true,
                readAloud: true
            )
            if let guidance = group.representative.flatMap({ $0.classification?.reviewNote }),
               group.classification?.requiresCarefulReview != true {
                Label(guidance, systemImage: "checkmark.circle.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, 6)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 14)
        .padding(.bottom, 6)
    }

    // MARK: - Carousel

    private var carousel: some View {
        VStack(spacing: 8) {
            // The duplicate card is always a Duplicate Dragons encounter: the still Dragons frame (it has no swipe).
            ExhibitFrame(
                chip: nil,
                accent: group.monsterType.accentColor,
                skin: FamilySkinKind.active(for: .duplicateDragons),
                skinSeed: group.representative?.id ?? "group"
            ) {
                TabView(selection: Binding(
                    get: { selectedMemberID ?? group.representative?.id },
                    set: { selectedMemberID = $0 }
                )) {
                    ForEach(group.members, id: \.id) { member in
                        memberView(member)
                            .tag(member.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
            // Up to 250 pt tall, shorter when the screen is crowded (a tip row above, a large text size) so the
            // card always fits and leaves the Undo pill its room.
            .frame(minHeight: 140, maxHeight: 250)

            Text("Copy \(indexOfSelected + 1) of \(group.members.count)")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(.textSecondary)
        }
        .padding(.horizontal, 12)
    }

    private var indexOfSelected: Int {
        guard let id = selectedMemberID ?? group.representative?.id,
              let idx = group.members.firstIndex(where: { $0.id == id }) else { return 0 }
        return idx
    }

    private func memberView(_ member: MediaItem) -> some View {
        let willDelete = decisions[member.id] ?? false
        let isSurvivor = member.id == group.survivorID
        return ZStack {
            Color.dungeonVoid
                .overlay {
                    if let thumb = member.thumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                    } else {
                        Image(systemName: member.monsterType.symbol)
                            .font(.system(size: 60, weight: .bold))
                            .foregroundStyle(member.monsterType.accentColor.opacity(0.4))
                    }
                }
                .overlay {
                    if member.kind == .video {
                        // Real video frame thumbnails stream from PHImageManager;
                        // the play cue marks it as motion, not a still.
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(.white.opacity(0.85))
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .overlay(
                    LinearGradient(colors: [.clear, .black.opacity(0.4)], startPoint: .center, endPoint: .bottom)
                        .allowsHitTesting(false)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))

            if isSurvivor {
                VStack {
                    HStack {
                        Spacer()
                        Label("Suggested keep", systemImage: "star.fill")
                            .font(.caption2.weight(.black))
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.goldFill))
                            .foregroundStyle(.goldInk)
                            .padding(8)
                    }
                    Spacer()
                }
            }

            VStack {
                Spacer()
                HStack {
                    if member.kind == .video, !member.formattedDuration.isEmpty {
                        Text(member.formattedDuration)
                            .font(.caption2.monospacedDigit().weight(.bold))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 5).fill(.black.opacity(0.6)))
                            .foregroundStyle(.white)
                    }
                    Label(member.formattedSize, systemImage: "internaldrive.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.patinaOnGlass)
                    Text("·").foregroundStyle(Color.onGlassMuted)
                    Text(member.ageDescription)
                        .font(.caption2)
                        .foregroundStyle(Color.onGlass)
                    Spacer()
                    decisionBadge(willDelete: willDelete)
                }
                .padding(10)
                .background {
                    BlurEffectView(style: .systemUltraThinMaterialDark)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func decisionBadge(willDelete: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: willDelete ? "xmark" : "shield.fill")
                .font(.caption2.weight(.black))
            Text(willDelete ? "DELETE" : "KEEP")
                .font(.caption2.weight(.black))
                .tracking(0.6)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(willDelete ? Color.combatCrimsonDeep : Color.gemEmeraldDeep))
        .foregroundStyle(.white)
    }

    // MARK: - Decision controls

    private var decisionControls: some View {
        VStack(spacing: 8) {
            if let survivor = group.recommendedSurvivor, selectedMember != nil {
                Text("Star marks the sharpest copy. The choice is always yours.")
                    .font(.caption2)
                    .foregroundStyle(.textSecondary)
            }
            HStack(spacing: 12) {
                copyButton("Delete this copy", symbol: "xmark", fill: .combatCrimsonDeep, edge: .combatCrimson,
                           ink: .white, chosen: decisionForSelected == true,
                           label: "Mark this copy for deletion") { setDecision(true) }
                copyButton("Keep this copy", symbol: "checkmark.shield.fill", fill: .gemEmeraldDeep, edge: .gemEmerald,
                           ink: .white, chosen: decisionForSelected == false,
                           label: "Keep this copy") { setDecision(false) }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// A per-copy button. Delete and Keep are the same size and both filled; the one chosen for this copy
    /// shows a ring and a tick, so neither looks like the default.
    private func copyButton(
        _ title: String, symbol: String, fill: Color, edge: Color, ink: Color, chosen: Bool,
        label: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: chosen ? "checkmark.circle.fill" : symbol)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(RoundedRectangle(cornerRadius: 12).fill(fill))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(chosen ? Color.textPrimary : edge, lineWidth: chosen ? 2.5 : 1))
                .foregroundStyle(ink)
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    private var decisionForSelected: Bool? {
        guard let member = selectedMember else { return nil }
        return decisions[member.id]
    }

    private func setDecision(_ willDelete: Bool) {
        guard let member = selectedMember else { return }
        decisions[member.id] = willDelete
        HapticsService.shared.light()
        // Advance to the next undecided copy so the player never loses place.
        if let idx = group.members.firstIndex(where: { $0.id == member.id }) {
            let next = (idx + 1) % group.members.count
            selectedMemberID = group.members[next].id
        }
    }

    // MARK: - Confirm

    private var confirmButton: some View {
        Button {
            HapticsService.shared.medium()
            onConfirm(decisions)
        } label: {
            Label(
                slayCount > 0 ? "Confirm — delete \(slayCount) cop\(slayCount == 1 ? "y" : "ies")" : "Confirm — keep all copies",
                systemImage: "checkmark.seal.fill"
            )
            .font(.headline.weight(.heavy))
            .frame(maxWidth: .infinity).padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 9).fill(slayCount > 0 ? Color.combatCrimsonDeep : Color.goldFill))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(slayCount > 0 ? Color.combatCrimson : Color.goldRim, lineWidth: 1))
            .foregroundStyle(slayCount > 0 ? .white : .goldInk)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .accessibilityHint("Applies your per-copy choices and moves to the next monster")
    }
}

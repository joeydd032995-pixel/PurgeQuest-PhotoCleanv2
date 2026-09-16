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
        .background(Color.dungeonStoneLight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(group.monsterType.accentColor.opacity(0.6), lineWidth: 1.5)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Duplicate group. \(group.members.count) copies of \(group.monsterType.displayName). Choose which copies to delete.")
    }

    // MARK: - Header

    private var headerBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: group.monsterType.symbol)
                        .font(.caption.weight(.bold))
                    Text(group.monsterType.displayName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(group.monsterType.accentColor.opacity(0.85)))
                .foregroundStyle(.dungeonVoid)

                rarityChip
                Spacer()
                if group.monsterType.rarity.hasCrownBadge {
                    Image(systemName: "crown.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.questAmber)
                }
            }
            if let why = group.classification?.whyText {
                Text(why)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)
            }
            if let guidance = group.representative.flatMap({ $0.classification?.reviewNote }) {
                Label(guidance, systemImage: group.classification?.requiresCarefulReview == true ? "eye.fill" : "checkmark.circle.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(group.classification?.requiresCarefulReview == true ? .questAmber : .gemEmerald)
            }
        }
        .padding(14)
    }

    private var rarityChip: some View {
        Text(group.monsterType.rarity.displayName)
            .font(.system(size: 10, weight: .black).monospaced())
            .tracking(0.6)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.dungeonVoid.opacity(0.7)))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(group.monsterType.rarity.frameColor.opacity(0.8), lineWidth: 1))
            .foregroundStyle(group.monsterType.rarity.frameColor)
    }

    // MARK: - Carousel

    private var carousel: some View {
        VStack(spacing: 8) {
            TabView(selection: Binding(
                get: { selectedMemberID ?? group.representative?.id },
                set: { selectedMemberID = $0 }
            )) {
                ForEach(group.members, id: \.id) { member in
                    memberView(member)
                        .tag(member.id)
                        .padding(.horizontal, 2)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 240)

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
                .overlay(
                    LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
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
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.questAmber))
                            .foregroundStyle(.dungeonVoid)
                            .padding(8)
                    }
                    Spacer()
                }
            }

            VStack {
                Spacer()
                HStack {
                    Label(member.formattedSize, systemImage: "internaldrive.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.gemEmerald)
                    Text("·").foregroundStyle(.white.opacity(0.5))
                    Text(member.ageDescription)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    decisionBadge(willDelete: willDelete)
                }
                .padding(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func decisionBadge(willDelete: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: willDelete ? "xmark" : "shield.fill")
                .font(.system(size: 9, weight: .black))
            Text(willDelete ? "SLAY" : "KEEP")
                .font(.system(size: 10, weight: .black))
                .tracking(0.6)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(willDelete ? Color.combatCrimson : Color.gemEmeraldDeep))
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
                Button {
                    setDecision(true)
                } label: {
                    Label("Slay this copy", systemImage: "xmark")
                        .font(.subheadline.weight(.heavy))
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 9).fill(decisionForSelected == true ? Color.combatCrimson : Color.dungeonStone))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.combatCrimsonDeep, lineWidth: decisionForSelected == true ? 1 : 0))
                        .foregroundStyle(decisionForSelected == true ? .white : .combatCrimson)
                }
                .accessibilityLabel("Mark this copy for deletion")

                Button {
                    setDecision(false)
                } label: {
                    Label("Keep this copy", systemImage: "shield.fill")
                        .font(.subheadline.weight(.heavy))
                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 9).fill(decisionForSelected == false ? Color.gemEmeraldDeep : Color.dungeonStone))
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(decisionForSelected == false ? Color.gemEmerald : Color.dungeonAsh, lineWidth: 1))
                        .foregroundStyle(decisionForSelected == false ? .white : .gemEmerald)
                }
                .accessibilityLabel("Keep this copy")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
                slayCount > 0 ? "Confirm — purge \(slayCount) cop\(slayCount == 1 ? "y" : "ies")" : "Confirm — keep all copies",
                systemImage: "checkmark.seal.fill"
            )
            .font(.headline.weight(.heavy))
            .frame(maxWidth: .infinity).padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 9).fill(slayCount > 0 ? Color.combatCrimson : Color.questAmber))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(slayCount > 0 ? Color.combatCrimsonDeep : Color.questAmberDeep, lineWidth: 1))
            .foregroundStyle(slayCount > 0 ? .white : .dungeonVoid)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .accessibilityHint("Applies your per-copy choices and moves to the next monster")
    }
}

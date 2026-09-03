//
//  SwipeMediaCard.swift
//  PurgeQuest
//

import SwiftUI
import AVKit
import Photos

struct SwipeMediaCard: View {
    let item: MediaItem
    let isFront: Bool
    let onDelete: () -> Void
    let onSpare: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var snapAway: CGSize? = nil
    @State private var dynamicFlavor: String? = nil
    @State private var showLivePreview: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private let commitThreshold: CGFloat = 110
    private var rotation: Angle {
        .degrees(Double(dragOffset.width / 18))
    }

    var body: some View {
        ZStack {
            cardBody
                .overlay(alignment: .topLeading) { deleteOverlay }
                .overlay(alignment: .topTrailing) { spareOverlay }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(item.monsterType.accentColor.opacity(0.5), lineWidth: 1.5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black.opacity(0.6), lineWidth: 1)
                )
        }
        .scaleEffect(isFront ? 1.0 : 0.94)
        .offset(x: snapAway?.width ?? dragOffset.width, y: snapAway?.height ?? dragOffset.height)
        .rotationEffect(snapAway == nil ? rotation : .degrees(Double((snapAway?.width ?? 0) / 14)))
        .gesture(isFront ? dragGesture : nil)
        .task(id: item.id) {
            guard isFront else { return }
            if let cached = FoundationFlavorService.shared.cached(for: item) {
                dynamicFlavor = cached
            } else {
                let result = await FoundationFlavorService.shared.flavor(for: item)
                dynamicFlavor = result
            }
            // Kick off looping video preview after a tiny delay so the
            // thumbnail reads first and the player has time to attach.
            if item.kind == .video {
                try? await Task.sleep(for: .milliseconds(220))
                guard !Task.isCancelled, isFront else { return }
                VideoPreviewService.shared.play(phAssetID: item.id)
                withAnimation(.easeInOut(duration: 0.35)) { showLivePreview = true }
            }
        }
        .onDisappear {
            if item.kind == .video {
                VideoPreviewService.shared.stop(forAssetID: item.id)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, item.kind == .video {
                VideoPreviewService.shared.stop(forAssetID: item.id)
                showLivePreview = false
            }
        }
        .accessibilityLabel(item.monsterType.isElite ? "Elite. \(item.voiceOverDescription)" : item.voiceOverDescription)
        .accessibilityAdjustableAction { dir in
            switch dir {
            case .increment: onSpare()
            case .decrement: onDelete()
            @unknown default: break
            }
        }
    }

    private var cardBody: some View {
        Color.dungeonStoneLight
            .overlay {
                if let thumb = item.thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                } else {
                    Image(systemName: item.monsterType.symbol)
                        .font(.system(size: 80, weight: .bold))
                        .foregroundStyle(item.monsterType.accentColor.opacity(0.5))
                }
            }
            .overlay {
                if item.kind == .video, isFront, showLivePreview {
                    VideoPreviewLayerView()
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .overlay(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.4), .black.opacity(0.85)],
                    startPoint: .top, endPoint: .bottom
                )
                .allowsHitTesting(false)
            )
            .overlay {
                if item.kind == .video, !(isFront && showLivePreview) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 70, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .top) { topMetaBar }
            .overlay(alignment: .bottomLeading) { bottomMetaBar }
    }

    private var topMetaBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: item.monsterType.symbol)
                    .font(.caption.weight(.bold))
                Text(item.monsterType.displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(item.monsterType.accentColor.opacity(0.85)))
            .foregroundStyle(.dungeonVoid)
            if item.monsterType.isElite {
                eliteBadge
            }
            Spacer()
            if item.kind == .video, !item.formattedDuration.isEmpty {
                Text(item.formattedDuration)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(.black.opacity(0.7)))
                    .foregroundStyle(.white)
            }
        }
        .padding(12)
    }

    /// Small gold tag marking high-HP "boss" monsters — the foes a Purge
    /// Knight earns bonus XP for slaying. Static; no pulse.
    private var eliteBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "crown.fill")
                .font(.system(size: 9, weight: .black))
            Text("ELITE")
                .font(.system(size: 10, weight: .black))
                .tracking(0.6)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .foregroundStyle(.dungeonVoid)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.questAmber))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.55), lineWidth: 0.6))
        .accessibilityHidden(true)
    }

    private var bottomMetaBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("“\(dynamicFlavor ?? item.monsterType.flavor)”")
                .font(.callout.italic())
                .foregroundStyle(.white.opacity(0.95))
                .lineLimit(3)
                .animation(.easeInOut(duration: 0.25), value: dynamicFlavor)
            HStack(spacing: 8) {
                Label(item.formattedSize, systemImage: "internaldrive.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.gemEmerald)
                Text("·").foregroundStyle(.white.opacity(0.5))
                Text(item.ageDescription)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(14)
    }

    private var deleteOverlay: some View {
        let strength = max(0, min(1, -dragOffset.width / commitThreshold))
        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.combatCrimson.opacity(0.45 * strength))
            Text("DELETE")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(.white)
                .padding(10).padding(.horizontal, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.combatCrimsonDeep))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.6), lineWidth: 1))
                .rotationEffect(.degrees(-12))
                .opacity(strength)
                .scaleEffect(0.6 + strength * 0.5)
                .position(x: 110, y: 80)
        }
        .allowsHitTesting(false)
    }

    private var spareOverlay: some View {
        let strength = max(0, min(1, dragOffset.width / commitThreshold))
        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gemEmerald.opacity(0.4 * strength))
            Text("SPARE")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(.dungeonVoid)
                .padding(10).padding(.horizontal, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.gemEmeraldDeep))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.6), lineWidth: 1))
                .rotationEffect(.degrees(12))
                .opacity(strength)
                .scaleEffect(0.6 + strength * 0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, 60)
        .padding(.trailing, 28)
        .allowsHitTesting(false)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation
            }
            .onEnded { value in
                isDragging = false
                if value.translation.width < -commitThreshold {
                    commit(left: true)
                } else if value.translation.width > commitThreshold {
                    commit(left: false)
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    private func commit(left: Bool) {
        let target = CGSize(width: left ? -700 : 700, height: dragOffset.height + 50)
        if reduceMotion {
            snapAway = target
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                snapAway = target
            }
        }
        // Fire callback after a short delay so the animation reads.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 80 : 220))
            if left { onDelete() } else { onSpare() }
        }
    }
}

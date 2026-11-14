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
    /// This asset was purged once before and recovered — deleting it again
    /// earns no XP, gems, or quest progress.
    var isShade: Bool = false
    /// Live reward preview: what deleting this card pays at the current combo.
    var rewardXP: Int = 0
    var rewardGems: Int = 0
    let onDelete: () -> Void
    let onSpare: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var snapAway: CGSize? = nil
    @State private var dynamicFlavor: String? = nil
    @State private var showLivePreview: Bool = false
    /// Live Photo playback raised by tapping the card.
    @State private var showLivePlayback: Bool = false
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
                .overlay {
                    if item.isLivePhoto, isFront, showLivePlayback {
                        LivePhotoPreviewView(phAssetID: item.id)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) { showLivePlayback = false }
                            }
                            .transition(.opacity)
                            .accessibilityLabel("Live Photo playing. Tap to stop.")
                    }
                }
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
        .onTapGesture {
            // Live Photos: tap the front card to play the paired motion.
            guard isFront, item.isLivePhoto else { return }
            HapticsService.shared.light()
            withAnimation(.easeInOut(duration: 0.2)) { showLivePlayback.toggle() }
        }
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
            showLivePlayback = false
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
                // Lighter scrim — the frost blur under the meta bar now does
                // the heavy lifting for readability.
                LinearGradient(
                    colors: [.clear, .black.opacity(0.25), .black.opacity(0.55)],
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
            .foregroundStyle(.onAccent)
            if item.monsterType.isElite {
                eliteBadge
            }
            if item.isLivePhoto {
                liveBadge
            }
            if isShade {
                shadeBadge
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
                .font(.caption2.weight(.black))
            Text("ELITE")
                .font(.caption2.weight(.black))
                .tracking(0.6)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .foregroundStyle(.goldInk)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.goldFill))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.55), lineWidth: 0.6))
        .accessibilityHidden(true)
    }

    /// Ashen tag marking a returned shade: this monster was slain once
    /// already, so a second kill pays nothing.
    private var shadeBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "moon.zzz.fill")
                .font(.caption2.weight(.black))
            Text("SHADE")
                .font(.caption2.weight(.black))
                .tracking(0.6)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .foregroundStyle(.textSecondary)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.dungeonAsh.opacity(0.9)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.25), lineWidth: 0.6))
        .accessibilityLabel("Shade. Already purged once — no rewards this time.")
    }

    /// Small gold tag marking a Live Photo — tap the card to play it.
    private var liveBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "livephoto")
                .font(.caption2.weight(.black))
            Text("LIVE")
                .font(.caption2.weight(.black))
                .tracking(0.6)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .foregroundStyle(.goldInk)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.goldFill))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.55), lineWidth: 0.6))
        .accessibilityHidden(true)
    }

    /// Dark-glass footer: a blur of the photo under an 82% tint, so the text on it keeps its contrast over
    /// any photo or video frame, white ones included. Its text colors are the fixed on-glass set
    /// (ThemePalette.Glass), measured at 4.5:1 or better over a white photo. The theme's own accents are
    /// not used here: the Light-mode ones are dark inks and measured 2.2:1 on this strip.
    private var bottomMetaBar: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("“\(dynamicFlavor ?? item.monsterType.flavor)”")
                .font(.callout.italic())
                .foregroundStyle(.onGlass)
                .lineLimit(3)
                .animation(.easeInOut(duration: 0.25), value: dynamicFlavor)
            // "Why did this appear?" — plain-language reason from the classifier.
            if let why = item.classification?.whyText {
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.onGlassMuted)
                    Text(why)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.onGlass)
                        .lineLimit(2)
                }
            }
            if item.classification?.requiresCarefulReview == true {
                Label("Review carefully", systemImage: "eye.fill")
                    .font(.caption2.weight(.black))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.goldFill.opacity(0.92)))
                    .foregroundStyle(.goldInk)
                    .accessibilityHint("This monster deserves a close look before deciding")
            }
            HStack(spacing: 8) {
                Label(item.formattedSize, systemImage: "internaldrive.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.patinaOnGlass)
                Text("·").foregroundStyle(.onGlassMuted)
                Text(item.ageDescription)
                    .font(.caption2)
                    .foregroundStyle(.onGlassMuted)
            }
            if rewardXP > 0 || rewardGems > 0 {
                HStack(spacing: 8) {
                    Label("+\(rewardXP) XP", systemImage: "bolt.fill")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.brassOnGlass)
                    Text("·").foregroundStyle(.onGlassMuted)
                    Label("+\(rewardGems)", systemImage: "diamond.fill")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(.patinaOnGlass)
                    Text("on confirm")
                        .font(.caption2)
                        .foregroundStyle(.onGlassMuted)
                }
            }
        }
        .padding(12)
        .background {
            ZStack {
                BlurEffectView(style: .systemUltraThinMaterialDark)
                Color.glassFill
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(10)
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
                .foregroundStyle(.onAccent)
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

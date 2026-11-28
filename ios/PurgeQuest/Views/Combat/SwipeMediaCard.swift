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
    /// What the combo multiplier means to the rim, and what the last decision did to it. The front card only; the
    /// card behind keeps the defaults (no glow, no cue).
    var comboTier = ComboTier(tenths: 10)
    var comboCue: ComboCue = .none
    /// Where the front card reports its drag, so the screen's edges can draw the tear and the barrier. nil for the
    /// card behind, which is never dragged.
    var dragModel: CardDragModel? = nil
    let onDelete: () -> Void
    let onSpare: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var snapAway: CGSize? = nil
    @State private var showLivePreview: Bool = false
    /// Live Photo playback raised by tapping the card.
    @State private var showLivePlayback: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    /// The side the card is armed for while it is dragged past the commit line (see `SwipeProgress`).
    @State private var armedSide: SwipeProgress.Side? = nil
    /// A 150 ms scale punch when the card arms.
    @State private var punch: CGFloat = 1
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    /// When this card was committed, for the Storage Behemoths' stone chips.
    @State private var burstStart: Date? = nil
    /// The combo on the rim: a pulse after a raise, the sheen at x2.0, the fade after a keep, and the fade-in.
    @State private var comboPulse: Double = 0
    @State private var comboSheen: CGFloat = -0.4
    @State private var comboCool: Double = 0
    @State private var comboShown: Double = 0
    /// A brass glow around the frame while a Live Photo plays.
    @State private var liveGlow: Double = 0

    private let commitThreshold: CGFloat = 110
    private var rotation: Angle {
        .degrees(Double(dragOffset.width / 18))
    }

    /// Reduce Motion or Low Power Mode: every decorative effect becomes a still.
    private var gate: FXGate { FXGate(reduceMotion: reduceMotion, lowPowerMode: lowPower) }

    /// The family skin on this card: forced in a tour launch, off in the comparison launches, nil when the family's
    /// kill switch is off. The card behind keeps its skin too, drawn still.
    private var skin: FamilySkinKind? {
        if UITestSupport.skinsDisabled { return nil }
        if isFront, let forced = UITestSupport.forcedSkin { return forced }
        return FamilySkinKind.active(for: item.monsterType.family)
    }

    /// The Live Photo reveal: a circle opening from the LIVE badge's corner, or the plain cross-fade under the gate.
    private var liveReveal: AnyTransition {
        gate.isStill ? AnyTransition.opacity : AnyTransition(IrisTransition(origin: CGPoint(x: 34, y: 34)))
    }

    private var liveAnimation: Animation {
        Animation.easeInOut(duration: gate.isStill ? 0.2 : 0.22)
    }

    /// The tier the rim shows: the combat screen's, or one a tour launch forces (`-UITestCombo 20`).
    private var shownTier: ComboTier {
        if isFront, let tenths = UITestSupport.forcedComboTenths { return ComboTier(tenths: tenths) }
        return comboTier
    }

    /// The combo on this card's rim, front card only. Nothing shows at x1.0 unless a keep just cooled it.
    private var comboState: ComboRimState? {
        guard isFront, shownTier.tenths > 10 || comboCue == .cooled else { return nil }
        var state = ComboRimState(tier: shownTier)
        state.pulse = comboPulse
        state.sheen = comboSheen
        state.cool = comboCool
        state.shown = comboShown
        return state
    }

    /// How far the Storage Behemoths' pressure cracks have grown, from the drag. It is part of the frame treatment,
    /// so it stays under the gate.
    private var crackAmount: Double {
        skin == .behemoths ? SkinDrag.pressureCracks(strength: progress.strength) : 0
    }

    private var progress: SwipeProgress {
        SwipeProgress(dx: Double(dragOffset.width), dy: Double(dragOffset.height), gate: gate, wasArmed: armedSide)
    }

    /// Where the card sits: flying away once committed, else under the finger plus the cosmetic pull toward the tear.
    private var cardOffset: CGSize {
        if let away = snapAway { return away }
        let pull = CGFloat(progress.pull)
        return CGSize(width: dragOffset.width + pull, height: dragOffset.height)
    }

    var body: some View {
        ZStack {
            cardBody
                .overlay(alignment: .topLeading) { deleteOverlay }
                .overlay(alignment: .topTrailing) { spareOverlay }
                .overlay { edgeLayer }
                .overlay {
                    if item.isLivePhoto, isFront, showLivePlayback {
                        LivePhotoPreviewView(phAssetID: item.id)
                            .onTapGesture {
                                withAnimation(liveAnimation) {
                                    showLivePlayback = false
                                    liveGlow = 0
                                }
                            }
                            .transition(liveReveal)
                            .accessibilityLabel("Live Photo playing. Tap to stop.")
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .rotation3DEffect(.degrees(progress.tiltY), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .rotation3DEffect(.degrees(progress.tiltX), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        .scaleEffect(isFront ? punch : 0.94)
        .offset(cardOffset)
        .rotationEffect(snapAway == nil ? rotation : .degrees(Double((snapAway?.width ?? 0) / 14)))
        .gesture(isFront ? dragGesture : nil)
        .onChange(of: dragOffset) { _, _ in
            updateArming()
            publishEdges()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .task(id: item.id) { await playComboCue() }
        .task(id: item.id) {
            // Tour only: draw the front card mid-drag, with no finger down.
            guard isFront, let pose = UITestSupport.cardPoseWidth else { return }
            try? await Task.sleep(for: .milliseconds(400))
            dragOffset = CGSize(width: pose, height: 0)
        }
        .onTapGesture {
            // Live Photos: tap the front card to play the paired motion.
            guard isFront, item.isLivePhoto else { return }
            HapticsService.shared.light()
            withAnimation(liveAnimation) {
                showLivePlayback.toggle()
                liveGlow = showLivePlayback ? 1 : 0
            }
        }
        .task(id: item.id) {
            guard isFront else { return }
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
            liveGlow = 0
            if isFront { dragModel?.signal = EdgeSignal.rest }
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

    /// The card: the photo in its frame, and the nameplate under it. Nothing is drawn over the photo except
    /// its badges and the size chip, so the whole picture can be judged before deciding.
    private var cardBody: some View {
        VStack(spacing: 10) {
            ExhibitFrame(
                chip: Wording.exhibitChip(size: item.formattedSize, age: item.ageDescription),
                accent: item.monsterType.accentColor,
                lift: progress.lift,
                highlightShift: progress.highlightShift,
                skin: skin,
                skinSeed: item.id,
                crack: crackAmount,
                combo: comboState,
                liveGlow: liveGlow
            ) { photoLayer }
            Nameplate(
                monster: item.monsterType,
                why: item.classification?.whyText,
                needsCarefulReview: item.classification?.requiresCarefulReview == true,
                skin: skin,
                jitters: isFront && !gate.isStill,
                seedKey: item.id,
                glowColor: item.monsterType.accentColor
            )
        }
        .padding(8)
        .padding(.bottom, 4)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.dungeonStone)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.dungeonAsh, lineWidth: 1))
        )
    }

    /// The skin's moving parts, in the two side bands only (see `SkinEdgeLayer`).
    @ViewBuilder
    private var edgeLayer: some View {
        if let skin {
            SkinEdgeLayer(
                kind: skin,
                seedKey: item.id,
                accent: item.monsterType.accentColor,
                gate: gate,
                isFront: isFront,
                dragX: Double(dragOffset.width),
                dragY: Double(dragOffset.height),
                lift: progress.lift,
                burstStart: burstStart
            )
        }
    }

    private var photoLayer: some View {
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
                    VideoPreviewStage(gate: gate)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .overlay {
                if item.kind == .video, !(isFront && showLivePreview) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 70, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .top) { topMetaBar }
    }

    private var topMetaBar: some View {
        HStack(spacing: 8) {
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
        .padding(10)
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
        .accessibilityLabel("Shade. Already deleted once — no rewards this time.")
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

    private var deleteOverlay: some View {
        let strength = max(0, min(1, -dragOffset.width / commitThreshold))
        // Under the gate the armed state shows at once: the stamp jumps to full strength.
        let stamp: CGFloat = (gate.isStill && armedSide == .delete) ? 1 : strength
        // The tear itself is drawn at the screen's left edge (`ScreenEdgeOverlay`); only the stamp rides the card.
        return ZStack {
            Text("DELETE")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(.white)
                .padding(10).padding(.horizontal, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.combatCrimsonDeep))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.6), lineWidth: 1))
                .rotationEffect(.degrees(-12))
                .opacity(stamp)
                .scaleEffect(0.6 + stamp * 0.5)
                .position(x: 110, y: 80)
        }
        .allowsHitTesting(false)
    }

    private var spareOverlay: some View {
        let strength = max(0, min(1, dragOffset.width / commitThreshold))
        let stamp: CGFloat = (gate.isStill && armedSide == .keep) ? 1 : strength
        // The barrier itself is drawn at the screen's right edge (`ScreenEdgeOverlay`); only the stamp rides the card.
        return ZStack(alignment: .topTrailing) {
            Text("KEEP")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(.onAccent)
                .padding(10).padding(.horizontal, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.gemEmeraldDeep))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.6), lineWidth: 1))
                .rotationEffect(.degrees(12))
                .opacity(stamp)
                .scaleEffect(0.6 + stamp * 0.5)
                .padding(.top, 60)
                .padding(.trailing, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
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

    /// The combo's moment on this card as it arrives: a pulse after a raise, a fade from ash after a keep, one sheen at
    /// x2.0. Event-driven and once per card. Under the gate nothing moves: the rim fades in over 150 ms.
    private func playComboCue() async {
        guard isFront else { return }
        if gate.isStill {
            withAnimation(.easeInOut(duration: 0.15)) { comboShown = 1 }
            return
        }
        comboShown = 1
        switch comboCue {
        case .raised:
            comboPulse = 1
            try? await Task.sleep(for: .milliseconds(30))
            withAnimation(.easeOut(duration: 0.25)) { comboPulse = 0 }
        case .cooled:
            comboCool = 1
            try? await Task.sleep(for: .milliseconds(30))
            withAnimation(.easeInOut(duration: 0.4)) { comboCool = 0 }
        case .none:
            break
        }
        if shownTier.isMax {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.5)) { comboSheen = 1.4 }
        }
    }

    /// Tells the screen's edges how far this card is dragged. Once the card is committed the overlays let go.
    private func publishEdges() {
        guard isFront, let dragModel else { return }
        dragModel.animated = !gate.isStill
        dragModel.signal = snapAway == nil ? EdgeSignal(progress: progress) : EdgeSignal.rest
    }

    /// Keeps `armedSide` in step with the drag and fires the detent once per crossing.
    private func updateArming() {
        guard isFront, snapAway == nil else { return }
        let next = progress.armed
        guard next != armedSide else { return }
        armedSide = next
        guard let side = next else { return }
        fireDetent(side)
    }

    /// The haptic, then a 150 ms scale punch (skipped under the gate).
    private func fireDetent(_ side: SwipeProgress.Side) {
        switch side {
        case .delete: HapticsService.shared.detentDelete()
        case .keep:   HapticsService.shared.detentKeep()
        }
        guard !gate.isStill else { return }
        withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) { punch = 1.03 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) { punch = 1 }
        }
    }

    private func commit(left: Bool) {
        let target = CGSize(width: left ? -700 : 700, height: dragOffset.height + 50)
        // The Storage Behemoths throw stone chips as they go. Only a timestamp: the commit itself is unchanged.
        if skin == .behemoths, !gate.isStill { burstStart = Date() }
        if reduceMotion {
            snapAway = target
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                snapAway = target
            }
        }
        if isFront { dragModel?.signal = EdgeSignal.rest }
        // Fire callback after a short delay so the animation reads.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 80 : 220))
            if left { onDelete() } else { onSpare() }
        }
    }
}

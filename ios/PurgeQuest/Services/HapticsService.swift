//
//  HapticsService.swift
//  PurgeQuest
//

import UIKit
import CoreHaptics

@MainActor
final class HapticsService {
    static let shared = HapticsService()

    private var engine: CHHapticEngine?
    private(set) var supportsHaptics: Bool = false
    var reduceMotion: Bool = false

    private init() {
        let caps = CHHapticEngine.capabilitiesForHardware()
        supportsHaptics = caps.supportsHaptics
        if supportsHaptics {
            do {
                engine = try CHHapticEngine()
                engine?.isAutoShutdownEnabled = true
                try engine?.start()
            } catch {
                supportsHaptics = false
            }
        }
    }

    func light() {
        guard !reduceMotion else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func medium() {
        guard !reduceMotion else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func heavy() {
        guard !reduceMotion else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    func success() {
        guard !reduceMotion else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func warning() {
        guard !reduceMotion else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    func videoSlash() {
        guard !reduceMotion, supportsHaptics, let engine else {
            heavy(); return
        }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            heavy()
        }
    }

    func comboBurst() {
        guard !reduceMotion, supportsHaptics, let engine else {
            success(); return
        }
        var events: [CHHapticEvent] = []
        for i in 0..<3 {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(0.6 + Double(i) * 0.15))
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(0.5 + Double(i) * 0.15))
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: TimeInterval(i) * 0.08))
        }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            success()
        }
    }
}

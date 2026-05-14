//
//  FoundationFlavorService.swift
//  PurgeQuest
//
//  On-device dynamic monster flavor text using Apple Intelligence
//  Foundation Models (iOS 26+). Falls back to MonsterType.flavor
//  when unavailable. Generation is serialized through an actor to
//  avoid Neural Engine contention, and results are cached per item.
//

import Foundation

@MainActor
@Observable
final class FoundationFlavorService {
    static let shared = FoundationFlavorService()

    private var cache: [String: String] = [:]
    private var inFlight: Set<String> = []

    private init() {}

    /// Returns the cached flavor for an item if present (sync, cheap).
    func cached(for item: MediaItem) -> String? {
        cache[item.id]
    }

    /// Best-effort dynamic flavor. Returns the static fallback immediately
    /// if Apple Intelligence isn't available, otherwise generates and caches.
    func flavor(for item: MediaItem) async -> String {
        if let hit = cache[item.id] { return hit }

        if #available(iOS 26.0, *) {
            if FoundationFlavorCoordinator.shared.isAvailable {
                if inFlight.contains(item.id) {
                    return item.monsterType.flavor
                }
                inFlight.insert(item.id)
                defer { inFlight.remove(item.id) }

                if let generated = await FoundationFlavorCoordinator.shared.generate(for: item) {
                    cache[item.id] = generated
                    return generated
                }
            }
        }
        return item.monsterType.flavor
    }
}

// MARK: - iOS 26+ Foundation Models coordinator

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
fileprivate actor FoundationFlavorCoordinator {
    static let shared = FoundationFlavorCoordinator()

    nonisolated var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    private var session: LanguageModelSession?

    private func ensureSession() -> LanguageModelSession {
        if let s = session { return s }
        let s = LanguageModelSession {
            "You write punchy, witty one-line monster taunts for a photo-cleanup RPG called PurgeQuest."
            "Each photo or video in the player's camera roll is a monster they will slay to free storage."
            "Voice: dramatic, fantasy-flavored, slightly tongue-in-cheek. Never mean or self-deprecating about the player."
            "DO NOT use quotes, emojis, hashtags, or markdown."
            "DO NOT exceed 18 words. One sentence only."
        }
        s.prewarm()
        session = s
        return s
    }

    func generate(for item: MediaItem) async -> String? {
        let s = ensureSession()
        guard !s.isResponding else { return nil }

        let prompt = Self.buildPrompt(for: item)
        do {
            let response = try await s.respond(
                to: prompt,
                options: GenerationOptions(
                    sampling: .random(top: 40),
                    temperature: 0.95,
                    maximumResponseTokens: 60
                )
            )
            return Self.sanitize(response.content)
        } catch {
            return nil
        }
    }

    private static func buildPrompt(for item: MediaItem) -> String {
        let kind = item.kind == .video ? "video" : "photo"
        let monster = item.monsterType.displayName
        let size = item.formattedSize
        let age = item.ageDescription
        let duration = item.kind == .video && !item.formattedDuration.isEmpty
            ? ", duration \(item.formattedDuration)"
            : ""
        return """
        Write one taunt (max 18 words) for the monster about to be slain.
        Monster type: \(monster)
        Media: \(kind), \(size), captured \(age)\(duration).
        Reference at least one of: the size, the age, or the duration.
        """
    }

    private static func sanitize(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip surrounding quotes the model often adds despite instructions.
        let quoteSet = CharacterSet(charactersIn: "\"“”'`")
        s = s.trimmingCharacters(in: quoteSet)
        // Collapse newlines.
        s = s.replacingOccurrences(of: "\n", with: " ")
        // Hard cap to keep card layout safe.
        if s.count > 140 {
            s = String(s.prefix(140)).trimmingCharacters(in: .whitespaces) + "…"
        }
        return s
    }
}
#else
@available(iOS 26.0, *)
fileprivate enum FoundationFlavorCoordinator {
    static let shared = Self.self
    static var isAvailable: Bool { false }
    static func generate(for item: MediaItem) async -> String? { nil }
}
#endif

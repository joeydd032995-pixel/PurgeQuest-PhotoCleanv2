//
//  DesignSystemTests.swift
//  PurgeQuestTests
//
//  Light/Dark resolution of the adaptive colors, the new art in the asset
//  catalog, the Bestiary spotlight rule, and render smoke tests for every new
//  view in both appearances. Set SNAPSHOT_DIR (TEST_RUNNER_SNAPSHOT_DIR with
//  xcodebuild) and the renders are also saved as PNGs for visual review.
//

import Testing
import SwiftUI
import UIKit
@testable import PurgeQuest

// MARK: - Adaptive colors

struct AdaptiveColorTests {
    private func resolve(_ color: UIColor, dark: Bool) -> (r: Double, g: Double, b: Double) {
        let traits = UITraitCollection(userInterfaceStyle: dark ? .dark : .light)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    private func matches(_ value: (r: Double, g: Double, b: Double), _ rgb: ThemeRGB) -> Bool {
        abs(value.r - rgb.red) < 0.004 && abs(value.g - rgb.green) < 0.004 && abs(value.b - rgb.blue) < 0.004
    }

    @Test func everyTokenResolvesToItsLightAndDarkValue() {
        var tokens: [(String, ThemePair)] = []
        for background in ThemePalette.textBackgrounds { tokens.append((background.name, background.pair)) }
        for accent in ThemePalette.textAccents { tokens.append((accent.name, accent.pair)) }
        tokens.append(("textPrimary", ThemePalette.textPrimary))
        tokens.append(("textSecondary", ThemePalette.textSecondary))
        tokens.append(("textTertiary", ThemePalette.textTertiary))
        tokens.append(("hairline", ThemePalette.hairline))
        tokens.append(("onAccent", ThemePalette.onAccent))
        tokens.append(("goldTitle", ThemePalette.goldTitle))
        for (name, pair) in tokens {
            let color = UIColor.adaptive(pair)
            #expect(matches(resolve(color, dark: false), pair.light), "\(name) light")
            #expect(matches(resolve(color, dark: true), pair.dark), "\(name) dark")
        }
    }

    @Test func canvasIsLightInLightAndDeepGreenBlackInDark() {
        let canvas = UIColor.adaptive(ThemePalette.canvas)
        #expect(resolve(canvas, dark: false).r > 0.9)
        #expect(resolve(canvas, dark: true).r < 0.1)
    }
}

// MARK: - Assets and rules

struct DesignAssetTests {
    @Test func everyFamilyHasItsIconInTheAssetCatalog() {
        for family in MonsterFamily.allCases {
            #expect(UIImage(named: family.iconAssetName) != nil, "missing asset \(family.iconAssetName)")
        }
        #expect(Set(MonsterFamily.allCases.map(\.iconAssetName)).count == MonsterFamily.allCases.count)
    }

    @Test func emblemIsATransparentWingedShield() throws {
        let image = try #require(UIImage(named: EmblemView.assetName))
        let cg = try #require(image.cgImage)
        let hasAlpha: Bool
        switch cg.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: hasAlpha = false
        default: hasAlpha = true
        }
        #expect(hasAlpha, "emblem must keep its transparent background")
        let ratio = Double(cg.width) / Double(cg.height)
        #expect((1.15...1.40).contains(ratio), "unexpected emblem aspect \(ratio)")
    }

    @Test func spotlightFollowsTheLatestEncounterAndStartsOnTheFirstFamily() {
        #expect(MonsterFamily.spotlight(latestEncounters: []) == MonsterFamily.allCases[0])
        let now = Date()
        let met: [(family: MonsterFamily, at: Date)] = [
            (.storageBehemoths, now.addingTimeInterval(-300)),
            (.glitchborn, now),
            (.videoPhantoms, now.addingTimeInterval(-60))
        ]
        #expect(MonsterFamily.spotlight(latestEncounters: met) == .glitchborn)
    }

    @Test func spinnerHeadFadesIntoAMonotonicTail() {
        #expect(GoldSpinner.opacity(forSpoke: 3, head: 3) == 1.0)
        let tail = (0..<8).map { GoldSpinner.opacity(forSpoke: (3 - $0 + 8) % 8, head: 3) }
        #expect(tail == tail.sorted(by: >))
        #expect(tail.allSatisfy { $0 >= 0.18 && $0 <= 1.0 })
        #expect((0..<8).contains(GoldSpinner.headIndex(at: Date())))
    }
}

// MARK: - Render smoke tests (and optional PNG export)

@MainActor
struct SnapshotRenderTests {
    private func render<Content: View>(_ name: String, scheme: ColorScheme, width: CGFloat, height: CGFloat? = nil,
                                       @ViewBuilder content: () -> Content) -> UIImage? {
        DungeonFont.registerAll()
        let framed = ZStack {
            DungeonBackgroundView()
            content().padding(16)
        }
        .frame(width: width, height: height)
        .environment(\.colorScheme, scheme)

        let renderer = ImageRenderer(content: framed)
        renderer.scale = 2
        guard let image = renderer.uiImage else { return nil }

        if let directory = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"], let data = image.pngData() {
            try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            let suffix = scheme == .dark ? "dark" : "light"
            try? data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("\(name)-\(suffix).png"))
        }
        return image
    }

    private func tile(_ family: MonsterFamily, _ found: Int, _ total: Int, spotlight: Bool = false) -> some View {
        FamilyTileView(family: family, discovered: found, total: total, isSpotlight: spotlight)
    }

    @Test(arguments: [ColorScheme.light, ColorScheme.dark])
    func bestiaryTilesRender(scheme: ColorScheme) {
        let image = render("bestiary", scheme: scheme, width: 393) {
            VStack(alignment: .leading, spacing: 18) {
                BestiaryHeaderView(discovered: 0, total: 33)
                Grid(horizontalSpacing: 14, verticalSpacing: 14) {
                    GridRow { tile(.clutterUndead, 0, 8, spotlight: true); tile(.archiveRelics, 0, 1) }
                    GridRow { tile(.storageBehemoths, 0, 5); tile(.duplicateDragons, 0, 8) }
                    GridRow { tile(.videoPhantoms, 0, 8); tile(.glitchborn, 0, 3) }
                }
            }
        }
        #expect(image != nil)
        #expect((image?.size.height ?? 0) > 500)
    }

    @Test(arguments: [ColorScheme.light, ColorScheme.dark])
    func discoveredTilesRender(scheme: ColorScheme) {
        let image = render("bestiary-progress", scheme: scheme, width: 393) {
            Grid(horizontalSpacing: 14, verticalSpacing: 14) {
                GridRow { tile(.clutterUndead, 8, 8); tile(.archiveRelics, 1, 1, spotlight: true) }
                GridRow { tile(.storageBehemoths, 2, 5); tile(.duplicateDragons, 5, 8) }
            }
        }
        #expect(image != nil)
    }

    @Test(arguments: [ColorScheme.light, ColorScheme.dark])
    func goldButtonsRender(scheme: ColorScheme) {
        let image = render("gold-buttons", scheme: scheme, width: 393) {
            VStack(spacing: 16) {
                Button("Continue") {}.buttonStyle(.gold)
                Button("Enter the Dungeon") {}.buttonStyle(.gold(fullWidth: true))
                Button { } label: { Label("Rally for 20 Gems", systemImage: "diamond.fill") }
                    .buttonStyle(.gold(fullWidth: true))
                Button("Continue") {}.buttonStyle(.gold).disabled(true)
            }
        }
        #expect(image != nil)
    }

    @Test(arguments: [ColorScheme.light, ColorScheme.dark])
    func splashRenders(scheme: ColorScheme) {
        let image = render("splash", scheme: scheme, width: 393, height: 852) {
            SplashView()
        }
        #expect(image != nil)
        #expect(Int(image?.size.height ?? 0) == 852)
    }

    @Test(arguments: [ColorScheme.light, ColorScheme.dark])
    func paletteBoardRenders(scheme: ColorScheme) {
        let image = render("palette", scheme: scheme, width: 393) { PaletteBoard() }
        #expect(image != nil)
    }
}

/// Test-only swatch sheet: every text tone and accent on every surface.
private struct PaletteBoard: View {
    var body: some View {
        VStack(spacing: 10) {
            block("Canvas", Color.dungeonVoid)
            block("Surface", Color.dungeonStone)
            block("Raised", Color.dungeonStoneLight)
        }
    }

    private func block(_ title: String, _ background: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundStyle(Color.textPrimary)
            Text("Secondary text on \(title.lowercased())").font(.subheadline).foregroundStyle(Color.textSecondary)
            Text("Tertiary hint on \(title.lowercased())").font(.caption).foregroundStyle(Color.textTertiary)
            HStack(spacing: 6) {
                chip("amber", Color.questAmber)
                chip("crimson", Color.combatCrimson)
                chip("emerald", Color.gemEmerald)
                chip("jade", Color.xpViolet)
            }
            HStack(spacing: 6) {
                chip("sapphire", Color.videoSapphire)
                chip("indigo", Color.behemothIndigo)
                chip("coral", Color.dragonCoral)
                chip("rose", Color.glitchRose)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(background))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.dungeonAsh, lineWidth: 1))
    }

    private func chip(_ name: String, _ color: Color) -> some View {
        Text(name)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(color.opacity(0.14)))
    }
}

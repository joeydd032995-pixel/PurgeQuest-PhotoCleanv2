//
//  SettingsView.swift
//  PurgeQuest
//

import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Query private var heroes: [Hero]
    @Query(sort: \DeletedMediaRecord.deletedAt, order: .reverse) private var deletions: [DeletedMediaRecord]

    @State private var confirmReset = false
    @State private var confirmForgetSpared = false
    @State private var showHeroCard = false

    private var hero: Hero? { heroes.first }

    var body: some View {
        @Bindable var appState = appState
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.textPrimary)

                section(title: "Cleanup") {
                    toggleRow(title: "Include Videos", subtitle: "Review photos and videos together", isOn: $appState.includeVideos)
                    toggleRow(title: "Video Focus Mode", subtitle: "Video-only review sessions", isOn: $appState.videoOnlyMode)
                    Button(role: .destructive) {
                        confirmForgetSpared = true
                    } label: {
                        Label("Forget spared monsters", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                section(title: "Lifetime Stats") {
                    statRow(label: "Photos purged",  value: "\(hero?.totalPhotosPurged ?? 0)", icon: "photo.fill", tint: .questAmber)
                    statRow(label: "Videos purged",  value: "\(hero?.totalVideosPurged ?? 0)", icon: "video.fill", tint: .videoSapphire)
                    statRow(label: "Total freed",    value: formattedFreed,                   icon: "internaldrive.fill", tint: .gemEmerald)
                    statRow(label: "Highest combo",  value: "\(hero?.highestCombo ?? 0)×",    icon: "bolt.fill", tint: .combatCrimson)
                    statRow(label: "Longest streak", value: "\(hero?.streakDays ?? 0) days",   icon: "flame.fill", tint: .questAmberDeep)
                }

                section(title: "Recently Deleted (last 7 days)") {
                    if deletions.isEmpty {
                        Text("No items in your purge log.")
                            .font(.callout).foregroundStyle(.textSecondary)
                    } else {
                        ForEach(deletions.prefix(20)) { rec in
                            HStack {
                                Image(systemName: rec.mediaKind == .photo ? "photo.fill" : "video.fill")
                                    .foregroundStyle(rec.mediaKind == .photo ? Color.questAmber : Color.videoSapphire)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(rec.monsterType.displayName)
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(.textPrimary)
                                    Text("\(ByteCountFormatter.string(fromByteCount: rec.fileSizeBytes, countStyle: .file)) · \(rec.deletedAt.formatted(.relative(presentation: .named)))")
                                        .font(.caption2)
                                        .foregroundStyle(.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 6)
                        }
                        Button {
                            if let url = URL(string: "photos-redirect://") { UIApplication.shared.open(url) }
                        } label: {
                            Label("Open Photos · Recently Deleted", systemImage: "photo.stack")
                                .font(.callout.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.questAmber.opacity(0.15)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.questAmber.opacity(0.4), lineWidth: 1)))
                                .foregroundStyle(.questAmber)
                        }
                    }
                }

                section(title: "Privacy") {
                    Text("PurgeQuest runs **100% on-device**. Your photos and videos never leave your iPhone. There's no analytics server, no tracking, no cloud sync. Deleted items move to **Photos → Recently Deleted** and can be restored for 30 days.")
                        .font(.callout)
                        .foregroundStyle(.textSecondary)
                }

                section(title: "About") {
                    HStack { Text("Version"); Spacer(); Text("1.0.0").foregroundStyle(.textSecondary) }
                    Button {
                        showHeroCard = true
                    } label: {
                        Label("Share Hero Card", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button(role: .destructive) {
                        confirmReset = true
                    } label: {
                        Label("Reset all PurgeQuest data", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Color.clear.frame(height: 30)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .scrollIndicators(.hidden)
        .background(DungeonBackgroundView())
        .alert("Reset all data?", isPresented: $confirmReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { resetAllData() }
        } message: {
            Text("This will erase your hero, achievements, and quests. Your Photos library is unaffected.")
        }
        .alert("Forget spared monsters?", isPresented: $confirmForgetSpared) {
            Button("Cancel", role: .cancel) {}
            Button("Forget", role: .destructive) { forgetSpared() }
        } message: {
            Text("Monsters you previously spared will reappear at the top of your next dive.")
        }
        .sheet(isPresented: $showHeroCard) {
            if let hero { HeroCardSheet(hero: hero) }
        }
    }

    private var formattedFreed: String {
        let mb = hero?.totalMBFreed ?? 0
        if mb >= 1024 { return String(format: "%.2f GB", mb / 1024.0) }
        return String(format: "%.0f MB", mb)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.heavy))
                .tracking(0.6)
                .foregroundStyle(.textSecondary)
                .padding(.leading, 6)
            VStack(alignment: .leading, spacing: 10) {
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

    private func toggleRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(isOn: isOn) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.callout.weight(.semibold)).foregroundStyle(.textPrimary)
                    Text(subtitle).font(.caption).foregroundStyle(.textSecondary)
                }
            }
            .tint(.questAmber)
        }
    }

    private func statRow(label: String, value: String, icon: String, tint: Color) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 22)
            Text(label).foregroundStyle(.textPrimary)
            Spacer()
            Text(value).font(.callout.monospacedDigit().weight(.semibold)).foregroundStyle(tint)
        }
    }

    private func forgetSpared() {
        for r in (try? modelContext.fetch(FetchDescriptor<SparedMediaRecord>())) ?? [] {
            modelContext.delete(r)
        }
        try? modelContext.save()
    }

    private func resetAllData() {
        for h in heroes { modelContext.delete(h) }
        for d in deletions { modelContext.delete(d) }
        for s in (try? modelContext.fetch(FetchDescriptor<SparedMediaRecord>())) ?? [] { modelContext.delete(s) }
        for q in (try? modelContext.fetch(FetchDescriptor<Quest>())) ?? [] { modelContext.delete(q) }
        for a in (try? modelContext.fetch(FetchDescriptor<Achievement>())) ?? [] { modelContext.delete(a) }
        for c in (try? modelContext.fetch(FetchDescriptor<CosmeticItem>())) ?? [] { modelContext.delete(c) }
        try? modelContext.save()
        UserDefaults.standard.removeObject(forKey: "pq.hasOnboarded")
        UserDefaults.standard.removeObject(forKey: "pq.selectedClass")
        UserDefaults.standard.removeObject(forKey: "pq.heroName")
        appState.hasOnboarded = false
        appState.phase = .onboarding
    }
}

// MARK: - Hero Card share

private struct HeroCardSheet: View {
    let hero: Hero
    @Environment(\.dismiss) private var dismiss
    @State private var renderedImage: UIImage?

    var body: some View {
        VStack(spacing: 18) {
            Text("Your Hero Card")
                .font(.title2.weight(.bold))
                .foregroundStyle(.textPrimary)
            HeroCardArtwork(hero: hero)
                .padding(.horizontal, 24)

            if let img = renderedImage {
                ShareLink(item: Image(uiImage: img), preview: SharePreview("PurgeQuest Hero Card", image: Image(uiImage: img))) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .padding(.vertical, 12).padding(.horizontal, 24)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.questAmber))
                        .foregroundStyle(.dungeonVoid)
                }
            } else {
                ProgressView().tint(.questAmber)
            }
            Button("Close") { dismiss() }
                .foregroundStyle(.textSecondary)
                .padding(.bottom, 12)
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DungeonBackgroundView())
        .task {
            // Render off-screen for share
            let renderer = ImageRenderer(content: HeroCardArtwork(hero: hero).frame(width: 540, height: 720))
            renderer.scale = 2
            renderedImage = renderer.uiImage
        }
    }
}

private struct HeroCardArtwork: View {
    let hero: Hero
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: hero.heroClass.symbol)
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(.questAmber)
                .frame(width: 108, height: 108)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.dungeonStoneLight)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.questAmber.opacity(0.6), lineWidth: 1.5))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.questAmber.opacity(0.3), lineWidth: 1).padding(3))
                )
            Text(hero.name).font(.dungeonTitle).foregroundStyle(.textPrimary)
            Text("\(hero.heroClass.displayName) · LV \(hero.level)").font(.headline).foregroundStyle(.textSecondary)
            HStack(spacing: 10) {
                StatTile(icon: "internaldrive.fill", label: "Total freed",
                         value: hero.totalMBFreed >= 1024 ? String(format: "%.1f GB", hero.totalMBFreed / 1024) : String(format: "%.0f MB", hero.totalMBFreed),
                         tint: .gemEmerald)
                StatTile(icon: "bolt.fill", label: "Peak combo", value: "\(hero.highestCombo)×", tint: .combatCrimson)
            }
            HStack(spacing: 10) {
                StatTile(icon: "photo.fill", label: "Photos", value: "\(hero.totalPhotosPurged)", tint: .questAmber)
                StatTile(icon: "video.fill", label: "Videos", value: "\(hero.totalVideosPurged)", tint: .videoSapphire)
            }
            Text("PurgeQuest")
                .font(.dungeonCaption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(.questAmber)
                .padding(.top, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.dungeonStone)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.questAmber.opacity(0.6), lineWidth: 1.5))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.questAmber.opacity(0.3), lineWidth: 1).padding(3))
        )
    }
}

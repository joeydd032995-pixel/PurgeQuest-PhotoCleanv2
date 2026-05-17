//
//  PurgeQuestWidget.swift
//  PurgeQuestWidget
//
//  Three widget kinds:
//   • DailyQuestWidget — homescreen small/medium showing featured daily quest progress
//   • StreakWidget     — homescreen small with flame + streak count + total MB freed
//   • LockScreenWidget — accessoryCircular gem counter + accessoryRectangular streak/quest
//

import WidgetKit
import SwiftUI

// MARK: - Provider

nonisolated struct PurgeEntry: TimelineEntry {
    let date: Date
    let snapshot: PurgeQuestWidgetSnapshot
}

nonisolated struct PurgeProvider: TimelineProvider {
    func placeholder(in context: Context) -> PurgeEntry {
        PurgeEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (PurgeEntry) -> Void) {
        let snap = context.isPreview ? .placeholder : WidgetSnapshotReader.read()
        completion(PurgeEntry(date: .now, snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PurgeEntry>) -> Void) {
        let snap = WidgetSnapshotReader.read()
        let entry = PurgeEntry(date: .now, snapshot: snap)
        // Refresh once an hour as a backstop; the app calls reloadAllTimelines() on writes.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Daily Quest Widget

struct DailyQuestWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PurgeEntry

    var body: some View {
        switch family {
        case .systemMedium: medium
        default: small
        }
    }

    private var progress: Double {
        guard entry.snapshot.questTarget > 0 else { return 0 }
        return min(1.0, Double(entry.snapshot.questCurrent) / Double(entry.snapshot.questTarget))
    }

    private var accent: Color {
        entry.snapshot.questIsVideo
            ? Color(red: 0.32, green: 0.62, blue: 0.98)
            : Color(red: 1.00, green: 0.74, blue: 0.21)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: entry.snapshot.questIsVideo ? "film.fill" : "scroll.fill")
                    .font(.caption.weight(.bold))
                Text("DAILY QUEST")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(0.6)
            }
            .foregroundStyle(accent)

            Text(entry.snapshot.questTitle)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .lineLimit(2)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.snapshot.questCurrent) / \(entry.snapshot.questTarget)")
                    .font(.system(.title3, design: .rounded).weight(.heavy))
                    .foregroundStyle(accent)
                ProgressBar(progress: progress, tint: accent)
                    .frame(height: 6)
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.04, blue: 0.06), Color(red: 0.10, green: 0.09, blue: 0.13)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: entry.snapshot.questIsVideo ? "film.fill" : "scroll.fill")
                    Text("DAILY QUEST")
                        .tracking(0.6)
                }
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(accent)

                Text(entry.snapshot.questTitle)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(entry.snapshot.questSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer(minLength: 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(entry.snapshot.questCurrent) / \(entry.snapshot.questTarget)")
                            .font(.system(.title3, design: .rounded).weight(.heavy))
                            .foregroundStyle(accent)
                        Spacer()
                        Label("\(entry.snapshot.streakDays)", systemImage: "flame.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                    ProgressBar(progress: progress, tint: accent)
                        .frame(height: 7)
                }
            }
            // Hero crest
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [accent.opacity(0.7), accent.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                    Text("\(entry.snapshot.heroLevel)")
                        .font(.system(.title, design: .rounded).weight(.black))
                        .foregroundStyle(.white)
                }
                .frame(width: 56, height: 56)
                Text("LV")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.04, blue: 0.06), Color(red: 0.10, green: 0.09, blue: 0.13)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }
}

struct DailyQuestWidget: Widget {
    let kind: String = "PurgeQuest.DailyQuest"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PurgeProvider()) { entry in
            DailyQuestWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Quest")
        .description("Track your active PurgeQuest daily quest progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Streak Widget

struct StreakWidgetView: View {
    let entry: PurgeEntry

    private var freedString: String {
        let mb = entry.snapshot.totalMBFreed
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return "\(Int(mb.rounded())) MB"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("STREAK")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.orange)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.orange)
                Text("\(entry.snapshot.streakDays)")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                Text("d")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Image(systemName: "internaldrive.fill")
                    .font(.caption2)
                Text(freedString + " freed")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                Image(systemName: "diamond.fill")
                    .font(.caption2)
                    .foregroundStyle(Color(red: 0.18, green: 0.85, blue: 0.55))
                Text("\(entry.snapshot.gems)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.primary)
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.05, blue: 0.04), Color(red: 0.04, green: 0.04, blue: 0.06)],
                startPoint: .top, endPoint: .bottom
            )
        }
    }
}

struct StreakWidget: Widget {
    let kind: String = "PurgeQuest.Streak"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PurgeProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Streak Flame")
        .description("Keep your daily PurgeQuest streak alive.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Lock Screen Widgets

struct LockGemView: View {
    let entry: PurgeEntry
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "diamond.fill")
                    .font(.caption.weight(.bold))
                Text("\(entry.snapshot.gems)")
                    .font(.system(.caption2, design: .rounded).weight(.heavy))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
        .widgetAccentable()
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct LockRectView: View {
    let entry: PurgeEntry

    private var progress: Double {
        guard entry.snapshot.questTarget > 0 else { return 0 }
        return min(1.0, Double(entry.snapshot.questCurrent) / Double(entry.snapshot.questTarget))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                Text("\(entry.snapshot.streakDays)d streak")
                Spacer(minLength: 0)
                Image(systemName: "diamond.fill")
                Text("\(entry.snapshot.gems)")
                    .monospacedDigit()
            }
            .font(.caption2.weight(.bold))

            Text(entry.snapshot.questTitle)
                .font(.caption.weight(.heavy))
                .lineLimit(1)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(.primary)
        }
        .widgetAccentable()
        .containerBackground(for: .widget) { Color.clear }
    }
}

struct LockScreenGemWidget: Widget {
    let kind: String = "PurgeQuest.LockGem"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PurgeProvider()) { entry in
            LockGemView(entry: entry)
        }
        .configurationDisplayName("Storage Gems")
        .description("Today's gem balance on your Lock Screen.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct LockScreenStreakWidget: Widget {
    let kind: String = "PurgeQuest.LockStreak"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PurgeProvider()) { entry in
            LockRectView(entry: entry)
        }
        .configurationDisplayName("Quest & Streak")
        .description("Featured daily quest and streak at a glance.")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - Helpers

private struct ProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule()
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(4, geo.size.width * progress))
            }
        }
    }
}

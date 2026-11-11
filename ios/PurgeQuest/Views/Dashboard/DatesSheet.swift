//
//  DatesSheet.swift
//  PurgeQuest
//
//  The Dashboard's date range: all dates, only a range, or everything except a range (see DateScope).
//  It edits a draft and writes to AppState only on Apply, the way the Forge does; swiping the sheet
//  away discards the draft.
//

import SwiftUI

struct DatesSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    // The draft is kept as the pickers' own state rather than as a DateScope, because a DateScope cannot
    // say "Only, but no day chosen yet": it would normalize to All dates.
    @State private var mode: DateScope.Mode
    @State private var hasStart: Bool
    @State private var hasEnd: Bool
    @State private var start: Date
    @State private var end: Date

    private let calendar = Calendar.current

    /// The earliest date a picker offers: well before any photo.
    private static let earliest = Calendar.current.date(from: DateComponents(year: 1900, month: 1, day: 1)) ?? Date.distantPast

    init(initial: DateScope) {
        let calendar = Calendar.current
        _mode = State(initialValue: initial.mode)
        _hasStart = State(initialValue: initial.from != nil)
        _hasEnd = State(initialValue: initial.to != nil)
        _start = State(initialValue: initial.from?.start(in: calendar) ?? Date())
        _end = State(initialValue: initial.to?.start(in: calendar) ?? Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                Picker("Date range", selection: $mode) {
                    Text("All dates").tag(DateScope.Mode.all)
                    Text("Only").tag(DateScope.Mode.only)
                    Text("Exclude").tag(DateScope.Mode.exclude)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("dates.mode")

                if mode != .all {
                    dateRows
                    quickPicks
                }
                explanation
                actions
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(DungeonBackgroundView())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: mode) { old, new in
            // Leaving All dates for the first time starts from something sensible rather than nothing.
            guard old == .all, new != .all, !hasStart, !hasEnd else { return }
            fill(new == .only ? .lastYear : .last30Days, haptic: false)
        }
        .onChange(of: start) { _, newValue in
            if hasEnd, CalendarDay(end, calendar: calendar) < CalendarDay(newValue, calendar: calendar) {
                end = newValue
            }
        }
        .onChange(of: end) { _, newValue in
            if hasStart, CalendarDay(newValue, calendar: calendar) < CalendarDay(start, calendar: calendar) {
                start = newValue
            }
        }
        .onChange(of: hasStart) { _, isOn in
            if isOn { pullEndUpToStart() }
        }
        .onChange(of: hasEnd) { _, isOn in
            if isOn { pullEndUpToStart() }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Dates")
                .font(.dungeonHeader)
                .foregroundStyle(.textPrimary)
            Text("Choose which photos and videos dives can show, by the date each was taken.")
                .font(.caption)
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dateRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            dateRow("Start date", isOn: $hasStart, date: $start, whenOff: "Starts at the beginning of your library")
            Rectangle().fill(Color.dungeonAsh.opacity(0.4)).frame(height: 1)
            dateRow("End date", isOn: $hasEnd, date: $end, whenOff: "Runs on with no end, so photos you take later are covered")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DungeonPanelBackground())
    }

    private func dateRow(_ title: String, isOn: Binding<Bool>, date: Binding<Date>, whenOff: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: isOn) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.textPrimary)
            }
            .tint(.questAmber)
            if isOn.wrappedValue {
                DatePicker(title, selection: date, in: Self.earliest...Date(), displayedComponents: .date)
                    .labelsHidden()
                    .tint(.questAmber)
            } else {
                Text(whenOff)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }
        }
    }

    private var quickPicks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUICK PICKS")
                .font(.dungeonCaption.weight(.bold))
                .foregroundStyle(.textSecondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                ForEach(DateQuickPick.allCases, id: \.self) { pick in
                    Button {
                        fill(pick)
                    } label: {
                        Text(pick.title)
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(DungeonPanelBackground(cornerRadius: DungeonRadius.chip, elevated: false))
                            .foregroundStyle(.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Quick picks fill in today's dates. They don't move as time passes.")
                .font(.caption2)
                .foregroundStyle(.textSecondary)
        }
    }

    @ViewBuilder
    private var explanation: some View {
        Group {
            if mode == .all {
                Text(DateScope.all.explanation())
            } else if !canApply {
                Text("Turn on a start date or an end date.")
            } else {
                Text(candidate.explanation())
            }
        }
        .font(.callout)
        .foregroundStyle(.textSecondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                HapticsService.shared.medium()
                appState.setDateScope(candidate)
                dismiss()
            } label: {
                Text("Apply")
            }
            .buttonStyle(.gold(fullWidth: true))
            .disabled(!canApply)
            .accessibilityIdentifier("dates.apply")

            if appState.dateScope.isActive {
                Button("Show all dates") {
                    HapticsService.shared.light()
                    appState.setDateScope(.all)
                    dismiss()
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(.textSecondary)
            }
        }
    }

    // MARK: - Draft

    /// What Apply would save. DateScope tidies it: reversed ends are swapped, no day at all is All dates.
    private var candidate: DateScope {
        DateScope(
            mode: mode,
            from: hasStart ? CalendarDay(start, calendar: calendar) : nil,
            to: hasEnd ? CalendarDay(end, calendar: calendar) : nil
        )
    }

    /// Only and Exclude need at least one end; All dates can always be applied.
    private var canApply: Bool { mode == .all || hasStart || hasEnd }

    /// Fills the pickers from a quick pick: concrete days from today, not a rule that keeps moving.
    private func fill(_ pick: DateQuickPick, haptic: Bool = true) {
        let days = pick.days(now: Date(), calendar: calendar)
        hasStart = days.from != nil
        hasEnd = days.to != nil
        if let first = days.from { start = first.start(in: calendar) }
        if let last = days.to { end = last.start(in: calendar) }
        if haptic { HapticsService.shared.light() }
    }

    /// An end before the start would be swapped when applied. Pull the end up to the start instead, so the
    /// pickers always say what will be applied.
    private func pullEndUpToStart() {
        guard hasStart, hasEnd,
              CalendarDay(end, calendar: calendar) < CalendarDay(start, calendar: calendar) else { return }
        end = start
    }
}

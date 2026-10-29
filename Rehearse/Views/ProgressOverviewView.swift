import Charts
import SwiftUI

/// Answers "is practice working?": how the score has moved across every
/// interview, how much rehearsing is happening, whether the same weakness
/// keeps coming back, and which part of the score moved.
struct ProgressOverviewView: View {
    @Environment(AppState.self) private var appState

    /// Oldest → newest.
    private var interviews: [Rehearsal] {
        appState.interviews.reversed().filter { $0.feedback != nil }
    }

    var body: some View {
        Group {
            if interviews.count >= 2 {
                ReportScroll {
                    SectionTitle(title: "Overall Score")
                    ScoreTrend(points: interviews.compactMap { interview in
                        interview.feedback.map { ScoreTrend.Point(rehearsal: interview, score: $0.overall) }
                    })
                    weekSection
                    patternSection
                    scoresSection
                }
            } else {
                ContentUnavailableView(
                    "Not Enough Interviews Yet",
                    systemImage: "chart.bar",
                    description: Text("Do two interviews and your progress will show up here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .groupedBackground()
            }
        }
        .screenTitle("Progress", inList: false)
    }

    // MARK: - This week

    private struct Day: Identifiable {
        let date: Date
        let count: Int
        let isFuture: Bool
        var id: Date { date }
    }

    /// The calendar week, in the locale's order, with rehearsals (interviews
    /// and practice) counted per day. Days still to come are dimmed.
    private var week: [Day] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let count = appState.rehearsals.filter { calendar.isDate($0.date, inSameDayAs: day) }.count
            return Day(date: day, count: count, isFuture: day > today)
        }
    }

    /// The week as a row of days, as in Fitness: a filled day with a tick
    /// is one you rehearsed on, and the total leads the card. Today's date
    /// is in the accent.
    @ViewBuilder
    private var weekSection: some View {
        let days = week
        let total = days.reduce(0) { $0 + $1.count }
        SectionTitle(title: "This Week")
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.xxs) {
                Text("\(total)")
                    .font(.title3.weight(.bold).monospacedDigit())
                Text(total == 1 ? "session" : "sessions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: 0) {
                ForEach(days) { day in
                    dayCircle(day)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .cardBackground()
    }

    private func dayCircle(_ day: Day) -> some View {
        let isToday = Calendar.current.isDateInToday(day.date)
        let isActive = day.count > 0
        return VStack(spacing: AppTheme.Spacing.xs) {
            Text(day.date.formatted(.dateTime.weekday(.narrow)))
                .font(.caption2.weight(isToday ? .bold : .semibold))
                .foregroundStyle(isToday ? AppTheme.brand : Color(.tertiaryLabel))
            // A practiced day wears the app's done mark, green, at the
            // day's size; the rest are empty discs.
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white, AppTheme.practiced)
                    .frame(width: 32, height: 32)
            } else {
                Circle()
                    .fill(AppTheme.fill)
                    .frame(width: 32, height: 32)
            }
            // Today is marked the way Calendar marks it: the date in the accent.
            Text(day.date.formatted(.dateTime.day()))
                .font(.caption.monospacedDigit().weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? AppTheme.brand : Color.secondary)
        }
        .opacity(day.isFuture ? 0.4 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isToday ? "Today" : day.date.formatted(.dateTime.weekday(.wide).day().month()))
        .accessibilityValue(day.isFuture ? "Still to come" : "\(day.count) \(day.count == 1 ? "session" : "sessions")")
    }

    // MARK: - Pattern

    /// The weakness behind the score: each one flagged in the last three
    /// interviews, most often first. A row opens practice for it.
    @ViewBuilder
    private var patternSection: some View {
        let recent = Array(appState.interviews.prefix(3).reversed())
        let flagged = Skill.allCases
            .map { skill in (skill, recent.filter { $0.feedback?.focus == skill }.count) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }

        if !flagged.isEmpty {
            SectionTitle(title: "What Keeps Coming Up")
            VStack(spacing: 0) {
                ForEach(Array(flagged.enumerated()), id: \.element.0) { index, item in
                    let (skill, count) = item
                    if index > 0 { Divider().padding(.leading, AppTheme.Spacing.md) }
                    NavigationLink(value: skill == appState.currentFocus ? Route.practice : Route.library(focus: skill)) {
                        HStack(spacing: AppTheme.Spacing.sm) {
                            Text(skill.title)
                                .foregroundStyle(Color.primary)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(AppTheme.Spacing.md)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(CardRowButtonStyle())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(skill.title)
                    .accessibilityValue("Came up in \(count) of your last \(recent.count) interviews")
                    .accessibilityHint("Practice it")
                }
            }
            .cardBackground()
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        }
    }

    // MARK: - Scores

    /// The six areas the score is worked out from, lowest first so what to
    /// work on leads, each with its change since the first interview.
    @ViewBuilder
    private var scoresSection: some View {
        let rows = ScoreArea.allCases
            .map { area in (area, trend(of: area)) }
            .filter { !$0.1.isEmpty }
            .sorted { ($0.1.last ?? 0) < ($1.1.last ?? 0) }
        SectionTitle(title: "Since Your First Interview")
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.0) { index, row in
                let (area, trend) = row
                if index > 0 { Divider().padding(.leading, 52) }
                AreaScoreRow(area: area, score: trend.last ?? 0, delta: (trend.last ?? 0) - (trend.first ?? 0), showsChevron: false, symbolExplains: true)
            }
        }
        .cardBackground()
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    /// One area's score in every interview, oldest first.
    private func trend(of area: ScoreArea) -> [Int] {
        interviews.compactMap { $0.feedback?.areas.first { $0.area == area }?.score }
    }
}

/// A score over time, as Health draws a trend: the latest value large with
/// its date, the change since the first, and a line beneath. Tap a dot to
/// open that interview; touch and hold to read any of them.
struct ScoreTrend: View {
    struct Point: Identifiable {
        let rehearsal: Rehearsal
        let score: Int
        var id: Rehearsal.ID { rehearsal.id }
        var date: Date { rehearsal.date }
    }

    /// Oldest → newest.
    let points: [Point]

    /// Where the finger is on the chart, while it's held.
    @State private var selectedDate: Date?
    @State private var openedID: Rehearsal.ID?

    var body: some View {
        if let first = points.first, let latest = points.last, let lowest = points.map(\.score).min() {
            let shown = selected
            let headline = shown ?? latest
            // Low enough that every dot sits inside the chart.
            let floor = min(40, lowest / 20 * 20)
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    // Plainly out of 100, and the day it's from.
                    HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.xs) {
                        Text("\(headline.score)")
                            .font(.system(size: 52, weight: .bold).monospacedDigit())
                            .contentTransition(.numericText())
                        Text("out of 100")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Text("On \(headline.date.formatted(.dateTime.day().month(.wide)))")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    if let shown {
                        Text(shown.rehearsal.title)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        HStack(spacing: AppTheme.Spacing.xxs) {
                            DeltaText(delta: latest.score - first.score)
                            Text("since your first interview")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)

                Chart {
                    ForEach(points) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Score", point.score)
                        )
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .foregroundStyle(AppTheme.brand)
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Score", point.score)
                        )
                        // Hollow, as Health draws them, so the line runs
                        // through each one.
                        .symbol {
                            let size: CGFloat = point.id == shown?.id ? 14 : 9
                            Circle()
                                .fill(AppTheme.background)
                                .strokeBorder(AppTheme.brand, lineWidth: 2.5)
                                .frame(width: size, height: size)
                        }
                    }
                    if let shown {
                        RuleMark(x: .value("Selected", shown.date))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            .foregroundStyle(Color(.separator))
                    }
                }
                .chartYScale(domain: floor...100)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: Array(stride(from: floor, through: 100, by: 20))) {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color(.separator))
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .chartXAxis {
                    // Aligned keeps the first and last labels inside the plot.
                    AxisMarks(preset: .aligned, values: points.map(\.date)) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                    }
                }
                .chartXScale(range: .plotDimension(padding: 16))
                .chartXSelection(value: $selectedDate)
                // A tap opens the interview nearest it; touch and hold reads
                // them out, as in Health.
                .chartGesture { proxy in
                    SpatialTapGesture()
                        .onEnded { tap in
                            if let date: Date = proxy.value(atX: tap.location.x) {
                                openedID = nearest(to: date)?.id
                            }
                        }
                        .exclusively(before:
                            LongPressGesture(minimumDuration: 0.2)
                                .sequenced(before: DragGesture(minimumDistance: 0))
                                .onChanged { value in
                                    if case .second(true, let drag?) = value {
                                        proxy.selectXValue(at: drag.location.x)
                                    }
                                }
                                .onEnded { _ in selectedDate = nil }
                        )
                }
                .sensoryFeedback(.selection, trigger: shown?.id)
                .frame(height: 180)
                .accessibilityLabel("Score over time")
                .accessibilityValue(points.map { String($0.score) }.joined(separator: ", "))
            }
            // Straight on the page, not in a card, so the score leads.
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.md)
            .navigationDestination(item: $openedID) { id in
                RehearsalDetailView(rehearsalID: id)
            }
        }
    }

    /// The interview nearest the finger while the chart is held.
    private var selected: Point? {
        selectedDate.flatMap(nearest(to:))
    }

    private func nearest(to date: Date) -> Point? {
        points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }
}

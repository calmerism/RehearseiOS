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
                    scoreTrendCard
                    weeklyCard
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
        .scrollingTitle("Progress", inList: false)
    }

    // MARK: - This week

    private struct Day: Identifiable {
        let date: Date
        let count: Int
        var id: Date { date }
    }

    /// The last seven days, oldest first, with rehearsals (interviews and
    /// practice) counted per day.
    private var week: [Day] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let count = appState.rehearsals.filter { calendar.isDate($0.date, inSameDayAs: day) }.count
            return Day(date: day, count: count)
        }
    }

    /// The week as a row of days, as in Fitness: a filled day is one you
    /// rehearsed on; the total sits in the header, so the days carry no
    /// numbers. Today's date is in the accent.
    private var weeklyCard: some View {
        let days = week
        let total = days.reduce(0) { $0 + $1.count }
        return VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            HStack(alignment: .firstTextBaseline) {
                Label("This Week", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.xxs) {
                    Text("\(total)")
                        .font(.headline.weight(.bold).monospacedDigit())
                    Text(total == 1 ? "session" : "sessions")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

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
                .font(.caption2.weight(isToday ? .bold : .medium))
                .foregroundStyle(isToday ? AppTheme.brand : Color.secondary)
            Circle()
                .fill(isActive ? AppTheme.graphic : AppTheme.fill)
                .frame(width: 30, height: 30)
            // Today is marked the way Calendar marks it: the date in the accent.
            Text(day.date.formatted(.dateTime.day()))
                .font(.caption2.weight(isToday ? .bold : .regular))
                .foregroundStyle(isToday ? AppTheme.brand : Color.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).day().month()))
        .accessibilityValue("\(day.count) \(day.count == 1 ? "session" : "sessions")")
    }

    // MARK: - Score over time

    /// The overall score across every interview, as Health draws a trend:
    /// the latest value large, the change since the first, a line beneath.
    @ViewBuilder
    private var scoreTrendCard: some View {
        if let first = interviews.first?.feedback?.overall, let latest = interviews.last?.feedback?.overall {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                CardHeader(title: "Overall Score", systemImage: "chart.line.uptrend.xyaxis")
                VStack(alignment: .leading, spacing: 2) {
                    BigValue(value: "\(latest)", unit: "latest")
                    HStack(spacing: AppTheme.Spacing.xxs) {
                        DeltaText(delta: latest - first)
                        Text("since your first interview")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)

                Chart(interviews) { interview in
                    if let score = interview.feedback?.overall {
                        LineMark(
                            x: .value("Date", interview.date, unit: .day),
                            y: .value("Score", score)
                        )
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .foregroundStyle(AppTheme.brand)
                        PointMark(
                            x: .value("Date", interview.date, unit: .day),
                            y: .value("Score", score)
                        )
                        .symbolSize(36)
                        .foregroundStyle(AppTheme.brand)
                    }
                }
                .chartYScale(domain: 40...100)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: [40, 60, 80, 100]) {
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .chartXAxis {
                    // Aligned keeps the first and last labels inside the plot.
                    AxisMarks(preset: .aligned, values: interviews.map(\.date)) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .chartXScale(range: .plotDimension(padding: 20))
                .frame(height: 160)
                .accessibilityLabel("Overall score over time")
            }
            // Straight on the page, not in a card, as Your Score leads with
            // its score.
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.md)
        }
    }

    // MARK: - Pattern

    /// The weakness behind the score: how often each one has been flagged,
    /// most recent first, and whether practice is following it.
    @ViewBuilder
    private var patternSection: some View {
        let recent = Array(appState.interviews.prefix(3))
        let flagged = Skill.allCases
            .map { skill in (skill, recent.filter { $0.feedback?.focus == skill }.count) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }

        SectionTitle(title: "What Keeps Coming Up")
        VStack(spacing: 0) {
            ForEach(Array(flagged.enumerated()), id: \.element.0) { index, item in
                let (skill, count) = item
                if index > 0 { Divider().padding(.leading, AppTheme.Spacing.md) }
                HStack(spacing: AppTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(skill.title)
                            .font(.headline)
                        Text(skill == appState.currentFocus ? "Your current focus" : "Came up in \(count) of your last \(recent.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .accessibilityElement(children: .combine)
                .accessibilityValue("Came up in \(count) of your last \(recent.count) interviews")
            }
            if let focus = appState.currentFocus {
                Divider().padding(.leading, AppTheme.Spacing.md)
                NavigationLink(value: Route.practice) {
                    HStack {
                        Text("Improve \(focus.title)")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(AppTheme.Spacing.md)
                }
                .buttonStyle(CardRowButtonStyle())
                .foregroundStyle(AppTheme.brand)
            }
        }
        .cardBackground()
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    // MARK: - Scores

    /// The five areas the score is worked out from, each as a row with the
    /// latest value on the right and the change beneath it, as Health lists
    /// its trends.
    @ViewBuilder
    private var scoresSection: some View {
        SectionTitle(title: "Since Your First Interview")
        VStack(spacing: 0) {
            ForEach(Array(ScoreArea.allCases.enumerated()), id: \.element) { index, area in
                if index > 0 { Divider().padding(.leading, 52) }
                change(area, trend: trend(of: area))
            }
        }
        .cardBackground()
    }

    /// One area's score in every interview, oldest first.
    private func trend(of area: ScoreArea) -> [Int] {
        interviews.compactMap { $0.feedback?.areas.first { $0.area == area }?.score }
    }

    @ViewBuilder
    private func change(_ area: ScoreArea, trend: [Int]) -> some View {
        if let first = trend.first, let last = trend.last {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                Image(systemName: area.symbol)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.graphic)
                    .frame(width: 24)
                Text(area.title)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(last)")
                        .font(.rowScore)
                    HStack(spacing: AppTheme.Spacing.xxs) {
                        DeltaText(delta: last - first)
                        Text("from \(first)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview {
    NavigationStack { ProgressOverviewView() }
        .environment(AppState())
}

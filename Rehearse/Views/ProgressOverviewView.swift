import SwiftUI

/// Answers "is practice working?": how much rehearsing is happening, how the
/// score has moved since the first interview, whether the same weakness keeps
/// coming back, and which part of the score moved.
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
                    weeklyCard
                    statStrip
                    firstVersusLatestCard
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
                .background(WarmBackground())
            }
        }
        .navigationTitle("Your progress")
        .navigationBarTitleDisplayMode(.inline)
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
    /// rehearsed on, with how many sessions; today is outlined.
    private var weeklyCard: some View {
        let days = week
        let total = days.reduce(0) { $0 + $1.count }
        return VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week")
                    .font(.app(.subheadline))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(total)")
                    .font(.app(.headline, weight: .bold).monospacedDigit())
                + Text(total == 1 ? " session" : " sessions")
                    .font(.app(.footnote))
                    .foregroundStyle(.secondary)
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
                .font(.app(.caption2, weight: isToday ? .bold : .medium))
                .foregroundStyle(isToday ? Color.primary : Color.secondary)
            ZStack {
                if isActive {
                    Circle()
                        .fill(LinearGradient(colors: [AppTheme.peach, AppTheme.brand], startPoint: .top, endPoint: .bottom))
                        .shadow(color: AppTheme.brand.opacity(0.25), radius: 6, y: 3)
                    Text("\(day.count)")
                        .font(.app(.footnote, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white)
                } else {
                    Circle()
                        .fill(AppTheme.chip)
                        .overlay { Circle().strokeBorder(AppTheme.track, lineWidth: 1) }
                }
                if isToday {
                    Circle()
                        .strokeBorder(AppTheme.ink, lineWidth: 1.5)
                        .padding(-4)
                }
            }
            .frame(width: 34, height: 34)
            Text(day.date.formatted(.dateTime.day()))
                .font(.app(.caption2))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).day().month()))
        .accessibilityValue("\(day.count) \(day.count == 1 ? "session" : "sessions")")
    }

    // MARK: - Totals

    private var statStrip: some View {
        let best = interviews.compactMap { $0.feedback?.overall }.max() ?? 0
        return HStack(spacing: AppTheme.Spacing.sm) {
            stat("\(appState.rehearsals.count)", label: "Sessions")
            stat("\(interviews.count)", label: "Interviews")
            stat("\(best)", label: "Best score")
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func stat(_ value: String, label: String) -> some View {
        VStack(spacing: AppTheme.Spacing.xxs) {
            Text(value)
                .font(.app(.title, weight: .bold).monospacedDigit())
            Text(label)
                .font(.app(.caption))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, AppTheme.Spacing.lg)
        .padding(.horizontal, AppTheme.Spacing.xs)
        .cardBackground()
        .accessibilityElement(children: .combine)
    }

    // MARK: - First vs latest

    /// Where the candidate started and where they are now, side by side.
    @ViewBuilder
    private var firstVersusLatestCard: some View {
        if let first = interviews.first, let latest = interviews.last,
           let firstScore = first.feedback?.overall, let latestScore = latest.feedback?.overall {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text("First vs latest")
                        .font(.app(.subheadline))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(interviews.count)")
                        .font(.app(.headline, weight: .bold).monospacedDigit())
                    + Text(" interviews")
                        .font(.app(.footnote))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: AppTheme.Spacing.sm) {
                    scoreTile(firstScore, date: first.date, isLatest: false)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    scoreTile(latestScore, date: latest.date, isLatest: true)
                }
            }
            .padding(AppTheme.Spacing.md)
            .cardBackground()
            .accessibilityElement(children: .combine)
        }
    }

    private func scoreTile(_ score: Int, date: Date, isLatest: Bool) -> some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.app(.largeTitle, weight: .bold).monospacedDigit())
                    .foregroundStyle(isLatest ? .white : .primary)
            }
            .frame(maxWidth: .infinity, minHeight: 104)
            .background(
                isLatest
                    ? LinearGradient(colors: [AppTheme.peach, AppTheme.brand], startPoint: .top, endPoint: .bottom)
                    : LinearGradient(colors: [AppTheme.chip, AppTheme.blush], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: AppTheme.Radius.control + 4)
            )
            Text(date.formatted(.dateTime.day().month(.abbreviated)))
                .font(.app(.caption, weight: .medium))
                .foregroundStyle(.secondary)
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

        SectionTitle(title: "What keeps coming up")
        ForEach(flagged, id: \.0) { skill, count in
            HStack(spacing: AppTheme.Spacing.md) {
                IconChip(systemImage: "bolt", tint: skill == appState.currentFocus ? AppTheme.brand : .primary, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.title)
                        .font(.app(.headline))
                    if skill == appState.currentFocus {
                        Text("Current focus")
                            .font(.app(.footnote))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                Text("\(count)")
                    .font(.app(.title2, weight: .bold).monospacedDigit())
                + Text("/\(recent.count)")
                    .font(.app(.footnote, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(AppTheme.Spacing.md)
            .cardBackground()
            .accessibilityElement(children: .combine)
            .accessibilityValue("Flagged in \(count) of your last \(recent.count) interviews")
        }
        if appState.currentFocus != nil {
            PrimaryLink(title: "Practice current focus", systemImage: "mic", route: .practice(nil))
                .padding(.top, AppTheme.Spacing.xxs)
        }
    }

    // MARK: - Scores

    @ViewBuilder
    private var scoresSection: some View {
        SectionTitle(title: "Since your first interview")
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            change("Communication", systemImage: "waveform", trend: appState.trend(\.communication))
            change("Answer quality", systemImage: "text.badge.checkmark", trend: appState.trend(\.answerQuality))
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func change(_ title: String, systemImage: String, trend: [Int]) -> some View {
        SummaryCard(title: title, systemImage: systemImage) {
            if let first = trend.first, let last = trend.last {
                VStack(alignment: .leading, spacing: 2) {
                    BigValue(value: "\(last)")
                    HStack(spacing: AppTheme.Spacing.xxs) {
                        DeltaText(delta: last - first)
                        Text("from \(first)")
                            .font(.app(.caption))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack { ProgressOverviewView() }
        .environment(AppState())
}

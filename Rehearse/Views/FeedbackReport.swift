import SwiftUI

/// The report for one interview, shared by the end of the live interview and
/// History so a result always reads the same way. Ordered by what to do with
/// it: the result, the one thing to work on, what went well, then detail.
/// Lay it out in a `ReportScroll`.
struct FeedbackReport<PracticeAction: View>: View {
    let rehearsal: Rehearsal
    @ViewBuilder let practiceAction: PracticeAction

    @Environment(AppState.self) private var appState

    var body: some View {
        if let feedback = rehearsal.feedback {
            resultCard(feedback)
            focusCard(feedback)
            strengthsCard(feedback)
            scoresCard(feedback)
            transcriptCard
        }
    }

    private var previous: Rehearsal? { appState.previousInterview(before: rehearsal) }

    // MARK: - Result

    private func resultCard(_ feedback: Feedback) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            SummaryCard(
                title: "Overall score",
                systemImage: "gauge.with.needle",
                tint: AppTheme.results,
                detail: rehearsal.date.formatted(date: .abbreviated, time: .omitted)
            ) {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.xs) {
                    BigValue(value: "\(feedback.overall)")
                    if let previousScore = previous?.feedback?.overall {
                        DeltaText(delta: feedback.overall - previousScore)
                        Text("from \(previousScore)")
                            .font(.app(.subheadline))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Your first scored interview")
                            .font(.app(.subheadline))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)

                Text(feedback.summary)
                    .fixedSize(horizontal: false, vertical: true)

                if let coverage = feedback.coverageNote {
                    Label(coverage, systemImage: "info.circle")
                        .font(.app(.footnote))
                        .foregroundStyle(.secondary)
                }
            }

            Text("This score is for tracking your practice. It doesn’t predict how the real interview will go.")
                .font(.app(.footnote))
                .foregroundStyle(.secondary)
                .padding(.horizontal, AppTheme.Spacing.md)
        }
    }

    // MARK: - Focus

    private func focusCard(_ feedback: Feedback) -> some View {
        SummaryCard(title: "Work on next", systemImage: "bolt", tint: AppTheme.focus) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(feedback.focus.title)
                    .font(.app(.title2, weight: .bold))
                if previous?.feedback?.focus == feedback.focus {
                    Label("This came up last time too", systemImage: "arrow.counterclockwise")
                        .font(.app(.footnote, weight: .semibold))
                        .foregroundStyle(AppTheme.focus)
                }
            }
            Text(feedback.focusEvidence)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text("Try this")
                    .font(.app(.footnote, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(feedback.focus.advice)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppTheme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.track, in: RoundedRectangle(cornerRadius: AppTheme.Radius.control))
            .accessibilityElement(children: .combine)

            practiceAction
                .padding(.top, AppTheme.Spacing.xxs)
        }
    }

    // MARK: - Strengths

    private func strengthsCard(_ feedback: Feedback) -> some View {
        SummaryCard(title: "Went well", systemImage: "checkmark.circle.fill", tint: AppTheme.success) {
            ForEach(feedback.strengths, id: \.self) { strength in
                Label(strength, systemImage: "checkmark")
                    .labelStyle(StrengthLabelStyle())
            }
        }
    }

    // MARK: - Scores

    private func scoresCard(_ feedback: Feedback) -> some View {
        SummaryCard(title: "Scores", systemImage: "chart.bar", tint: AppTheme.results) {
            scoreRow("Communication", score: feedback.communication, note: feedback.communicationNote)
            Divider()
            scoreRow("Answer Quality", score: feedback.answerQuality, note: feedback.answerQualityNote)
        }
    }

    private func scoreRow(_ title: String, score: Int, note: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            ScoreBar(title: title, score: score)
            Text(note)
                .font(.app(.footnote))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Transcript

    @ViewBuilder
    private var transcriptCard: some View {
        if !rehearsal.transcript.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        ForEach(Array(rehearsal.transcript.enumerated()), id: \.offset) { _, entry in
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                                if entry.isFollowUp {
                                    Text("Follow-up")
                                        .font(.app(.caption, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                Text(entry.question)
                                    .font(AppTheme.question(.callout))
                                Text(entry.answer)
                                    .font(.app(.subheadline))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, entry.isFollowUp ? AppTheme.Spacing.md : 0)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.top, AppTheme.Spacing.sm)
                } label: {
                    Label("Questions and answers", systemImage: "text.bubble")
                        .font(.app(.subheadline, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(AppTheme.Spacing.md)
                .cardBackground()

            }
        }
    }
}

private struct StrengthLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
            configuration.icon
                .font(.app(.footnote, weight: .bold))
                .foregroundStyle(AppTheme.success)
            configuration.title
        }
    }
}

/// The scrolling page a report sits on: cards on the grouped background.
struct ReportScroll<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                content
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
        }
        .background(WarmBackground())
    }
}

/// A past interview, opened from Home or History.
struct RehearsalDetailView: View {
    let rehearsalID: Rehearsal.ID
    @Environment(AppState.self) private var appState

    var body: some View {
        if let rehearsal = appState.rehearsal(id: rehearsalID) {
            ReportScroll {
                FeedbackReport(rehearsal: rehearsal) {
                    practiceLink(for: rehearsal)
                }
            }
            .navigationTitle(rehearsal.title)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Rehearsal Not Found", systemImage: "questionmark.circle")
        }
    }

    /// The latest interview's focus is the current one, so it goes to Practice.
    /// An older interview's focus may be settled; it opens matching questions.
    @ViewBuilder
    private func practiceLink(for rehearsal: Rehearsal) -> some View {
        if rehearsal.id == appState.lastInterview?.id {
            PrimaryLink(title: "Practice this", systemImage: "mic", route: .practice(nil))
        } else if let focus = rehearsal.feedback?.focus {
            PrimaryLink(title: "Questions for \(focus.title)", route: .library(focus: focus))
        }
    }
}

#Preview {
    let state = AppState()
    NavigationStack {
        RehearsalDetailView(rehearsalID: state.rehearsals[1].id)
    }
    .environment(state)
}

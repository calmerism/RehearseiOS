import SwiftUI

/// The report for one interview, shared by the end of the live interview and
/// History so a result always reads the same way: the score out of 100, how
/// it's worked out from six areas, what went well, the areas to grow, then
/// each question, which opens to show what went wrong in it. How Scoring
/// Works, from the toolbar or the Overall row, says what every number is
/// based on. Words are kept to a few per line.
/// Lay it out in a `ReportScroll`.
struct FeedbackReport<PracticeAction: View>: View {
    let rehearsal: Rehearsal
    /// The button on an area for growth that goes and works on it.
    @ViewBuilder let practiceAction: (Skill) -> PracticeAction

    @Environment(AppState.self) private var appState
    @State private var openQuestion: OpenQuestion?
    @State private var openArea: AreaScore?
    /// The area for growth in view, when there are several to swipe through.
    @State private var growthPage: Skill?
    @State private var showsScoring = false

    var body: some View {
        if let feedback = rehearsal.feedback {
            resultCard(feedback)
            breakdownCard(feedback)
            strengthsCard(feedback)
            growthCard(feedback)
            questionBreakdown(feedback)
            rehearseAgainButton
            footer
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("How Scoring Works", systemImage: "info.circle") { showsScoring = true }
                    }
                }
                .sheet(isPresented: $showsScoring) {
                    NavigationStack { ScoringInfoView() }
                        .presentationDetents([.large])
                }
                #if DEBUG
                .task {
                    // `-scoring` opens How Scoring Works, for screenshots.
                    guard ProcessInfo.processInfo.arguments.contains("-scoring") else { return }
                    try? await Task.sleep(for: .seconds(0.6))
                    showsScoring = true
                }
                #endif
        }
    }

    /// The main questions answered, which the score is based on.
    private var answerCount: Int { rehearsal.transcript.filter { !$0.isFollowUp }.count }

    private var previous: Rehearsal? { appState.previousInterview(before: rehearsal) }

    // MARK: - Result

    /// The total, large and plainly out of 100, what it means, how it moved
    /// since last time, and where it sits on the scale.
    private func resultCard(_ feedback: Feedback) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ScoreRing(
                score: feedback.overall,
                caption: "out of 100",
                size: 168,
                delta: (previous?.feedback?.overall).map { feedback.overall - $0 }
            )
                .padding(.top, AppTheme.Spacing.xs)
            VStack(spacing: AppTheme.Spacing.xxs) {
                Text(feedback.band.title)
                    .font(.title2.bold())
                if answerCount > 0 {
                    Text("Based on \(answerCount) \(answerCount == 1 ? "answer" : "answers")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            ScoreScale(score: feedback.overall)
        }
        // Straight on the page, not in a card, so the score leads the screen.
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.md)
    }

    // MARK: - How it's worked out

    /// Why the score is what it is: the six areas, each out of 100, and
    /// their average. Tap an area for the parts it's worked out from, or the
    /// average for how scoring works.
    private func breakdownCard(_ feedback: Feedback) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(feedback.areas.enumerated()), id: \.element.id) { index, area in
                if index > 0 { Divider().padding(.leading, 52) }
                Button {
                    openArea = area
                } label: {
                    AreaRow(area: area)
                }
                .buttonStyle(CardRowButtonStyle())
            }
            Divider()
            if feedback.deduction > 0 {
                HStack {
                    Text("Ended early")
                    Spacer()
                    Text("−\(feedback.deduction)")
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.record)
                }
                .font(.subheadline)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.sm)
            }
            Button {
                showsScoring = true
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Overall")
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                        Text(feedback.deduction > 0 ? "Average of the six, less \(feedback.deduction) for ending early" : "Average of the six")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(Text("\(feedback.overall)").font(.title3.bold()).foregroundStyle(Color.primary)) / 100")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(AppTheme.Spacing.md)
                .contentShape(Rectangle())
                .accessibilityElement(children: .combine)
                .accessibilityHint("Shows how scoring works")
            }
            .buttonStyle(CardRowButtonStyle())
        }
        .cardBackground()
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        #if DEBUG
        .task {
            // `-part N` opens an area's working, for screenshots.
            let arguments = ProcessInfo.processInfo.arguments
            guard let index = arguments.firstIndex(of: "-part"), arguments.indices.contains(index + 1),
                  let number = Int(arguments[index + 1]), feedback.areas.indices.contains(number) else { return }
            try? await Task.sleep(for: .seconds(0.6))
            openArea = feedback.areas[number]
        }
        #endif
        .sheet(item: $openArea) { area in
            NavigationStack {
                AreaDetailView(area: area)
            }
            .presentationDetents([.medium, .large])
            // Solid, so the score behind doesn't show through the rows.
            .presentationBackground(AppTheme.background)
        }
    }

    // MARK: - Strengths

    /// What went right with a tick, then what went wrong with a cross.
    private func strengthsCard(_ feedback: Feedback) -> some View {
        SummaryCard(title: "Insights") {
            ForEach(feedback.strengths.prefix(2), id: \.self) { strength in
                Label(strength, systemImage: "checkmark")
                    .labelStyle(InsightLabelStyle(tint: AppTheme.success))
            }
            ForEach(feedback.weaknesses, id: \.self) { weakness in
                Label(weakness, systemImage: "xmark")
                    .labelStyle(InsightLabelStyle(tint: AppTheme.record))
            }
        }
    }

    // MARK: - Again

    /// The same interview again, to see the change.
    @ViewBuilder
    private var rehearseAgainButton: some View {
        if rehearsal.interview != nil {
            PrimaryButton(title: "Rehearse Again") {
                appState.rehearseAgain(rehearsal)
            }
            .padding(.top, AppTheme.Spacing.sm)
        }
    }

    // MARK: - Growth

    /// What to improve, most important first: the interview's focus, then
    /// anything else an answer fell short on. Only what this interview
    /// showed, one card each, side by side, swiped through rather than
    /// stacked down the page.
    private func growthAreas(_ feedback: Feedback) -> [Skill] {
        let flagged = rehearsal.transcript.compactMap(\.weakSkill)
        var ordered = [feedback.focus] + flagged
        var seen = Set<Skill>()
        ordered = ordered.filter { seen.insert($0).inserted }
        return ordered
    }

    /// What this interview showed about a skill: the moment it came up, or
    /// the habit to build where it didn't.
    private func evidence(for skill: Skill, _ feedback: Feedback) -> String {
        if skill == feedback.focus { return feedback.focusEvidence }
        if let moment = rehearsal.transcript.first(where: { $0.weakSkill == skill })?.moment {
            return moment.note
        }
        return skill.advice
    }

    @ViewBuilder
    private func growthCard(_ feedback: Feedback) -> some View {
        let skills = growthAreas(feedback)
        SectionTitle(title: skills.count > 1 ? "Areas for Growth" : "Area for Growth")
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                ForEach(skills, id: \.self) { skill in
                    growthPage(skill, feedback)
                        // The next card peeks in from the right, so it's
                        // clear there's more to swipe to.
                        .containerRelativeFrame(.horizontal) { width, _ in
                            skills.count > 1 ? width - 28 : width
                        }
                        .id(skill)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $growthPage)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .scrollDisabled(skills.count < 2)
        if skills.count > 1 {
            GrowthDots(count: skills.count, current: skills.firstIndex(of: growthPage ?? skills[0]) ?? 0)
                .frame(maxWidth: .infinity)
        }
    }

    private func growthPage(_ skill: Skill, _ feedback: Feedback) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                Text(skill.title)
                    .cardTitleStyle()
                if skill == feedback.focus, previous?.feedback?.focus == feedback.focus {
                    Label("This came up last time too", systemImage: "arrow.counterclockwise")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.focus)
                }
            }
            Text(evidence(for: skill, feedback))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            practiceAction(skill)
                .padding(.top, AppTheme.Spacing.xxs)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardBackground()
    }

    // MARK: - Questions

    /// Each question with how it went at a glance: a tick, an exclamation
    /// mark or a cross, and its score. Tap one to see what went wrong and ask about it.
    @ViewBuilder
    private func questionBreakdown(_ feedback: Feedback) -> some View {
        if !rehearsal.transcript.isEmpty {
            SectionTitle(title: "Review Your Answers")
            VStack(spacing: 0) {
                ForEach(Array(numberedTranscript.enumerated()), id: \.offset) { index, item in
                    if index > 0 { Divider().padding(.leading, 52) }
                    Button {
                        openQuestion = OpenQuestion(number: item.number, entry: item.entry, focus: feedback.focus, areas: feedback.areas(for: item.entry))
                    } label: {
                        questionRow(number: item.number, entry: item.entry, score: feedback.score(for: item.entry))
                    }
                    .buttonStyle(CardRowButtonStyle())
                }
            }
            .cardBackground()
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            #if DEBUG
            .task {
                guard appState.debugOpensFirstAnswer, let first = numberedTranscript.first else { return }
                appState.debugOpensFirstAnswer = false
                try? await Task.sleep(for: .seconds(0.6))
                openQuestion = OpenQuestion(number: first.number, entry: first.entry, focus: feedback.focus, areas: feedback.areas(for: first.entry))
            }
            #endif
            .sheet(item: $openQuestion) { open in
                NavigationStack {
                    AnswerReviewView(number: open.number, entry: open.entry, focus: open.focus, areas: open.areas)
                }
            }
        }
    }

    private func questionRow(number: Int, entry: TranscriptEntry, score: Int?) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            verdictIcon(entry, score: score)
                .frame(width: 24)
            Text(entry.question)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
                .multilineTextAlignment(.leading)
            Spacer(minLength: AppTheme.Spacing.xs)
            if let score {
                Text("\(score)")
                    .font(.rowScore)
                    .foregroundStyle(Color.primary)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows what went wrong in this answer")
    }

    @ViewBuilder
    private func verdictIcon(_ entry: TranscriptEntry, score: Int?) -> some View {
        if let score {
            VerdictIcon(score: score)
        } else {
            // A follow-up, scored with its question.
            Image(systemName: "arrow.turn.down.right")
                .foregroundStyle(.secondary)
        }
    }

    /// When it took place, in full, at the end: "Saturday, 10 October 2026
    /// at 9:32 AM".
    private var footer: some View {
        Text(rehearsal.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year().hour().minute()))
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.xs)
    }

    private var numberedTranscript: [(number: Int, entry: TranscriptEntry)] {
        var number = 0
        return rehearsal.transcript.map { entry in
            if !entry.isFollowUp { number += 1 }
            return (max(number, 1), entry)
        }
    }
}

/// The answer whose review sheet is open.
private struct OpenQuestion: Identifiable {
    let id = UUID()
    let number: Int
    let entry: TranscriptEntry
    let focus: Skill
    let areas: [AreaScore]
}

/// One area in a list: its symbol and name, a bar, and its score out of 100.
struct AreaRow: View {
    let area: AreaScore
    static let symbolWidth: CGFloat = 24

    var body: some View {
        // The symbol, name, score and chevron share the first line, as
        // Settings lines up a row; the bar sits under the name.
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                Image(systemName: area.area.symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.graphic)
                    .frame(width: Self.symbolWidth)
                Text(area.area.title)
                    .foregroundStyle(Color.primary)
                Spacer()
                Text("\(area.score)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Color.primary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            ProgressView(value: Double(area.score), total: 100)
                .tint(AppTheme.graphic)
                .padding(.leading, Self.symbolWidth + AppTheme.Spacing.sm)
                // Ends under the score, not the chevron.
                .padding(.trailing, 20)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(area.area.title), \(area.score) out of 100")
        .accessibilityHint("Shows how it's worked out")
    }
}

/// How one area's score is worked out, in the style of the earlier part
/// sheet: a header with what it measures and the score, then each part with
/// a tick, exclamation mark or cross, what happened, its score and its weight.
struct AreaDetailView: View {
    let area: AreaScore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                HStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: area.area.symbol)
                        .font(.title2)
                        .foregroundStyle(AppTheme.graphic)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(area.area.measures)
                            .foregroundStyle(.secondary)
                        Text("\(Text("\(area.score)").font(.title.bold()).foregroundStyle(Color.primary)) / 100")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .padding(.vertical, AppTheme.Spacing.xxs)
            }

            Section {
                ForEach(area.parts) { part in
                    HStack(spacing: AppTheme.Spacing.sm) {
                        VerdictIcon(score: part.score)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(part.title)
                            Text(part.evidence)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let rule = part.rule {
                                Text(rule)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer(minLength: AppTheme.Spacing.xs)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(part.score)")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                            Text("\(part.weight)%")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("Marked On")
            } footer: {
                Text("Each part is out of 100 and counts for its weight.")
            }
        }
        .navigationTitle(area.area.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

/// Where a score sits: four bands in the ring's colors, labelled, with a
/// marker at the score.
private struct ScoreScale: View {
    let score: Int

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            GeometryReader { proxy in
                let width = proxy.size.width
                let x = width * CGFloat(min(max(score, 0), 100)) / 100
                ZStack(alignment: .leading) {
                    HStack(spacing: 3) {
                        ForEach(Feedback.Band.allCases, id: \.self) { band in
                            Capsule()
                                .fill(ScoreRing.color(for: band.range.lowerBound).opacity(Feedback.Band(score: score) == band ? 1 : 0.3))
                                .frame(width: max(width * CGFloat(band.range.count) / 101 - 2, 0))
                        }
                    }
                    .frame(height: 6)
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(ScoreRing.color(for: score), lineWidth: 3))
                        .offset(x: min(max(x - 7, 0), width - 14))
                }
                .frame(height: 14)
            }
            .frame(height: 14)
            // Where each band starts; the band's name is the heading above.
            GeometryReader { proxy in
                ForEach([0, 40, 80, 90, 100], id: \.self) { mark in
                    Text("\(mark)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .position(x: min(max(proxy.size.width * CGFloat(mark) / 100, 8), proxy.size.width - 10), y: 7)
                }
            }
            .frame(height: 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Feedback.Band(score: score).title), \(score) out of 100")
    }
}

/// Which area for growth is in view: a row of dots, the current one a
/// longer capsule in the accent, as the system page control marks a page.
private struct GrowthDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? AppTheme.graphic : Color(.systemGray4))
                    .frame(width: index == current ? 16 : 6, height: 6)
            }
        }
        .animation(.smooth(duration: 0.3), value: current)
        .padding(.top, AppTheme.Spacing.xxs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Area \(current + 1) of \(count)")
    }
}

private struct InsightLabelStyle: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
            configuration.icon
                .font(.footnote.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 14)
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
                TabHeader()
                content
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            // Same 8pt start as Home, so every tab's first card sits alike.
            .padding(.top, AppTheme.Spacing.xs)
            .padding(.bottom, AppTheme.Spacing.sm)
            // Exactly as wide as the page. Even a fraction of a point wider
            // lets the page drift sideways under a finger.
            .containerRelativeFrame(.horizontal)
        }
        // Up and down only: the page never pans or bounces sideways.
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .debugScrollAnchor()
        .groupedBackground()
        .edgeSwipeBackOnly()
    }
}

/// A past interview, opened from Home or History.
struct RehearsalDetailView: View {
    let rehearsalID: Rehearsal.ID
    @Environment(AppState.self) private var appState

    var body: some View {
        if let rehearsal = appState.rehearsal(id: rehearsalID) {
            ReportScroll {
                FeedbackReport(rehearsal: rehearsal) { skill in
                    improveLink(for: skill, in: rehearsal)
                }
            }
            .scrollingTitle("Your Score", subtitle: rehearsal.title, inList: false)
            .navigationBarTitleDisplayMode(.inline)
        } else {
            ContentUnavailableView("Rehearsal Not Found", systemImage: "questionmark.circle")
        }
    }

    /// The latest interview's focus is the current one, so it goes to
    /// Practice; anything else opens the questions that build it.
    private func improveLink(for skill: Skill, in rehearsal: Rehearsal) -> some View {
        let isCurrentFocus = rehearsal.id == appState.lastInterview?.id && skill == rehearsal.feedback?.focus
        return PrimaryLink(title: "Improve \(skill.title)", route: isCurrentFocus ? .practice : .library(focus: skill))
    }
}

#Preview {
    let state = AppState()
    NavigationStack {
        RehearsalDetailView(rehearsalID: state.rehearsals[1].id)
    }
    .environment(state)
}

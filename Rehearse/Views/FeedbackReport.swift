import SwiftUI

/// The report for one interview, shared by the end of the live interview and
/// History so a result always reads the same way. It's split over two pages:
/// the first is the result (the score, what it means, where it sits on the
/// scale), how it's worked out and what to improve; a row opens the second,
/// every answer.
/// How Scoring Works, from the info button or the Overall row, says what
/// every number is based on. Lay it out in a `ReportScroll`.
struct FeedbackReport<PracticeAction: View>: View {
    let rehearsal: Rehearsal
    /// Which page of the report this is.
    var page: ReportPage = .overview
    /// The button on an area for growth that goes and works on it.
    @ViewBuilder let practiceAction: (Skill) -> PracticeAction

    @Environment(AppState.self) private var appState
    /// The one sheet open over the report. One presenter for all of them,
    /// so a tap always opens its sheet straight away.
    @State private var sheet: ReportSheet?

    private enum ReportSheet: Identifiable {
        case scoring
        case area(AreaScore)
        case answer(OpenQuestion)

        var id: String {
            switch self {
            case .scoring: "scoring"
            case .area(let area): "area-\(area.id)"
            case .answer(let open): "answer-\(open.id)"
            }
        }
    }

    var body: some View {
        if let feedback = rehearsal.feedback {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                switch page {
                case .overview:
                    resultCard(feedback)
                    SectionTitle(title: "Score Breakdown")
                    breakdownCard(feedback)
                    answersLink(feedback)
                    SectionTitle(title: "What to Improve")
                        .padding(.top, AppTheme.Spacing.sm)
                    growthList(feedback)
                    rehearseAgainButton
                case .answers:
                    questionBreakdown(feedback)
                    Text("Tap an answer to see what went well, what to fix, and to ask about it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, AppTheme.Spacing.headingMargin - AppTheme.Spacing.md)
                }
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .scoring:
                    NavigationStack { ScoringInfoView() }
                        .presentationDetents([.large])
                case .area(let area):
                    NavigationStack { AreaDetailView(area: area) }
                        .presentationDetents([.large])
                        // Solid, so the score behind doesn't show through.
                        .presentationBackground(AppTheme.background)
                case .answer(let open):
                    NavigationStack {
                        AnswerReviewView(number: open.number, entry: open.entry, focus: open.focus, areas: open.areas)
                    }
                }
            }
            #if DEBUG
            .task {
                // `-scoring` opens How Scoring Works, `-part N` an area's
                // working, and `-screen answer` the first answer, for
                // screenshots.
                let arguments = ProcessInfo.processInfo.arguments
                try? await Task.sleep(for: .seconds(0.6))
                if arguments.contains("-scoring") { sheet = .scoring }
                if let index = arguments.firstIndex(of: "-part"), arguments.indices.contains(index + 1),
                   let number = Int(arguments[index + 1]), feedback.areas.indices.contains(number) {
                    sheet = .area(feedback.areas[number])
                }
                if appState.debugOpensFirstAnswer, let first = numberedTranscript.first {
                    appState.debugOpensFirstAnswer = false
                    sheet = .answer(OpenQuestion(number: first.number, entry: first.entry, focus: feedback.focus, areas: feedback.areas(for: first.entry)))
                }
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
        VStack(spacing: AppTheme.Spacing.lg) {
            ScoreRing(
                score: feedback.overall,
                caption: "out of 100",
                size: 168,
                delta: (previous?.feedback?.overall).map { feedback.overall - $0 }
            )
                .padding(.top, AppTheme.Spacing.xs)
            VStack(spacing: 2) {
                // The band, with what it means one tap away beside it.
                HStack(spacing: AppTheme.Spacing.xs) {
                    Text(feedback.band.title)
                        .font(.title2.bold())
                    Button {
                        sheet = .scoring
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.title3)
                            .foregroundStyle(AppTheme.brand)
                            .tapTarget()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("How scoring works")
                    .accessibilityHint("Explains what the score means and how it’s worked out")
                }
                // When it took place, under the score it belongs to.
                Group {
                    Text(rehearsal.date.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))
                    if answerCount > 0 {
                        Text("Based on \(answerCount) \(answerCount == 1 ? "answer" : "answers")")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }
            ScoreScale(score: feedback.overall)
        }
        // Straight on the page, not in a card, so the score leads the screen.
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.md)
    }

    // MARK: - The pages

    /// The row that opens the second page, every answer, with a line saying
    /// how many need work.
    private func answersLink(_ feedback: Feedback) -> some View {
        let toImprove = rehearsal.transcript.filter { entry in
            feedback.score(for: entry).map { $0 < 80 } ?? false
        }.count
        return pageLink(.answers, symbol: "text.bubble.fill",
                        detail: "\(answerCount) \(answerCount == 1 ? "answer" : "answers")" + (toImprove > 0 ? ", \(toImprove) to improve" : ""))
            .cardBackground()
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    private func pageLink(_ target: ReportPage, symbol: String, detail: String) -> some View {
        NavigationLink {
            ReportScroll {
                FeedbackReport(rehearsal: rehearsal, page: target, practiceAction: practiceAction)
            }
            .scrollingTitle(target.title, subtitle: rehearsal.title, inList: false)
            .navigationBarTitleDisplayMode(.inline)
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(AppTheme.graphic)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(target.title)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: AppTheme.Spacing.xs)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(CardRowButtonStyle())
    }

    /// Every area to improve, one card each, down the page.
    private func growthList(_ feedback: Feedback) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            ForEach(growthAreas(feedback), id: \.self) { skill in
                growthPage(skill, feedback)
            }
        }
    }

    // MARK: - How it's worked out

    /// Why the score is what it is: the six areas, each out of 100. Tap an
    /// area for the parts it's worked out from.
    @ViewBuilder
    private func breakdownCard(_ feedback: Feedback) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(feedback.areas.enumerated()), id: \.element.id) { index, area in
                if index > 0 { Divider().padding(.leading, 52) }
                Button {
                    sheet = .area(area)
                } label: {
                    AreaRow(area: area)
                }
                .buttonStyle(CardRowButtonStyle())
            }
        }
        .cardBackground()
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
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
    /// showed.
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
            VStack(spacing: 0) {
                ForEach(Array(numberedTranscript.enumerated()), id: \.offset) { index, item in
                    if index > 0 { Divider().padding(.leading, 52) }
                    Button {
                        sheet = .answer(OpenQuestion(number: item.number, entry: item.entry, focus: feedback.focus, areas: feedback.areas(for: item.entry)))
                    } label: {
                        questionRow(number: item.number, entry: item.entry, score: feedback.score(for: item.entry))
                    }
                    .buttonStyle(CardRowButtonStyle())
                }
            }
            .cardBackground()
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
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

    private var numberedTranscript: [(number: Int, entry: TranscriptEntry)] {
        var number = 0
        return rehearsal.transcript.map { entry in
            if !entry.isFollowUp { number += 1 }
            return (max(number, 1), entry)
        }
    }
}

/// The two pages a report is split over.
enum ReportPage {
    case overview, answers

    var title: String {
        switch self {
        case .overview: "Your Score"
        case .answers: "Your Answers"
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

    var body: some View {
        AreaScoreRow(area: area.area, score: area.score)
            .accessibilityHint("Shows how it's worked out")
    }
}

/// One area of the score: symbol, name, score and chevron share the first
/// line, as Settings lines up a row, with the bar under the name. Progress
/// adds the change since the first interview before the score, has no
/// chevron since its rows don't open anything, and draws the symbol larger
/// as a button that says what the area measures.
struct AreaScoreRow: View {
    let area: ScoreArea
    let score: Int
    var delta: Int?
    var showsChevron = true
    var symbolExplains = false
    static let symbolWidth: CGFloat = 24
    @State private var isExplaining = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                if symbolExplains {
                    explainingSymbol
                } else {
                    Image(systemName: area.symbol)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: Self.symbolWidth)
                }
                Text(area.title)
                    .foregroundStyle(Color.primary)
                Spacer()
                if let delta {
                    DeltaText(delta: delta)
                }
                Text("\(score)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Color.primary)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            ProgressView(value: Double(score), total: 100)
                .tint(AppTheme.graphic)
                .padding(.leading, (symbolExplains ? 36 : Self.symbolWidth) + AppTheme.Spacing.sm)
                // Ends under the score, not the chevron.
                .padding(.trailing, showsChevron ? 20 : 0)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: symbolExplains ? .contain : .ignore)
        .accessibilityLabel("\(area.title), \(score) out of 100")
        .accessibilityValue(delta.map { $0 == 0 ? "No change" : $0 > 0 ? "Up \($0)" : "Down \(-$0)" } ?? "")
    }

    /// The symbol in a soft circle; a tap says what the area measures and
    /// how it's scored, without leaving the page.
    private var explainingSymbol: some View {
        Button {
            isExplaining = true
        } label: {
            Image(systemName: area.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.brand)
                .frame(width: 36, height: 36)
                .background(AppTheme.brand.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 6 }
        .accessibilityLabel("What \(area.title) measures")
        .popover(isPresented: $isExplaining) {
            VStack(alignment: .leading, spacing: 4) {
                Text(area.title)
                    .font(.headline)
                Text(area.measures)
                Text(area.method)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 260, alignment: .leading)
            .padding()
            .presentationCompactAdaptation(.popover)
        }
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

/// Where a score sits: four bands in the ring's colors with a marker at
/// the score, and a legend naming each band and its range.
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
            // What each color means: two columns, the score's own band
            // in full strength, the rest dimmed as on the bar.
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 4) {
                ForEach(Feedback.Band.allCases, id: \.self) { band in
                    let isCurrent = Feedback.Band(score: score) == band
                    HStack(spacing: 5) {
                        Circle()
                            .fill(ScoreRing.color(for: band.range.lowerBound))
                            .frame(width: 6, height: 6)
                        Text(band.title)
                            .foregroundStyle(isCurrent ? Color.primary : Color.secondary)
                            .fontWeight(isCurrent ? .semibold : .regular)
                        Text("\(band.range.lowerBound)–\(band.range.upperBound)")
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                    .font(.caption2)
                }
            }
            .padding(.top, AppTheme.Spacing.xs)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Feedback.Band(score: score).title), \(score) out of 100")
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
        // Secondary, so Rehearse Again stays the page's one solid button.
        return NavigationLink(value: isCurrentFocus ? Route.practice : Route.library(focus: skill)) {
            Text("Improve \(skill.title)")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

#Preview {
    let state = AppState()
    NavigationStack {
        RehearsalDetailView(rehearsalID: state.rehearsals[1].id)
    }
    .environment(state)
}

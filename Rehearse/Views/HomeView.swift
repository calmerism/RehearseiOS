import SwiftUI

/// Answers one question: what should I do next? The next interview leads,
/// then sections ordered by the candidate's situation rather than fixed:
/// - New: start a first rehearsal (no empty statistics).
/// - Just finished an interview: practice its weakness first.
/// - Upcoming interview: prepare for that interview.
/// The full report, History and Progress are a tap away; Home stays short.
struct HomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                header
                if appState.isNewUser && appState.upcomingInterviews.isEmpty {
                    getStartedCard
                }
                nextInterviewCard
                statTiles
                if appState.hasFreshFeedback {
                    focusAreas
                }
                upcomingSection
                if !appState.hasFreshFeedback {
                    focusAreas
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.xl)
        }
        .background(WarmBackground())
        .navigationTitle("Rehearse")
        .toolbar(.hidden, for: .navigationBar)
        // Without a navigation bar, nothing else softens content scrolling under the status bar.
        .safeAreaBar(edge: .top, spacing: 0) { Color.clear.frame(height: 0) }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rehearse")
                    .font(.app(.largeTitle, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            }
            Spacer()
            demoMenu
        }
        .padding(.top, AppTheme.Spacing.xs)
        .padding(.bottom, AppTheme.Spacing.xs)
        // Both ends line up with the text inside the cards below.
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: - New candidate

    private var getStartedCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Start with a mock interview")
                .font(.app(.title2, weight: .bold))
            Text("About 15 minutes, out loud. After that you’ll see how it went and the one thing to work on.")
                .font(.app(.subheadline))
                .foregroundStyle(.secondary)
            PrimaryButton(title: "Take a Mock Interview", systemImage: "mic") {
                appState.path.append(.setup(.custom))
            }
            .padding(.top, AppTheme.Spacing.xs)
        }
        .padding(AppTheme.Spacing.md)
        .cardBackground()
    }

    // MARK: - Next interview

    /// The soonest real interview, with the one action that prepares for it.
    @ViewBuilder
    private var nextInterviewCard: some View {
        if let next = appState.nextInterview {
            let score = appState.lastScore(for: next)
            HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text("Next interview")
                        .font(.app(.footnote))
                        .foregroundStyle(.secondary)
                    Text(next.title)
                        .font(.app(.title3, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: AppTheme.Spacing.sm) {
                        if let date = next.date {
                            metaLabel(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)), systemImage: "calendar")
                        }
                        if let countdown = next.countdownText {
                            metaLabel(countdown, systemImage: "clock")
                        }
                    }
                    NavigationLink(value: Route.setup(.upcoming(next.id))) {
                        Text("Rehearse now")
                    }
                    .buttonStyle(PillButtonStyle(isCompact: true))
                    .padding(.top, AppTheme.Spacing.xs)
                }
                Spacer(minLength: 0)
                ScoreRing(score: score, caption: score == nil ? "not yet" : "last score")
            }
            .padding(AppTheme.Spacing.md)
            .cardBackground()
            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: AppTheme.Radius.card))
            .contextMenu {
                Button("Edit", systemImage: "pencil") { edit(next) }
            }
            .accessibilityAction(named: "Edit \(next.title)") { edit(next) }
        }
    }

    private func metaLabel(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.app(.footnote))
        .foregroundStyle(.secondary)
    }

    // MARK: - Stats

    /// Effort, not performance: how much rehearsing and practicing has happened.
    @ViewBuilder
    private var statTiles: some View {
        if !appState.isNewUser {
            HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                NavigationLink(value: Route.history) {
                    statTile(
                        title: "Interviews",
                        systemImage: "person.wave.2",
                        value: "\(appState.interviews.count)",
                        unit: "done",
                        caption: nil
                    )
                }
                .buttonStyle(CardButtonStyle())

                NavigationLink(value: Route.practice(nil)) {
                    statTile(
                        title: "Practice",
                        systemImage: "mic",
                        value: "\(appState.practiceSessions.count)",
                        unit: appState.practiceSessions.count == 1 ? "answer" : "answers",
                        caption: nil
                    )
                }
                .buttonStyle(CardButtonStyle())
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func statTile(title: String, systemImage: String, value: String, unit: String, caption: String?) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack(spacing: AppTheme.Spacing.sm) {
                IconChip(systemImage: systemImage)
                Text(title)
                    .font(.app(.subheadline))
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                BigValue(value: value, unit: unit)
                if let caption {
                    Text(caption)
                        .font(.app(.caption))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardBackground()
        .foregroundStyle(Color.primary)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Focus areas

    /// The weakness from the last interview, as a short list of questions to
    /// practice it on — each starts answering straight away.
    @ViewBuilder
    private var focusAreas: some View {
        if appState.currentFocus != nil {
            let questions = appState.recommendedQuestions()
            SectionTitle(title: "Focus areas", actionTitle: "See all") {
                appState.path.append(.practice(nil))
            }
            ForEach(questions) { question in
                focusRow(question)
            }
        }
    }

    private func focusRow(_ question: Question) -> some View {
        Button {
            appState.activePractice = question
        } label: {
            HStack(spacing: AppTheme.Spacing.md) {
                Thumbnail(systemImage: question.category.symbol)
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(question.text)
                        .font(.app(.subheadline, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                ActionCircle(systemImage: "play.fill")
            }
            .padding(AppTheme.Spacing.sm)
            .cardBackground()
            .foregroundStyle(Color.primary)
        }
        .buttonStyle(CardButtonStyle())
        .accessibilityHint("Answer this question out loud")
    }

    // MARK: - Upcoming interviews

    /// The interviews after the next one, and a way to add more. A long press
    /// on a row offers editing.
    @ViewBuilder
    private var upcomingSection: some View {
        let later = Array(appState.upcomingInterviews.dropFirst())
        if appState.upcomingInterviews.isEmpty {
            if !appState.isNewUser {
                addInterviewCard(detail: "Practice for the actual role, company and date.")
            } else {
                addInterviewCard(detail: nil)
            }
        } else {
            SectionTitle(title: "Upcoming", actionTitle: "Add", actionImage: "plus") {
                appState.interviewEditor = InterviewEditorRequest()
            }
            if later.isEmpty {
                Text("No other interviews yet.")
                    .font(.app(.footnote))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, AppTheme.Spacing.md)
            }
            ForEach(later) { interview in
                upcomingRow(interview)
            }
        }
    }

    private func upcomingRow(_ interview: Interview) -> some View {
        NavigationLink(value: Route.setup(.upcoming(interview.id))) {
            HStack(spacing: AppTheme.Spacing.md) {
                DateTile(date: interview.date)
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(interview.title)
                        .font(.app(.subheadline, weight: .semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(details(for: interview))
                        .font(.app(.caption))
                        .foregroundStyle(.secondary)
                    preparationLabel(for: interview)
                }
                Spacer(minLength: 0)
                ActionCircle(systemImage: "play.fill")
            }
            .padding(AppTheme.Spacing.sm)
            .cardBackground()
            .foregroundStyle(Color.primary)
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(CardButtonStyle())
        .accessibilityHint("Set up a rehearsal for this interview")
        .contextMenu {
            Button("Rehearse This Interview", systemImage: "mic") {
                appState.path.append(.setup(.upcoming(interview.id)))
            }
            Button("Edit", systemImage: "pencil") { edit(interview) }
        }
    }

    /// "Behavioral at 10:30 AM"
    private func details(for interview: Interview) -> String {
        guard let time = interview.date?.formatted(date: .omitted, time: .shortened) else { return interview.type.rawValue }
        return "\(interview.type.rawValue) at \(time)"
    }

    /// Green once rehearsed, so readiness shows at a glance.
    private func preparationLabel(for interview: Interview) -> some View {
        let count = appState.rehearsalCount(for: interview)
        let text = count > 0 ? "Rehearsed \(count == 1 ? "once" : "\(count) times")" : "Not rehearsed yet"
        return Label(text, systemImage: count > 0 ? "checkmark.circle.fill" : "circle.dashed")
            .font(.app(.caption, weight: .medium))
            .foregroundStyle(count > 0 ? AppTheme.success : Color.secondary)
    }

    private func addInterviewCard(detail: String?) -> some View {
        Button {
            appState.interviewEditor = InterviewEditorRequest()
        } label: {
            HStack(spacing: AppTheme.Spacing.md) {
                IconChip(systemImage: "plus", size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add an upcoming interview")
                        .font(.app(.headline))
                    if let detail {
                        Text(detail)
                            .font(.app(.footnote))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(AppTheme.Spacing.md)
            .cardBackground()
            .foregroundStyle(Color.primary)
            .multilineTextAlignment(.leading)
        }
        .buttonStyle(CardButtonStyle())
    }

    private func edit(_ interview: Interview) {
        appState.interviewEditor = InterviewEditorRequest(interview: interview)
    }

    // MARK: - Presenter controls

    /// Not part of the product: lets a presenter switch Home between contexts.
    private var demoMenu: some View {
        Menu {
            Section("Prototype scenario") {
                Button("Returning candidate") { appState.load(.returning) }
                Button("New candidate") { appState.load(.newUser) }
            }
        } label: {
            IconChip(systemImage: "slider.horizontal.3", size: 44)
        }
        .accessibilityLabel("Demo scenarios")
    }
}

/// The small ink disc at the end of an actionable card, like a play button.
struct ActionCircle: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.app(.footnote, weight: .bold))
            .foregroundStyle(AppTheme.onInk)
            .frame(width: 32, height: 32)
            .background(AppTheme.ink, in: Circle())
            .accessibilityHidden(true)
    }
}

/// A square picture-like tile for a list item, as in the reference's
/// exercise thumbnails.
struct Thumbnail: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 22, weight: .light))
            .foregroundStyle(AppTheme.brand)
            .frame(width: 60, height: 60)
            .background(
                LinearGradient(colors: [AppTheme.chip, AppTheme.blush], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: AppTheme.Radius.control + 2)
            )
            .accessibilityHidden(true)
    }
}

extension QuestionCategory {
    var symbol: String {
        switch self {
        case .common: "text.bubble"
        case .behavioral: "person.2"
        case .roleBased: "laptopcomputer"
        }
    }
}

#Preview("Returning") {
    NavigationStack { HomeView() }
        .environment(AppState())
}

#Preview("New") {
    NavigationStack { HomeView() }
        .environment(AppState(scenario: .newUser))
}

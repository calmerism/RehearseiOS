import SwiftUI

/// Acting on feedback. Built around the one focus from the last interview:
/// why it was flagged, the habit to apply, and a few questions that exercise
/// it. After practicing, the next step is to rehearse again and check.
struct PracticeView: View {
    let initialQuestion: Question?
    @Environment(AppState.self) private var appState

    var body: some View {
        ReportScroll {
            if let focus = appState.currentFocus {
                focusCard(focus)
                if let initialQuestion, !recommended.contains(initialQuestion) {
                    SectionTitle(title: "Selected question")
                    questionList([initialQuestion])
                }
                recommendedSection(focus)
                nextStepCard(focus)
            } else {
                noFocusSection
            }
        }
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var recommended: [Question] { appState.recommendedQuestions() }

    // MARK: - Focus

    private func focusCard(_ focus: Skill) -> some View {
        SummaryCard(title: "Working on", systemImage: "bolt", tint: AppTheme.focus) {
            Text(focus.title)
                .font(.app(.title2, weight: .bold))
            Text(focus.advice)
                .fixedSize(horizontal: false, vertical: true)
            if let evidence = appState.lastInterview?.feedback?.focusEvidence {
                Text(evidence)
                    .font(.app(.subheadline))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func recommendedSection(_ focus: Skill) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            SectionTitle(title: "Practice questions")
            VStack(spacing: 0) {
                ForEach(recommended) { question in
                    practiceRow(question)
                    Divider().padding(.leading, AppTheme.Spacing.md)
                }
                NavigationLink(value: Route.library(focus: focus)) {
                    HStack {
                        Text("More questions for \(focus.title.lowercased())")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.app(.footnote, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(AppTheme.Spacing.md)
                }
                .buttonStyle(CardRowButtonStyle())
                .foregroundStyle(AppTheme.brand)
            }
            .cardBackground()
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        }
    }

    /// Practice is only worth it if the next interview shows the change.
    @ViewBuilder
    private func nextStepCard(_ focus: Skill) -> some View {
        let count = appState.practiceCountSinceLastInterview
        if count > 0 {
            NavigationLink(value: Route.setup(appState.nextInterview.map { .upcoming($0.id) } ?? .custom)) {
                SummaryCard(title: "Rehearse again", systemImage: "arrow.clockwise", showsChevron: true) {
                    Text("You’ve practiced \(count == 1 ? "once" : "\(count) times"). A full interview shows whether \(focus.title.lowercased()) has improved.")
                        .font(.app(.subheadline))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .buttonStyle(CardButtonStyle())
        }
    }

    // MARK: - No interview yet

    @ViewBuilder
    private var noFocusSection: some View {
        SummaryCard(title: "Get started", systemImage: "sparkles") {
            Text("Find out what to work on")
                .font(.app(.title3, weight: .bold))
            Text("Do a mock interview first. Afterwards you’ll know the one thing to work on, with questions to practice it.")
                .foregroundStyle(.secondary)
            PrimaryButton(title: "Take a Mock Interview", systemImage: "mic") {
                appState.path.append(.setup(.custom))
            }
            .padding(.top, AppTheme.Spacing.xs)
        }
        if let initialQuestion {
            SectionTitle(title: "Selected question")
            questionList([initialQuestion])
        }
        NavigationLink(value: Route.library(focus: nil)) {
            SummaryCard(title: "Question library", systemImage: "text.book.closed", tint: AppTheme.focus, showsChevron: true) {
                Text("Pick a question and practice answering it.")
                    .font(.app(.subheadline))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(CardButtonStyle())
    }

    // MARK: - Rows

    private func questionList(_ questions: [Question]) -> some View {
        VStack(spacing: 0) {
            ForEach(questions) { practiceRow($0) }
        }
        .cardBackground()
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
    }

    private func practiceRow(_ question: Question) -> some View {
        Button {
            appState.activePractice = question
        } label: {
            HStack {
                QuestionRow(question: question)
                Spacer(minLength: AppTheme.Spacing.xs)
                if practicedSinceLastInterview(question) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.success)
                        .accessibilityLabel("Practiced")
                } else {
                    Image(systemName: "mic")
                        .foregroundStyle(AppTheme.brand)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .multilineTextAlignment(.leading)
        }
        .buttonStyle(CardRowButtonStyle())
        .accessibilityHint("Answer this question out loud")
    }

    private func practicedSinceLastInterview(_ question: Question) -> Bool {
        guard let last = appState.lastInterview else { return false }
        return appState.practiceHistory(for: question).contains { $0.date > last.date }
    }
}

/// Answering one question out loud, presented full screen. The habit being
/// practiced stays visible while answering, and the response says whether it
/// showed up.
struct PracticeSessionView: View {
    let question: Question
    let focus: Skill?

    @Environment(AppState.self) private var appState
    @State private var answerState: AnswerState = .ready
    @State private var notice: String?
    @State private var result: String?
    @State private var isSaved = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    // Same card as the interview: who's asking (here, the habit
                    // being practiced), then the question.
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        if let focus {
                            HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                                IconChip(systemImage: "bolt", tint: AppTheme.brand)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Practicing \(focus.title)")
                                        .font(.app(.subheadline, weight: .semibold))
                                    Text(focus.advice)
                                        .font(.app(.footnote))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                        Text(question.text)
                            .font(AppTheme.question(.title))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                    }
                    .padding(AppTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardBackground()

                    if let notice {
                        Label(notice, systemImage: "exclamationmark.circle")
                            .font(.app(.subheadline))
                            .foregroundStyle(.secondary)
                    }

                    if let result {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Label("How that went", systemImage: "waveform")
                                .font(.app(.headline))
                            Text(result)
                        }
                        .padding(AppTheme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardBackground(cornerRadius: AppTheme.Radius.control)
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.xl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .animation(.easeInOut(duration: 0.25), value: result)
            .safeAreaBar(edge: .bottom) {
                if result == nil {
                    RecordingControl(state: answerState, action: toggleRecording)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.lg)
                } else {
                    BottomActions {
                        PrimaryButton(title: "Done") { appState.activePractice = nil }
                        SecondaryButton(title: "Try Again") {
                            result = nil
                            answerState = .ready
                        }
                    }
                }
            }
            .warmBackground()
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { appState.activePractice = nil }
                }
            }
        }
    }

    /// Mirrors the interview: too-short answers aren't captured, and a short
    /// wait stands in for evaluation.
    private func toggleRecording() {
        switch answerState {
        case .ready:
            notice = nil
            answerState = .recording(startedAt: .now)
        case .recording(let startedAt):
            guard Date.now.timeIntervalSince(startedAt) >= 2 else {
                notice = "That was too short to catch. Tap when you’re ready and answer out loud."
                answerState = .ready
                return
            }
            answerState = .processing
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                guard answerState == .processing else { return }
                answerState = .captured
                result = MockFeedbackService.practiceNote(for: focus)
                // One practice session counts once, however many attempts.
                if !isSaved {
                    appState.savePractice(question, focus: focus)
                    isSaved = true
                }
            }
        default:
            break
        }
    }
}

#Preview("Practice") {
    NavigationStack { PracticeView(initialQuestion: nil) }
        .environment(AppState())
}

#Preview("Session") {
    PracticeSessionView(question: MockData.questions[0], focus: .answerStructure)
        .environment(AppState())
}

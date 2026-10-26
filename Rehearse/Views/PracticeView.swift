import SwiftUI

/// Acting on feedback. Built around the one focus from the last interview:
/// a recommended question first, then more questions that exercise it.
struct PracticeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ReportScroll {
            if let focus = appState.currentFocus {
                recommendedSection(focus)
            } else {
                noFocusSection
            }
        }
        .screenTitle("Practice", inList: false)
    }

    private var recommended: [Question] { appState.recommendedQuestions() }

    // MARK: - Recommended

    @ViewBuilder
    private func recommendedSection(_ focus: Skill) -> some View {
        if let featured = recommended.first {
            featuredCard(featured, focus: focus)
        }
        let more = recommended.dropFirst()
        VStack(spacing: 0) {
            ForEach(Array(more.enumerated()), id: \.element.id) { index, question in
                practiceRow(question)
                // Between questions it starts under the text, past the circle,
                // as in Reminders; above More Questions, at that row's edge.
                let isLast = index == more.count - 1
                Divider().padding(.leading, AppTheme.Spacing.md + (isLast ? 0 : Self.circleWidth + AppTheme.Spacing.sm))
            }
            NavigationLink(value: Route.library(focus: focus)) {
                HStack {
                    Text("More Questions")
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
        .cardBackground()
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    /// The one question to answer first, with why it was picked and the habit
    /// to apply while answering.
    private func featuredCard(_ question: Question, focus: Skill) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(question.metaText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(question.text)
                    .font(.questionInCard)
                    .fixedSize(horizontal: false, vertical: true)
                // Why it was picked, in one line of the card's own voice.
                Text(focus.recommendationReason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryButton(title: "Answer Out Loud", systemImage: "mic.fill") {
                appState.activePractice = question
            }
        }
        .padding(AppTheme.Spacing.md)
        .cardBackground()
    }

    // MARK: - No interview yet

    @ViewBuilder
    private var noFocusSection: some View {
        SummaryCard(title: "Get Started") {
            Text("See what to work on")
                .cardTitleStyle()
            Text("Do one mock interview and you’ll get one thing to work on, with questions to practice it.")
                .foregroundStyle(.secondary)
            PrimaryButton(title: "Take a Mock Interview") {
                appState.setUpInterview(.custom)
            }
            .padding(.top, AppTheme.Spacing.xs)
        }
        NavigationLink(value: Route.library(focus: nil)) {
            // A row, not a card with a header: the name is the thing to tap.
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Library")
                        .font(.headline)
                    Text("Pick any question and answer it out loud.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: AppTheme.Spacing.xs)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(AppTheme.Spacing.md)
            .cardBackground()
            .foregroundStyle(Color.primary)
            .multilineTextAlignment(.leading)
        }
        .buttonStyle(CardButtonStyle())
    }

    // MARK: - Rows

    /// The checklist circle's column, so dividers can start past it.
    private static let circleWidth: CGFloat = 24

    private func practiceRow(_ question: Question) -> some View {
        Button {
            appState.activePractice = question
        } label: {
            // A checklist, as Reminders draws one: an empty circle until the
            // question is practiced, then a filled green one. The circle sits
            // on the question's first line; the whole row starts practice.
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                let isPracticed = practicedSinceLastInterview(question)
                Image(systemName: isPracticed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isPracticed ? AppTheme.practiced : Color(.tertiaryLabel))
                    .frame(width: Self.circleWidth)
                    .accessibilityLabel(isPracticed ? "Practiced" : "Not practiced")
                QuestionRow(question: question, font: .headline, endsWithPeriod: true)
                Spacer(minLength: 0)
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
    /// What was heard, shown back so the candidate can check it.
    @State private var heard: SpokenAnswer?
    @State private var isTranscribing = true
    @State private var recorder = AnswerRecorder()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    // Same card as the interview: who's asking (here, the habit
                    // being practiced), then the question.
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        if let focus {
                            Text(focus.title)
                                // The same quiet line as above every other question.
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(question.text)
                            .font(.questionLarge)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        if let focus {
                            Divider()
                            TipRow(text: focus.advice)
                        }
                    }
                    .padding(AppTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardBackground()

                    if let notice {
                        Label(notice, systemImage: "exclamationmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let result {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Label("How that went", systemImage: "waveform")
                                .font(.headline)
                            Text(result)
                            if let heard {
                                Divider()
                                    .padding(.vertical, AppTheme.Spacing.xxs)
                                Text(Self.summary(of: heard.measurements))
                                    .font(.subheadline.weight(.semibold))
                                Text("“\(heard.text)”")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(6)
                            }
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
                    AnswerButton(state: answerState, action: toggleRecording)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Spacing.md)
                } else {
                    BottomActions {
                        PrimaryButton(title: "Done") { appState.activePractice = nil }
                        SecondaryButton(title: "Try Again") {
                            result = nil
                            heard = nil
                            answerState = .ready
                        }
                    }
                }
            }
            .groupedBackground()
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { appState.activePractice = nil }
                }
            }
        }
        .onDisappear { recorder.cancel() }
    }

    /// "142 words a minute, 2 filler words, 1 long pause", from what was measured.
    private static func summary(of measured: Measurements) -> String {
        var parts: [String] = []
        if let pace = measured.wordsPerMinute { parts.append("\(pace) words a minute") }
        if Scoring.flagsFillerWords, let fillers = measured.fillerWords { parts.append(fillers == 1 ? "1 filler word" : "\(fillers) filler words") }
        if let pauses = measured.longPauses, pauses > 0 { parts.append(pauses == 1 ? "1 long pause" : "\(pauses) long pauses") }
        return parts.isEmpty ? "Answer heard" : parts.joined(separator: ", ").prefix(1).uppercased() + parts.joined(separator: ", ").dropFirst()
    }

    /// Mirrors the interview: too-short answers aren't captured, and a short
    /// wait stands in for evaluation.
    private func toggleRecording() {
        switch answerState {
        case .ready:
            notice = nil
            // The clock starts once the microphone is listening.
            answerState = .processing
            Task {
                do {
                    try await recorder.start()
                    isTranscribing = true
                    answerState = .recording(startedAt: .now)
                } catch AnswerRecorder.Failure.unavailable {
                    // Practice still works without speech recognition; the
                    // answer just isn't written down.
                    isTranscribing = false
                    notice = "Speech recognition isn’t available, so this answer won’t be transcribed."
                    answerState = .recording(startedAt: .now)
                } catch {
                    notice = error.localizedDescription
                    answerState = .ready
                }
            }
        case .recording(let startedAt):
            guard Date.now.timeIntervalSince(startedAt) >= 2 else {
                recorder.cancel()
                notice = "That was too short to catch. Tap when you’re ready and answer out loud."
                answerState = .ready
                return
            }
            answerState = .processing
            Task {
                // A failed or empty transcription still finishes the attempt.
                let spoken = isTranscribing ? try? await recorder.stop() : nil
                guard answerState == .processing else { return }
                notice = spoken == nil ? "We couldn’t transcribe that answer, so there’s no transcript this time." : nil
                heard = spoken
                answerState = .captured
                result = MockFeedbackService.practiceNote(for: focus)
                // One practice session counts once, however many attempts.
                if !isSaved {
                    appState.savePractice(question, focus: focus, answer: spoken)
                    isSaved = true
                }
            }
        default:
            break
        }
    }
}

#Preview("Practice") {
    NavigationStack { PracticeView() }
        .environment(AppState())
}

#Preview("Session") {
    PracticeSessionView(question: MockData.questions[0], focus: .answerStructure)
        .environment(AppState())
}

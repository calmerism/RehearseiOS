import SwiftUI

/// The rehearsal itself, presented full screen. One question at a time, one
/// control to answer it. A follow-up keeps the previous answer on screen so it
/// reads as a response to what was said. When the interview ends it is saved,
/// and its feedback opens in place with the next step: practice the weakness.
struct LiveInterviewView: View {
    let session: InterviewSession

    @Environment(AppState.self) private var appState
    @State private var service: MockInterviewService
    @State private var stage: Stage = .interviewing
    @State private var isConfirmingEnd = false
    @State private var startedAt = Date.now
    /// While the question is still being said, the interviewer is "asking".
    @State private var isAsking = true
    /// Bumped to have the interviewer say the question again.
    @State private var replay = 0
    /// The candidate's own camera, in the corner of the call.

    private enum Stage: Equatable {
        case interviewing
        /// Stands in for evaluation latency, so the wait is designed for.
        case preparingFeedback
        case feedback(Rehearsal.ID)
    }

    init(session: InterviewSession) {
        self.session = session
        _service = State(initialValue: MockInterviewService(interview: session.interview, resume: session.resume))
    }

    var body: some View {
        NavigationStack {
            switch stage {
            case .interviewing:
                interviewing
            case .preparingFeedback:
                ProgressView("Preparing your feedback…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .groupedBackground()
                    .navigationTitle(session.interview.title)
                    .navigationBarTitleDisplayMode(.inline)
            case .feedback(let id):
                feedback(id)
            }
        }
        .onChange(of: service.phase) { _, phase in
            if phase == .finished { finish() }
        }
        .onDisappear { service.cancelRecording() }
        .sensoryFeedback(.success, trigger: stage) { _, new in
            if case .feedback = new { true } else { false }
        }
    }

    // MARK: - Interviewing

    private var interviewing: some View {
        // Everything on one screen, no scrolling: the question and controls
        // take what they need and the call fills the rest.
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            InterviewerVideo(mood: mood)
                // The candidate sees themselves too, as in a video call.
                .overlay(alignment: .bottomTrailing) {
                    SelfViewTile(isTalking: mood == .listening, isCameraOn: true)
                        .padding(AppTheme.Spacing.sm)
                }
                .frame(minHeight: 180, maxHeight: 440)
                .layoutPriority(0)
            if let question = service.currentQuestion {
                // The question alone, large: it's the one thing to read.
                RevealingQuestion(text: question, font: .system(size: 28, weight: .semibold).leading(.tight), replay: replay) { isAsking = false }
                    .tracking(-0.4)
                    .minimumScaleFactor(0.75)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, AppTheme.Spacing.xs)
                    .padding(.top, AppTheme.Spacing.xs)
                .layoutPriority(1)
                .id(question)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            Spacer(minLength: AppTheme.Spacing.sm)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.sm)
        .padding(.bottom, AppTheme.Spacing.xs)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.smooth(duration: 0.35), value: service.currentQuestion)
        .onChange(of: service.currentQuestion) { isAsking = true }
        .safeAreaBar(edge: .bottom) {
            AnswerButton(state: answerState, action: toggleRecording)
                .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.md)
            .animation(.smooth(duration: 0.25), value: service.phase)
        }
        .groupedBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // The bar holds only the call itself: how long it has run, in
            // the middle where a title would be, and End on the right. The
            // role was chosen on the screen before, so it isn't repeated.
            // No question count: as in a real interview, you don't know how
            // many are coming.
            ToolbarItem(placement: .principal) {
                Text(startedAt, style: .timer)
                    .font(.headline.monospacedDigit())
                    .accessibilityLabel("Elapsed time")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("End", role: .destructive) { isConfirmingEnd = true }
                    .tint(AppTheme.record)
                    .accessibilityLabel("End interview")
            }
        }
        .sheet(isPresented: $isConfirmingEnd) {
            EndInterviewSheet(
                answered: service.answeredTurns.count,
                total: service.turns.count,
                isAnswering: answerState != .ready && answerState != .captured,
                getFeedback: {
                    isConfirmingEnd = false
                    finish()
                },
                leave: {
                    isConfirmingEnd = false
                    appState.closeInterview()
                }
            )
        }
    }

    private var mood: InterviewerMood {
        switch service.phase {
        case .ready: isAsking ? .asking : .waiting
        case .recording: .listening
        case .processing: .thinking
        case .captured, .finished: .done
        }
    }

    private var answerState: AnswerState {
        switch service.phase {
        case .ready: .ready
        case .recording(let startedAt): .recording(startedAt: startedAt)
        case .processing: .processing
        case .captured, .finished: .captured
        }
    }

    private func toggleRecording() {
        switch service.phase {
        case .ready: service.startRecording()
        case .recording: Task { await service.stopRecording() }
        default: break
        }
    }

    // MARK: - Finishing

    private func finish() {
        guard stage == .interviewing else { return }
        stage = .preparingFeedback
        let rehearsal = appState.saveInterview(service, usedResume: session.resume != nil)
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            stage = .feedback(rehearsal.id)
        }
    }

    @ViewBuilder
    private func feedback(_ id: Rehearsal.ID) -> some View {
        if let rehearsal = appState.rehearsal(id: id) {
            ReportScroll {
                FeedbackReport(rehearsal: rehearsal) { skill in
                    // Secondary, so Rehearse Again stays the page's one
                    // solid button.
                    SecondaryButton(title: "Improve \(skill.title)") {
                        if skill == rehearsal.feedback?.focus {
                            appState.closeInterviewAndPractice()
                        } else {
                            appState.closeInterview(showing: .library(focus: skill))
                        }
                    }
                }
            }
            .scrollingTitle("Your Score", subtitle: rehearsal.title, inList: false)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { appState.closeInterview() }
                }
            }
        }
    }
}

/// Where the answer goes while it's being given: a prompt before, a live
/// waveform while recording, and a spinner while it's analyzed.
/// The answer control, as Voice Memos records: a round button in a ring.
/// Ready, an orange disc with a mic; recording, it shrinks to a red square
/// to stop, the ring pulsing; then a spinner while it's checked and a check
/// once it's in. A short line under it says what a tap does.
struct AnswerButton: View {
    let state: AnswerState
    let action: () -> Void
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .strokeBorder(isRecording ? AppTheme.record.opacity(0.35) : Color(.systemGray4), lineWidth: 4)
                        .frame(width: 80, height: 80)
                        .scaleEffect(isRecording && pulse && !reduceMotion ? 1.08 : 1)
                    switch state {
                    case .ready, .recording:
                        RoundedRectangle(cornerRadius: isRecording ? 8 : 32, style: .continuous)
                            .fill(isRecording ? AppTheme.record : AppTheme.buttonFill)
                            .frame(width: isRecording ? 30 : 64, height: isRecording ? 30 : 64)
                            .overlay {
                                if !isRecording {
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .transition(.opacity)
                                }
                            }
                    case .processing:
                        ProgressView()
                            .controlSize(.large)
                    case .captured:
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.white, AppTheme.practiced)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 88, height: 88)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(state == .processing || state == .captured)
            .sensoryFeedback(.impact(weight: .medium), trigger: isRecording)
            .accessibilityLabel(accessibilityLabel)

            caption
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isRecording ? AppTheme.record : Color.secondary)
                .contentTransition(.opacity)
        }
        .animation(.spring(duration: 0.35, bounce: 0.2), value: state)
        .onChange(of: isRecording) { _, recording in
            if recording {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true }
            } else {
                pulse = false
            }
        }
    }

    @ViewBuilder
    private var caption: some View {
        switch state {
        case .ready: Text("Tap to answer")
        case .recording(let since): Text("\(Text(since, style: .timer).monospacedDigit())  Tap to finish")
        case .processing: Text("Checking")
        case .captured: Text("Got it")
        }
    }

    private var accessibilityLabel: String {
        switch state {
        case .ready: "Answer"
        case .recording: "Finish answering"
        case .processing: "Checking your answer"
        case .captured: "Answer received"
        }
    }
}

#Preview {
    LiveInterviewView(session: InterviewSession(interview: MockData.upcomingInterview, resume: MockData.resume))
        .environment(AppState())
}

/// Ending before the last question: what each choice means before it's
/// made. Get Feedback scores what was answered; leaving keeps nothing.
/// Feedback can only be asked for once, since `finish` runs once.
private struct EndInterviewSheet: View {
    let answered: Int
    let total: Int
    /// An answer is being recorded or checked right now.
    let isAnswering: Bool
    let getFeedback: () -> Void
    let leave: () -> Void
    @Environment(\.dismiss) private var dismiss
    /// The height of what the sheet says; the sheet is exactly that tall.
    @State private var contentHeight: CGFloat = 300

    private var skipped: Int { max(total - answered, 0) }
    private var hasAnswers: Bool { answered > 0 }

    var body: some View {
        // Top to bottom: the close button on its own row, the question,
        // what each choice means (once there's something to lose), then
        // the choices. The same margin above and below.
        VStack(spacing: AppTheme.Spacing.lg) {
            closeRow
            heading
            if hasAnswers { outcomes }
            actions
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        // The close button as far from the top edge as from the right.
        .padding(.top, AppTheme.Spacing.lg + AppTheme.Spacing.xs)
        // iOS adds the home indicator's strip below, which reads as the
        // bottom margin, so nothing more here.
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(contentHeight)])
        .presentationBackground(Color(.systemGroupedBackground))
    }

    /// Back to the interview, as a sheet closes.
    private var closeRow: some View {
        HStack {
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Keep going")
        }
        // The row only holds the button; the heading starts close below.
        .padding(.bottom, -AppTheme.Spacing.md)
    }

    private var heading: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            Text(hasAnswers ? "End the interview?" : "Leave this interview?")
                .font(.title2.bold())
            Text(hasAnswers
                 ? "You’ve answered \(answered) \(answered == 1 ? "question" : "questions") so far."
                 : "You haven’t answered a question yet, so there’s nothing to give feedback on.")
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    /// What each choice does, as a Settings list reads: a short lead per
    /// row, the detail in gray beneath, hairlines between.
    private var outcomes: some View {
        VStack(alignment: .leading, spacing: 0) {
            outcome("checkmark.circle.fill", AppTheme.success, "Get Feedback",
                    "Scores the answers you gave" + (skipped > 0 ? ". Each question you didn’t get to takes 3 points off." : "."))
            Divider().padding(.leading, 52)
            outcome("xmark.circle.fill", AppTheme.record, "Leave Without Feedback",
                    "Your answers aren’t saved.")
            if isAnswering {
                Divider().padding(.leading, 52)
                outcome("exclamationmark.circle.fill", .orange, "Answer in Progress",
                        "The answer you’re giving now won’t be counted.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
    }

    @ViewBuilder
    private var actions: some View {
        if hasAnswers {
            VStack(spacing: AppTheme.Spacing.xs) {
                PrimaryButton(title: "Get Feedback", systemImage: "text.bubble.fill", action: getFeedback)
                Button("Leave Without Feedback", role: .destructive, action: leave)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        } else {
            // The one thing to do here, so a full button, in red.
            Button(role: .destructive, action: leave) {
                Text("Leave Interview")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(AppTheme.record)
        }
    }

    private func outcome(_ symbol: String, _ tint: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .accessibilityElement(children: .combine)
    }
}

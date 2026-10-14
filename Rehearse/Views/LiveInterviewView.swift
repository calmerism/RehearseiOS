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
    @State private var isCameraOn = true

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
                    SelfViewTile(isTalking: mood == .listening, isCameraOn: isCameraOn)
                        .padding(AppTheme.Spacing.sm)
                }
                .frame(minHeight: 180, maxHeight: 380)
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
        .safeAreaInset(edge: .top, spacing: 0) {
            // A segment a question, and the time, in one quiet line.
            HStack(spacing: AppTheme.Spacing.sm) {
                QuestionSegments(service: service)
                Text(startedAt, style: .timer)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Elapsed time")
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.xs)
        }
        .safeAreaBar(edge: .bottom) {
            AnswerButton(state: answerState, action: toggleRecording)
                .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.md)
            .animation(.smooth(duration: 0.25), value: service.phase)
        }
        .groupedBackground()
        .navigationTitle(questionTitle)
        .navigationSubtitle(session.interview.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("End", role: .destructive) { isConfirmingEnd = true }
                    .tint(AppTheme.record)
                    .accessibilityLabel("End interview")
            }
            ToolbarItem(placement: .primaryAction) {
                Button(isCameraOn ? "Turn Camera Off" : "Turn Camera On", systemImage: isCameraOn ? "video.fill" : "video.slash.fill") {
                    isCameraOn.toggle()
                }
            }
        }
        .confirmationDialog(endTitle, isPresented: $isConfirmingEnd, titleVisibility: .visible) {
            if service.answeredTurns.isEmpty {
                Button("Leave Interview", role: .destructive) { appState.closeInterview() }
            } else {
                Button("End and Get Feedback") { finish() }
                Button("Discard Interview", role: .destructive) { appState.closeInterview() }
            }
            Button("Keep Going", role: .cancel) {}
        } message: {
            if !service.answeredTurns.isEmpty {
                Text("You’ll get feedback on the \(service.answeredTurns.count) of \(service.turns.count) topics you answered.")
            }
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

    /// "Question 3 of 5"; follow-ups stay on their topic's number.
    private var questionTitle: String {
        let total = service.turns.count
        return "Question \(min(service.turnIndex + 1, total)) of \(total)"
    }

    private var endTitle: String {
        service.answeredTurns.isEmpty ? "Leave this interview?" : "End the interview early?"
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
                    PrimaryButton(title: "Improve \(skill.title)") {
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
                        Image(systemName: "checkmark")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(AppTheme.success)
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

/// One segment a question: answered in the accent, the current one filling
/// in, skipped ones hollow, the rest still to come.
private struct QuestionSegments: View {
    let service: MockInterviewService

    var body: some View {
        HStack(spacing: 4) {
            ForEach(service.turns.indices, id: \.self) { index in
                let status = service.status(ofTurn: index)
                Capsule()
                    .fill(color(for: status))
                    .overlay {
                        if status == .skipped {
                            Capsule().strokeBorder(AppTheme.graphic, lineWidth: 1)
                        }
                    }
                    .frame(height: 4)
            }
        }
        .animation(.smooth(duration: 0.3), value: service.turnIndex)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Question \(min(service.turnIndex + 1, service.turns.count)) of \(service.turns.count)")
    }

    private func color(for status: MockInterviewService.TurnStatus) -> Color {
        switch status {
        case .answered: AppTheme.graphic
        case .current: AppTheme.graphic.opacity(0.45)
        case .skipped: .clear
        case .upcoming: AppTheme.track
        }
    }
}

#Preview {
    LiveInterviewView(session: InterviewSession(interview: MockData.upcomingInterview, resume: MockData.resume))
        .environment(AppState())
}

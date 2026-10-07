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
                    .warmBackground()
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
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                if let question = service.currentQuestion {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                        questionContext
                        Text(question)
                            .font(AppTheme.question(.title))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                    }
                    .padding(AppTheme.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardBackground()

                    HStack(spacing: AppTheme.Spacing.sm) {
                        statTile(label: "Elapsed") {
                            Text(startedAt, style: .timer)
                        }
                        statTile(label: "Answered") {
                            Text("\(service.answeredTurns.count)/\(service.turns.count)")
                        }
                    }

                    // The habit to keep in mind, like a step card.
                    if let focus = appState.currentFocus {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text("Tip")
                                .font(.app(.caption))
                                .foregroundStyle(.secondary)
                            Text(focus.advice)
                                .font(.app(.subheadline, weight: .medium))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(AppTheme.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardBackground()
                        .accessibilityElement(children: .combine)
                    }
                }
                if let notice = service.notice {
                    Label(notice, systemImage: "exclamationmark.circle")
                        .font(.app(.subheadline))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.top, AppTheme.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(service.currentQuestion)
            .transition(.opacity)
        }
        .animation(.easeInOut(duration: 0.25), value: service.currentQuestion)
        .safeAreaInset(edge: .top, spacing: 0) {
            SegmentedProgress(
                total: service.turns.count,
                completed: service.phase == .finished ? service.turns.count : service.turnIndex
            )
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.xs)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Interview progress")
            .accessibilityValue(service.progressDescription)
        }
        .safeAreaBar(edge: .bottom) {
            RecordingControl(state: answerState, action: toggleRecording)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.lg)
        }
        .warmBackground()
        .navigationTitle(session.interview.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("End", systemImage: "xmark") { isConfirmingEnd = true }
                    .accessibilityLabel("End interview")
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

    private func statTile(label: String, @ViewBuilder value: () -> Text) -> some View {
        VStack(spacing: AppTheme.Spacing.xxs) {
            value()
                .font(.app(.title, weight: .bold).monospacedDigit())
                .foregroundStyle(.primary)
            Text(label)
                .font(.app(.caption))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.lg)
        .cardBackground()
        .accessibilityElement(children: .combine)
    }

    private var endTitle: String {
        service.answeredTurns.isEmpty ? "Leave this interview?" : "End the interview early?"
    }

    /// Where the question comes from: a follow-up to what was just said, the
    /// candidate's resume, or neither.
    @ViewBuilder
    private var questionContext: some View {
        if service.isFollowUp {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Label("Follow-up", systemImage: "arrowshape.turn.up.left")
                    .font(.app(.subheadline, weight: .semibold))
                    .foregroundStyle(AppTheme.brand)
                if let previous = service.previousAnswer {
                    Text("“\(previous)”")
                        .font(.app(.subheadline))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .padding(.leading, AppTheme.Spacing.sm)
                        .overlay(alignment: .leading) {
                            Capsule().fill(AppTheme.brand.opacity(0.5)).frame(width: 3)
                        }
                        .accessibilityLabel("You said: \(previous)")
                }
            }
        } else if let origin = service.currentTurn?.origin {
            Label(origin, systemImage: "doc.text")
                .font(.app(.subheadline, weight: .semibold))
                .foregroundStyle(.secondary)
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
                FeedbackReport(rehearsal: rehearsal) {
                    PrimaryButton(title: "Practice this now", systemImage: "mic") {
                        appState.closeInterviewAndPractice(nil)
                    }
                }
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { appState.closeInterview() }
                }
            }
        }
    }
}

#Preview {
    LiveInterviewView(session: InterviewSession(interview: MockData.upcomingInterview, resume: MockData.resume))
        .environment(AppState())
}

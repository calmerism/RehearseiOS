import Foundation
import Observation

/// Runs one live mock interview. It stands in for the future interviewer: it
/// picks predefined questions for the interview context, "captures" an answer,
/// and decides whether to follow up or move on. No audio is recorded.
@Observable
final class MockInterviewService {
    enum Phase: Equatable {
        /// The question is on screen; the candidate can start answering.
        case ready
        case recording(startedAt: Date)
        /// The answer was submitted and is being "analyzed".
        case processing
        /// The answer was captured; the interviewer is about to respond.
        case captured
        /// Every topic has been covered.
        case finished
    }

    let interview: Interview
    let turns: [InterviewTurn]
    let startedAt = Date.now

    private(set) var phase: Phase = .ready
    private(set) var turnIndex = 0
    private(set) var isFollowUp = false
    private(set) var transcript: [TranscriptEntry] = []
    /// Shown when an answer couldn't be captured, e.g. it was too short.
    private(set) var notice: String?
    /// Main questions answered, and ones skipped, by turn.
    private(set) var answeredTurnIDs: [String] = []
    private(set) var skippedTurnIDs: [String] = []

    /// Hears each answer and measures how it was said.
    private let recorder = AnswerRecorder()
    private var isStartingRecording = false

    /// Answers shorter than this are treated as a failed recording.
    private let minimumAnswerSeconds: TimeInterval = 2

    init(interview: Interview, resume: ResumeContext?) {
        self.interview = interview
        self.turns = Self.plan(for: interview, resume: resume)
    }

    var currentTurn: InterviewTurn? {
        turns.indices.contains(turnIndex) ? turns[turnIndex] : nil
    }

    var currentQuestion: String? {
        guard let turn = currentTurn else { return nil }
        return isFollowUp ? turn.followUp?.question : turn.question
    }

    /// The candidate's previous answer, kept on screen so a follow-up reads as a
    /// response to it rather than a new, unrelated question.
    var previousAnswer: String? {
        guard isFollowUp else { return nil }
        return transcript.last?.answer
    }

    /// Main topics the candidate has answered (follow-ups don't count);
    /// skipped ones aren't among them, so they aren't scored.
    var answeredTurns: [InterviewTurn] {
        turns.filter { answeredTurnIDs.contains($0.id) }
    }

    /// Where a question stands, for the list of questions.
    enum TurnStatus { case answered, skipped, current, upcoming }

    func status(ofTurn index: Int) -> TurnStatus {
        let id = turns[index].id
        if answeredTurnIDs.contains(id) && index != turnIndex { return .answered }
        if skippedTurnIDs.contains(id) { return .skipped }
        if index == turnIndex && phase != .finished { return .current }
        return index < turnIndex ? .answered : .upcoming
    }


    var progress: Double {
        guard !turns.isEmpty else { return 0 }
        return Double(min(turnIndex, turns.count)) / Double(turns.count)
    }

    /// Approximate position, deliberately not a question count.
    var progressDescription: String {
        switch progress {
        case 1...: "Interview complete"
        case 0.75...: "Last topic"
        case 0.4...: "About halfway"
        case 0.01...: "Getting going"
        default: "Just started"
        }
    }

    // MARK: - Answering

    func startRecording() {
        guard phase == .ready, !isStartingRecording else { return }
        notice = nil
        isStartingRecording = true
        // The clock starts once the microphone is listening, not while a
        // permission prompt is up.
        Task {
            defer { isStartingRecording = false }
            do {
                try await recorder.start()
                guard phase == .ready else { recorder.cancel(); return }
                phase = .recording(startedAt: .now)
            } catch {
                notice = error.localizedDescription
            }
        }
    }

    /// Stops listening without keeping anything, as when the interview closes.
    func cancelRecording() {
        recorder.cancel()
    }

    func stopRecording() async {
        guard case .recording(let startedAt) = phase, let turn = currentTurn else { return }

        guard Date.now.timeIntervalSince(startedAt) >= minimumAnswerSeconds else {
            recorder.cancel()
            notice = "That was too short to catch. Tap when you’re ready and answer out loud."
            phase = .ready
            return
        }

        phase = .processing
        let spoken: SpokenAnswer?
        do {
            spoken = try await recorder.stop()
        } catch {
            notice = error.localizedDescription
            phase = .ready
            return
        }
        guard phase == .processing else { return }
        guard let spoken else {
            notice = "We didn’t catch that. Check your microphone and answer out loud."
            phase = .ready
            return
        }

        if !isFollowUp { answeredTurnIDs.append(turn.id) }
        transcript.append(TranscriptEntry(
            question: currentQuestion ?? "",
            answer: spoken.text,
            isFollowUp: isFollowUp,
            // Still the prepared evaluation until answers are judged.
            moment: isFollowUp ? nil : turn.moment,
            measurements: spoken.measurements
        ))
        phase = .captured

        try? await Task.sleep(for: .seconds(1.8))
        guard phase == .captured else { return }
        advance()
    }

    private func advance() {
        if !isFollowUp, currentTurn?.followUp != nil {
            isFollowUp = true
        } else {
            isFollowUp = false
            turnIndex += 1
        }
        phase = turnIndex < turns.count ? .ready : .finished
    }

    // MARK: - Planning

    /// Stands in for interview generation. Role picks the role-specific
    /// question, interview type picks the topic set, the resume swaps generic
    /// questions for ones about the candidate's own work, company adds a short
    /// motivation question, and duration sets how many topics fit.
    static func plan(for interview: Interview, resume: ResumeContext?) -> [InterviewTurn] {
        // A tailored resume puts its lead project first, so the interview does too.
        let projectTurns: [InterviewTurn] = (resume?.highlights ?? []).compactMap { highlight in
            switch highlight.id {
            case "finlo": MockData.financePaymentsTurn
            case "campus-eats": MockData.campusEatsTurn
            default: nil
            }
        }
        let mentionsFinlo = resume?.highlights.contains { $0.id == "finlo" } ?? false
        var topics: [InterviewTurn]

        switch interview.type {
        case .technical:
            topics = projectTurns.isEmpty
                ? [MockData.cachingTurn, MockData.roleTurn(for: interview.role), MockData.debuggingTurn, MockData.decisionTurn]
                : [projectTurns[0], MockData.roleTurn(for: interview.role)] + projectTurns.dropFirst() + [MockData.debuggingTurn, MockData.decisionTurn]
        case .nonTechnical:
            topics = [
                mentionsFinlo ? MockData.finloDisagreementTurn : MockData.disagreementTurn,
                MockData.deadlineTurn,
                MockData.setbackTurn,
                MockData.feedbackTurn
            ]
        }

        let capacity = topicCapacity(forMinutes: interview.durationMinutes)
        if let company = interview.company {
            return Array(topics.prefix(capacity - 1)) + [MockData.motivationTurn(company: company)]
        }
        return Array(topics.prefix(capacity))
    }

    static func topicCapacity(forMinutes minutes: Int) -> Int {
        switch minutes {
        case ..<20: 3
        case ..<30: 4
        default: 5
        }
    }
}

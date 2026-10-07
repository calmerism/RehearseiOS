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

    /// Main topics the candidate has answered (follow-ups don't count).
    var answeredTurns: [InterviewTurn] {
        let answered = transcript.filter { !$0.isFollowUp }.count
        return Array(turns.prefix(answered))
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
        guard phase == .ready else { return }
        notice = nil
        phase = .recording(startedAt: .now)
    }

    func stopRecording() async {
        guard case .recording(let startedAt) = phase, let turn = currentTurn else { return }

        guard Date.now.timeIntervalSince(startedAt) >= minimumAnswerSeconds else {
            notice = "That was too short to catch. Tap when you’re ready and answer out loud."
            phase = .ready
            return
        }

        phase = .processing
        try? await Task.sleep(for: .seconds(1.2))
        guard phase == .processing else { return }

        let answer = isFollowUp ? (turn.followUp?.mockAnswer ?? "") : turn.mockAnswer
        transcript.append(TranscriptEntry(question: currentQuestion ?? "", answer: answer, isFollowUp: isFollowUp))
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
        let usesResume = resume != nil
        var topics: [InterviewTurn]

        switch interview.type {
        case .technical:
            topics = usesResume
                ? [MockData.financePaymentsTurn, MockData.roleTurn(for: interview.role), MockData.campusEatsTurn, MockData.debuggingTurn, MockData.decisionTurn]
                : [MockData.cachingTurn, MockData.roleTurn(for: interview.role), MockData.debuggingTurn, MockData.decisionTurn]
        case .behavioral:
            topics = [
                usesResume ? MockData.finloDisagreementTurn : MockData.disagreementTurn,
                MockData.deadlineTurn,
                MockData.setbackTurn,
                MockData.feedbackTurn
            ]
        case .systemDesign:
            topics = [MockData.shortenerTurn, MockData.viralLinkTurn, MockData.analyticsTurn]
            if usesResume { topics.insert(MockData.finloScaleTurn, at: 2) }
        }

        let capacity = topicCapacity(forMinutes: interview.durationMinutes)
        if let company = interview.company, interview.type != .systemDesign {
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

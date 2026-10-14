import Foundation

/// Stands in for answer evaluation and practice recommendations. Feedback is
/// assembled from the predefined evaluation of the questions that were
/// actually answered, so it always corresponds to the interview just taken.
enum MockFeedbackService {
    static func feedback(for interview: Interview, plannedTurns: [InterviewTurn], answeredTurns: [InterviewTurn], usedResume: Bool) -> Feedback {
        var base = baseline(for: interview.type)

        if usedResume {
            // Real projects make answers more specific.
            base.answerQuality += 4
        }

        let missing = plannedTurns.count - answeredTurns.count
        var coverageNote: String?
        if missing > 0 {
            coverageNote = "Based on \(answeredTurns.count) of \(plannedTurns.count) topics. A full interview gives you a better read."
        }

        let weaknesses = answeredTurns.compactMap { turn -> (Skill, String)? in
            if case .weakness(let skill) = turn.moment.kind { return (skill, turn.moment.note) }
            return nil
        }
        let focus = weaknesses.first?.0 ?? base.focus
        let evidence = weaknesses.first { $0.0 == focus }?.1 ?? base.evidence

        var strengths = answeredTurns
            .filter { $0.moment.kind == .strength }
            .map(\.moment.headline)
        if strengths.isEmpty {
            strengths = ["Answered every question"]
        }

        var feedback = Feedback(
            overall: 0,
            communication: base.communication,
            communicationNote: base.communicationNote,
            answerQuality: base.answerQuality,
            answerQualityNote: usedResume ? "Specific, because you were talking about your own projects." : base.answerQualityNote,
            summary: summary(for: focus),
            strengths: Array(strengths.prefix(3)),
            focus: focus,
            focusEvidence: evidence,
            coverageNote: coverageNote,
            deduction: max(missing, 0) * 3
        )
        // The total is always its parts added up.
        feedback.overall = feedback.scoredTotal
        return feedback
    }

    /// Stands in for the recommendation engine: questions that exercise the
    /// flagged skill, favouring open-ended ones where the habit shows most.
    static func recommendedQuestions(for skill: Skill, role: String?, from library: [Question], limit: Int = 3) -> [Question] {
        library
            .filter { $0.skills.contains(skill) && ($0.role == nil || $0.role == role) }
            .sorted { lhs, rhs in
                // Behavioral and common questions first: they have the least
                // built-in structure, so the habit is easiest to practice.
                (lhs.category == .roleBased ? 1 : 0) < (rhs.category == .roleBased ? 1 : 0)
            }
            .prefix(limit)
            .map { $0 }
    }

    /// The mocked evaluation of a single practiced answer.
    static func practiceNote(for focus: Skill?) -> String {
        switch focus {
        case .answerStructure:
            "You opened with your answer this time, and the details that followed were easy to place. Keep that first sentence short."
        case .concreteResults:
            "Much clearer about what you did yourself. Add one number for the result."
        case .tradeoffs:
            "You said what else you considered and why you didn’t pick it."
        case nil:
            "Got it. Do a mock interview and we’ll tell you what to practice next."
        }
    }

    private static func summary(for focus: Skill) -> String {
        switch focus {
        case .answerStructure:
            "Your examples were good, but a lot of answers started with the details before the point. Say your answer first and the rest is much easier to follow."
        case .concreteResults:
            "Good stories, but it was often hard to tell what you did yourself and how it ended."
        case .tradeoffs:
            "Your designs worked, but you rarely said what you gave up. Interviewers want to hear what else you considered."
        }
    }

    private struct Baseline {
        var overall: Int
        var communication: Int
        var communicationNote: String
        var answerQuality: Int
        var answerQualityNote: String
        var focus: Skill
        var evidence: String
    }

    private static func baseline(for type: InterviewType) -> Baseline {
        switch type {
        case .technical:
            Baseline(
                overall: 74, communication: 72,
                communicationNote: "Clear and calm, but long answers lost the thread.",
                answerQuality: 76, answerQualityNote: "Technically solid, and you explained why each step came next.",
                focus: .answerStructure,
                evidence: "A lot of answers started with the details before the point."
            )
        case .nonTechnical:
            Baseline(
                overall: 70, communication: 76,
                communicationNote: "Steady pace, with few filler words.",
                answerQuality: 64, answerQualityNote: "Relevant stories, but outcomes were often missing.",
                focus: .concreteResults,
                evidence: "Several stories ended without saying what changed."
            )
        }
    }
}

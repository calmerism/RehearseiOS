import Foundation

/// One entry in the candidate's history: a full mock interview, or a single
/// practiced question.
struct Rehearsal: Identifiable, Hashable {
    enum Kind: String, Hashable, nonisolated Codable {
        case interview
        case practice
    }

    var id = UUID()
    var kind: Kind
    var date: Date
    var interview: Interview?
    var feedback: Feedback?
    /// The questions actually asked, in order, with the (mocked) answer to each.
    var transcript: [TranscriptEntry] = []
    var practiceQuestion: Question?
    var practiceFocus: Skill?

    var score: Int? { feedback?.overall }

    var title: String {
        switch kind {
        case .interview: interview?.title ?? "Mock Interview"
        case .practice: practiceQuestion?.text ?? "Practice"
        }
    }

    var subtitle: String {
        let day = date.formatted(.relative(presentation: .named)).capitalizedFirst
        switch kind {
        // "Technical Interview from 2 days ago": joined with a word, not a comma.
        case .interview: return "\(interview?.type.interviewName ?? "Mock Interview") from \(day.lowercased())"
        case .practice: return "Practice answer from \(day.lowercased())"
        }
    }
}

struct TranscriptEntry: Hashable, nonisolated Codable {
    var question: String
    var answer: String
    var isFollowUp: Bool
    /// How this answer went, for a main question. Follow-ups have none.
    var moment: InterviewTurn.Moment? = nil
    /// What was actually said, when part of it was in Hindi; `answer` is
    /// the same answer in English.
    var spokenAnswer: String? = nil
    /// The Hindi parts of `spokenAnswer`, each with its English.
    var hindiLines: [HindiLine] = []
    /// This answer's verdicts from the answer judge, and what was measured
    /// while it was given. Nil before real judging and measuring.
    var verdicts: [JudgedPart]? = nil
    var measurements: Measurements? = nil

    /// The skill this answer fell short on, if any.
    var weakSkill: Skill? {
        if case .weakness(let skill) = moment?.kind { return skill }
        return nil
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

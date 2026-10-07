import Foundation

/// One entry in the candidate's history: a full mock interview, or a single
/// practiced question.
struct Rehearsal: Identifiable, Hashable {
    enum Kind: Hashable {
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
        case .interview: return "\(interview?.type.rawValue ?? "Mock") interview, \(day.lowercased())"
        case .practice: return "Practice, \(day.lowercased())"
        }
    }
}

struct TranscriptEntry: Hashable {
    var question: String
    var answer: String
    var isFollowUp: Bool
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

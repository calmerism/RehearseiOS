import Foundation

/// A report for one rehearsal. Scores are a practice signal, never a
/// prediction of whether the candidate will be hired.
struct Feedback: Hashable {
    var overall: Int
    var communication: Int
    var communicationNote: String
    var answerQuality: Int
    var answerQualityNote: String
    var summary: String
    var strengths: [String]
    /// The one area to improve next.
    var focus: Skill
    /// The specific moment in this interview that shows the focus area.
    var focusEvidence: String
    /// Set when the interview ended early, so the score isn't over-trusted.
    var coverageNote: String?
}

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

    /// What went wrong, in a few words each: the judged parts that scored
    /// lowest across the areas, worst first.
    var weaknesses: [String] {
        let weak = areas.flatMap(\.parts).filter { $0.score < 75 && $0.rule == nil }
        var seen = Set<String>()
        return weak.sorted { $0.score < $1.score }
            .map(\.evidence)
            .filter { seen.insert($0).inserted }
            .prefix(2)
            .map { $0 }
    }

    /// Points taken off for ending the interview early.
    var deduction: Int = 0

    /// The six areas the interview is scored on, worked out from its parts.
    var areas: [AreaScore] {
        Scoring.areas(answerQuality: answerQuality, communication: communication, focus: focus)
    }

    /// One answer scored on the same six areas: lifted for a strong answer,
    /// lowered where its weakness shows.
    func areas(for entry: TranscriptEntry) -> [AreaScore] {
        guard let moment = entry.moment else { return [] }
        let answer: Scoring.Answer
        if case .weakness(let skill) = moment.kind { answer = .weak(skill) } else { answer = .strong }
        return Scoring.areas(answerQuality: answerQuality, communication: communication, focus: focus, for: answer)
    }

    /// One answer's score: the average of its six areas.
    func score(for entry: TranscriptEntry) -> Int? {
        entry.moment == nil ? nil : Scoring.overall(areas(for: entry))
    }

    /// The average of the six areas, less any deduction: what `overall` is.
    var scoredTotal: Int {
        max(Scoring.overall(areas) - deduction, 0)
    }

    /// Where the score sits, in the ring's own four colors.
    var band: Band { Band(score: overall) }

    enum Band: CaseIterable {
        case needsWork, onYourWay, almostReady, interviewReady

        init(score: Int) {
            switch score {
            case ..<40: self = .needsWork
            case ..<80: self = .onYourWay
            case ..<90: self = .almostReady
            default: self = .interviewReady
            }
        }

        var title: String {
            switch self {
            case .needsWork: "Keep Practicing"
            case .onYourWay: "Getting There"
            case .almostReady: "Almost Ready"
            case .interviewReady: "Interview Ready"
            }
        }

        /// The scores in the band, as the scale under the ring labels them.
        var range: ClosedRange<Int> {
            switch self {
            case .needsWork: 0...39
            case .onYourWay: 40...79
            case .almostReady: 80...89
            case .interviewReady: 90...100
            }
        }
    }
}

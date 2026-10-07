import Foundation

enum PracticeSessionStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case ready
    case inProgress
    case reviewing
    case completed
}

/// A short rehearsal devoted to one specific improvement area.
struct PracticeSession: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var focusArea: ImprovementArea
    var question: Question
    var status: PracticeSessionStatus
    var priorScore: Int
    var resultScore: Int?
    var startedAt: Date?
    var completedAt: Date?
    var resultSummary: String?

    init(
        id: UUID = UUID(),
        focusArea: ImprovementArea,
        question: Question,
        status: PracticeSessionStatus = .ready,
        priorScore: Int? = nil,
        resultScore: Int? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        resultSummary: String? = nil
    ) {
        self.id = id
        self.focusArea = focusArea
        self.question = question
        self.status = status
        self.priorScore = priorScore ?? focusArea.score
        self.resultScore = resultScore
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.resultSummary = resultSummary
    }

    var isComplete: Bool { status == .completed }

    var scoreDelta: Int? {
        guard let resultScore else { return nil }
        return resultScore - priorScore
    }

    var scoreTransitionText: String {
        guard let resultScore else { return "\(priorScore)%" }
        return "\(priorScore)% → \(resultScore)%"
    }
}

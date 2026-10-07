import Foundation

/// An actionable skill focus identified by rehearsal feedback.
struct ImprovementArea: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String
    var score: Int
    var goal: Int
    var summary: String
    var advice: String

    init(
        id: UUID = UUID(),
        title: String,
        score: Int,
        goal: Int,
        summary: String,
        advice: String
    ) {
        self.id = id
        self.title = title
        self.score = score
        self.goal = goal
        self.summary = summary
        self.advice = advice
    }

    var pointsToGoal: Int {
        max(0, goal - score)
    }

    var improvementDescription: String {
        "\(score)% → \(goal)%"
    }
}

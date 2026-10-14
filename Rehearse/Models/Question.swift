import Foundation

enum QuestionCategory: String, CaseIterable, Identifiable, Hashable {
    case common = "Common"
    case behavioral = "Behavioral"
    case roleBased = "Role-Based"

    var id: Self { self }
}

enum Difficulty: String, CaseIterable, Hashable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
}

/// An interview habit that feedback can flag and practice can target. This is
/// the link that closes the loop: Feedback names a skill, Practice recommends
/// questions that exercise it.
enum Skill: String, CaseIterable, Identifiable, Hashable {
    case answerStructure
    case concreteResults
    case tradeoffs

    var id: Self { self }

    var title: String {
        switch self {
        case .answerStructure: "Answer Structure"
        case .concreteResults: "Concrete Results"
        case .tradeoffs: "Explaining Trade-offs"
        }
    }

    /// The single habit to practice.
    var advice: String {
        switch self {
        case .answerStructure:
            "Open with a one-sentence answer, then your approach, then the details."
        case .concreteResults:
            "Say what you did, not what the team did, and give a number or result."
        case .tradeoffs:
            "Name the option you didn’t choose and why you rejected it."
        }
    }

    /// What went wrong, in a few words, for a question's verdict.
    var shortfall: String {
        switch self {
        case .answerStructure: "Details before the point"
        case .concreteResults: "Unclear what you did"
        case .tradeoffs: "No alternatives named"
        }
    }

    /// How a stronger answer would open, as an example to copy.
    var exampleOpening: String {
        switch self {
        case .answerStructure:
            "“Our API slowed down under load, so I added a cache and cut response times from 900 to under 100 milliseconds. Here’s how.”"
        case .concreteResults:
            "“I rewrote the retry logic myself, and failed payments dropped by a third.”"
        case .tradeoffs:
            "“I chose a queue over direct calls. It adds a little delay, but nothing is lost if a service goes down.”"
        }
    }

    /// Why practice questions were picked for this skill.
    var recommendationReason: String {
        switch self {
        case .answerStructure: "An open question, where rambling is easiest to catch."
        case .concreteResults: "It asks what you did, so the details count."
        case .tradeoffs: "There’s more than one good answer, so explain your choice."
        }
    }
}

struct Question: Identifiable, Hashable {
    let id: String
    let text: String
    let category: QuestionCategory
    let difficulty: Difficulty
    /// `nil` for questions that apply to any role.
    let role: String?
    /// Skills this question is good practice for.
    let skills: [Skill]

    var roleLabel: String { role ?? "Any role" }

    /// "Medium behavioral question" or "Hard role-based question for iOS Engineer".
    var metaText: String {
        let base = "\(difficulty.rawValue) \(category.rawValue.lowercased()) question"
        return role.map { "\(base) for \($0)" } ?? base
    }
}

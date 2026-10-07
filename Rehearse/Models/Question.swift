import Foundation

enum QuestionCategory: String, CaseIterable, Identifiable, Hashable {
    case common = "Common"
    case behavioral = "Behavioral"
    case roleBased = "Role-Based"

    var id: Self { self }
}

enum Difficulty: String, Hashable {
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

    /// Why practice questions were picked for this skill.
    var recommendationReason: String {
        switch self {
        case .answerStructure: "Open questions that are easy to ramble on, so you’ll notice when you do."
        case .concreteResults: "Questions about what you did, where the details matter."
        case .tradeoffs: "Questions with more than one reasonable answer."
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

    /// "Behavioral, medium" or "Role-based, hard, for iOS Engineer".
    var metaText: String {
        let base = "\(category.rawValue), \(difficulty.rawValue.lowercased())"
        return role.map { "\(base), for \($0)" } ?? base
    }
}

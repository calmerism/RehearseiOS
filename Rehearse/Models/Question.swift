import Foundation

enum QuestionCategory: String, CaseIterable, Identifiable, Hashable, nonisolated Codable {
    case common = "Common"
    case behavioral = "Behavioral"
    case roleBased = "Role-Based"

    var id: Self { self }
}

enum Difficulty: String, CaseIterable, Hashable, nonisolated Codable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
}

/// An interview habit that feedback can flag and practice can target. This is
/// the link that closes the loop: Feedback names a skill, Practice recommends
/// questions that exercise it.
enum Skill: String, CaseIterable, Identifiable, Hashable, nonisolated Codable {
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

struct Question: Identifiable, Hashable, nonisolated Codable {
    let id: String
    let text: String
    let category: QuestionCategory
    let difficulty: Difficulty
    /// `nil` for questions that apply to any role.
    let role: String?
    /// Skills this question is good practice for.
    let skills: [Skill]
    /// The subject it's from, as the bank groups it: "system-design", "ios".
    /// Nil for the prototype's own questions.
    var area: String? = nil

    /// "System Design", "iOS", for the Library's filter.
    var areaTitle: String? { area.map(Question.title(forArea:)) }

    static func title(forArea area: String) -> String {
        let special = ["ios": "iOS", "sre": "SRE", "nlp": "NLP", "llm-ops": "LLM Ops", "unix": "Unix",
                       "devops": "DevOps", "generative-ai": "Generative AI", "react-native": "React Native"]
        if let name = special[area] { return name }
        return area.split(separator: "-").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    var roleLabel: String { role ?? "Any role" }

    /// "Medium behavioral question", or "Hard question for iOS Engineer":
    /// a role says more than "role-based", and keeps the line short.
    var metaText: String {
        if let role { return "\(difficulty.rawValue) question for \(role)" }
        return "\(difficulty.rawValue) \(category.rawValue.lowercased()) question"
    }
}

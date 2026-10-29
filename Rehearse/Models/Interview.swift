import Foundation

enum InterviewType: String, CaseIterable, Identifiable, Hashable, nonisolated Codable {
    case technical = "Technical"
    case nonTechnical = "Non-Technical"

    var id: Self { self }

    /// The interview's name, capitalized as a title: "Technical Interview".
    var interviewName: String { "\(rawValue) Interview" }

    /// Shown wherever the type is chosen, so the choice is an informed one
    /// rather than a label.
    var summary: String {
        switch self {
        case .technical: "Coding, system design and problem-solving questions, for engineering roles."
        case .nonTechnical: "Behavioral questions on teamwork, leadership and your past work."
        }
    }

    var symbol: String {
        switch self {
        case .technical: "chevron.left.forwardslash.chevron.right"
        case .nonTechnical: "person.2"
        }
    }
}

/// Part of an answer said in Hindi, as students often slip into it mid
/// answer, and how to say the same thing in English. Answer Review shows
/// these so the candidate learns the English for what they meant.
struct HindiLine: Hashable, nonisolated Codable {
    /// What was said, as heard.
    let said: String
    /// The same, said in English.
    let english: String
}

/// The context an interview is rehearsed against: either a real interview the
/// candidate has coming up, or a generic mock they configured for practice.
struct Interview: Identifiable, Hashable, nonisolated Codable {
    var id = UUID()
    var role: String
    /// `nil` means the mock is not company-specific.
    var company: String?
    var experienceLevel: String
    var type: InterviewType
    /// Only set for a real, scheduled interview.
    var date: Date?
    var durationMinutes: Int = 20

    var title: String {
        guard let company else { return role }
        return "\(role) at \(company)"
    }

    /// "Thu, Oct 9 at 3:00 PM"
    var scheduleText: String? {
        date?.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
    }

    /// "Today", "Tomorrow", "In 3 days"
    var countdownText: String? {
        guard let date else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: .now),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        switch days {
        case ..<0: return "Passed"
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "In \(days) days"
        }
    }
}

extension Interview {
    static let companies = ["Apple", "Google", "Microsoft", "Atlassian", "Canva"]
    static let experienceLevels = ["Internship", "New Graduate"]
    /// The last choice: the candidate types their own level.
    static let customExperience = "Custom"
    static let durations = [15, 20, 30]
}

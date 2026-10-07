import Foundation

enum InterviewType: String, CaseIterable, Identifiable, Hashable {
    case technical = "Technical"
    case behavioral = "Behavioral"
    case systemDesign = "System Design"

    var id: Self { self }

    /// Shown during setup so the choice is an informed one rather than a label.
    var summary: String {
        switch self {
        case .technical: "Your projects, technical decisions and debugging."
        case .behavioral: "Teamwork, ownership and how you handle setbacks."
        case .systemDesign: "Designing a system out loud and defending trade-offs."
        }
    }
}

/// The context an interview is rehearsed against: either a real interview the
/// candidate has coming up, or a generic mock they configured for practice.
struct Interview: Identifiable, Hashable {
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
    static let experienceLevels = ["Internship", "New Graduate", "Junior (1–2 years)"]
    static let durations = [15, 20, 30]
}

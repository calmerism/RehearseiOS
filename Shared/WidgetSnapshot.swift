import Foundation

/// What the widgets show, written by the app whenever it changes and read by
/// the widget extension. Kept to plain values so both targets can decode it
/// without the app's models. In the prototype the app's data is mocked, so
/// this is too; once accounts are real it carries the user's own.
nonisolated struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// The soonest real interview, as Home's card shows it.
    struct NextInterview: Codable, Equatable, Sendable {
        var company: String?
        var role: String
        var date: Date
        var durationMinutes: Int
        /// "Technical" or "Non-Technical"
        var typeName: String

        /// The company, or the role when there's none.
        var title: String { company ?? role }
        /// The role when the company is the title, so it isn't said twice.
        var subtitle: String? { company == nil ? nil : role }
    }

    /// The last mock interview's score, with its best and weakest areas.
    struct LastScore: Codable, Equatable, Sendable {
        struct Area: Codable, Equatable, Sendable {
            var title: String
            var score: Int
            /// The area's SF Symbol, as the app draws it.
            var symbol: String?
        }

        var overall: Int
        /// "Getting There"
        var bandTitle: String
        /// "Software Engineer at Apple"
        var interviewTitle: String
        var highest: Area
        var lowest: Area
        /// All six areas in the app's order.
        var areas: [Area]?
        /// Recent mock interviews' scores, oldest first, ending with this one.
        var history: [Point]?

        struct Point: Codable, Equatable, Sendable {
            var date: Date
            var score: Int
        }

        /// The change from the interview before, if there was one.
        var change: Int? {
            guard let history, history.count >= 2 else { return nil }
            return history[history.count - 1].score - history[history.count - 2].score
        }
    }

    var nextInterview: NextInterview?
    var lastScore: LastScore?
}

// MARK: - Sharing

nonisolated extension WidgetSnapshot {
    /// The App Group both targets belong to.
    static let appGroup = "group.com.rehearse.prototype"
    private static let key = "widgetSnapshot"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    /// The last one the app saved, if the app has run.
    static func load() -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defaults?.set(data, forKey: Self.key)
    }
}

// MARK: - Opening the app

/// Where a widget tap lands in the app.
nonisolated enum WidgetLink {
    static let scheme = "rehearse"

    /// Quick Prep for the soonest interview.
    static let quickPrep = URL(string: "rehearse://quick-prep")!
    /// The last mock interview's feedback.
    static let lastFeedback = URL(string: "rehearse://feedback")!
    /// The interview setup sheet, for someone without a score yet.
    static let mockInterview = URL(string: "rehearse://mock-interview")!
    /// Home, for empty widgets.
    static let home = URL(string: "rehearse://home")!
}

// MARK: - Sample

nonisolated extension WidgetSnapshot {
    /// The returning candidate from the app's demo, for the widget gallery
    /// and before the app has first run.
    static var sample: WidgetSnapshot {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: 3, to: .now) ?? .now
        return WidgetSnapshot(
            nextInterview: NextInterview(
                company: "Apple",
                role: "Software Engineer",
                date: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: day) ?? day,
                durationMinutes: 20,
                typeName: "Technical"
            ),
            lastScore: LastScore(
                overall: 78,
                bandTitle: "Getting There",
                interviewTitle: "Software Engineer at Apple",
                highest: .init(title: "Communication", score: 87, symbol: "waveform"),
                lowest: .init(title: "Problem Solving", score: 71, symbol: "puzzlepiece.fill"),
                areas: [
                    .init(title: "Technical Knowledge", score: 79, symbol: "cpu.fill"),
                    .init(title: "Problem Solving", score: 71, symbol: "puzzlepiece.fill"),
                    .init(title: "Communication", score: 87, symbol: "waveform"),
                    .init(title: "Project Depth", score: 76, symbol: "folder.fill"),
                    .init(title: "Handling Uncertainty", score: 80, symbol: "lightbulb.fill"),
                    .init(title: "Confidence", score: 75, symbol: "person.fill.checkmark")
                ],
                history: [(16, 58), (12, 62), (9, 66), (6, 70), (2, 74), (0, 78)].map { days, score in
                    LastScore.Point(date: calendar.date(byAdding: .day, value: -days, to: .now) ?? .now, score: score)
                }
            )
        )
    }
}

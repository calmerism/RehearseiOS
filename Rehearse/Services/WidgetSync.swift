import Foundation
import WidgetKit

/// Keeps the widgets showing what Home shows, and opens the place a widget
/// was tapped for.
extension AppState {
    /// The next interview and the last score, as plain values.
    var widgetSnapshot: WidgetSnapshot {
        let next = nextInterview.flatMap { interview -> WidgetSnapshot.NextInterview? in
            guard let date = interview.date else { return nil }
            return WidgetSnapshot.NextInterview(
                company: interview.company,
                role: interview.role,
                date: date,
                durationMinutes: interview.durationMinutes,
                typeName: interview.type.rawValue
            )
        }

        let score = lastInterview.flatMap { last -> WidgetSnapshot.LastScore? in
            guard let feedback = last.feedback else { return nil }
            let ranked = feedback.areas.sorted { $0.score > $1.score }
            guard let highest = ranked.first, let lowest = ranked.last else { return nil }
            return WidgetSnapshot.LastScore(
                overall: feedback.overall,
                bandTitle: feedback.band.title,
                interviewTitle: last.title,
                highest: .init(title: highest.area.title, score: highest.score, symbol: highest.area.symbol),
                lowest: .init(title: lowest.area.title, score: lowest.score, symbol: lowest.area.symbol),
                areas: feedback.areas.map { .init(title: $0.area.title, score: $0.score, symbol: $0.area.symbol) },
                history: interviews.prefix(6).reversed().compactMap { rehearsal in
                    rehearsal.feedback.map { .init(date: rehearsal.date, score: $0.overall) }
                }
            )
        }

        return WidgetSnapshot(nextInterview: next, lastScore: score)
    }

    /// Saves the snapshot and has the widgets redraw from it.
    func publishWidgetSnapshot() {
        widgetSnapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Goes where a widget link points. Signed out, the app stays on the
    /// way in and the link is dropped.
    func open(_ url: URL) {
        guard url.scheme == WidgetLink.scheme, isSignedIn, !needsProfileSetup else { return }
        selectedTab = .home
        switch url.host() {
        case "quick-prep":
            path = []
            if let next = nextInterview { setUpInterview(.upcoming(next.id)) }
        case "feedback":
            if let last = lastInterview { path = [.rehearsal(last.id)] }
        case "mock-interview":
            path = []
            setUpInterview(.custom)
        case "upcoming":
            // From a reminder: Quick Prep for that interview, if it's still
            // coming up; the list otherwise.
            if let id = UUID(uuidString: url.lastPathComponent), upcomingInterview(id: id) != nil {
                path = []
                setUpInterview(.upcoming(id))
            } else {
                path = [.upcoming]
            }
        default:
            path = []
        }
    }
}

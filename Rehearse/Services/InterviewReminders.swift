import Foundation
import UserNotifications

/// Local notifications before each upcoming interview while Interview
/// Reminders is on: three days before, the day before and two hours before.
/// They're scheduled on the phone, so nothing is sent anywhere; the whole
/// schedule is rebuilt whenever the interviews or the setting change.
enum InterviewReminders {
    private static let prefix = "interview-reminder-"

    /// Asks the first time; after that, says what the person chose.
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default: return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    /// Replaces every scheduled reminder with ones for `interviews`, or
    /// clears them when reminders are off.
    static func update(for interviews: [Interview], on: Bool) async {
        let center = UNUserNotificationCenter.current()
        let ours = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ours)
        let requests = interviews.flatMap { Self.requests(for: $0) }
        guard on, !requests.isEmpty else { return }
        // Reminders are on by default, so someone who never saw the
        // onboarding question is asked once there's something to remind
        // them of.
        guard await requestPermission() else { return }
        for request in requests {
            try? await center.add(request)
        }
    }

    /// The reminders still ahead for one interview.
    static func requests(for interview: Interview, now: Date = .now) -> [UNNotificationRequest] {
        guard let date = interview.date, date > now else { return [] }
        // "Apple interview", or the role when there's no company.
        let name = "\(interview.company ?? interview.role) interview"
        let calendar = Calendar.current
        let moments: [(key: String, at: Date?, title: String, body: String)] = [
            ("3d", calendar.date(byAdding: .day, value: -3, to: date), "\(name) in 3 days", "A quick practice now keeps your answers sharp."),
            ("1d", calendar.date(byAdding: .day, value: -1, to: date), "\(name) tomorrow", "One mock interview today, while it’s fresh."),
            ("2h", date.addingTimeInterval(-2 * 60 * 60), "\(name) in 2 hours", "Warm up with a question or two, then take a breath."),
        ]
        return moments.compactMap { moment in
            guard let at = moment.at, at > now else { return nil }
            let content = UNMutableNotificationContent()
            content.title = moment.title
            content.body = moment.body
            content.sound = .default
            content.threadIdentifier = interview.id.uuidString
            content.userInfo = ["url": link(for: interview).absoluteString]
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: at)
            return UNNotificationRequest(
                identifier: prefix + interview.id.uuidString + "-" + moment.key,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
        }
    }

    /// Opens Quick Prep for that interview.
    static func link(for interview: Interview) -> URL {
        URL(string: "\(WidgetLink.scheme)://upcoming/\(interview.id.uuidString)")!
    }
}

/// What the reminders are scheduled from, so they're rebuilt when it changes.
struct ReminderPlan: Hashable {
    var on: Bool
    var interviews: [Interview]
}

/// Shows reminders while the app is open, and opens the interview when one
/// is tapped. A tap that launches the app waits until the app can open it.
final class ReminderTapHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderTapHandler()

    private var pending: URL?
    var open: ((URL) -> Void)? {
        didSet {
            if let pending, let open {
                self.pending = nil
                open(pending)
            }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let link = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: link) else { return }
        await MainActor.run {
            if let open { open(url) } else { pending = url }
        }
    }
}

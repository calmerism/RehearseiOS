#if DEBUG
import Foundation

/// Opens a screen directly for screenshots, e.g. `-screen practice`.
/// Not part of the product, and compiled out of release builds.
extension AppState {
    /// `-demoTabs` walks the dock through every tab, for screen recordings.
    private func playDemoTabs() {
        Task { @MainActor in
            for tab in [AppTab.questions, .home] {
                try? await Task.sleep(for: .seconds(1.4))
                selectedTab = tab
            }
        }
    }

    func applyDebugLaunchArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-demoTabs") { playDemoTabs() }
        // Screenshots of any screen but the login start signed in.
        if arguments.contains("-signedIn") || arguments.contains("-demoTabs") || arguments.contains("-demoSwipe") {
            isSignedIn = true
        }
        guard let index = arguments.firstIndex(of: "-screen"), arguments.indices.contains(index + 1) else { return }
        let screen = arguments[index + 1]
        isSignedIn = !["login", "welcome"].contains(screen)
        if screen == "setup" {
            load(.newUser)
            needsProfileSetup = true
        }
        if arguments.contains("-newUser") { load(.newUser) }
        if arguments.contains("-resumeReady") { resume = .ready(MockData.resume) }
        if arguments.contains("-tailored"), let next = nextInterview {
            resume = .ready(MockData.resume)
            var version = MockData.tailoredVersions(company: next.company, role: next.role)[0]
            version.interviewID = next.id
            saveTailoredResume(version)
        }

        switch arguments[index + 1] {
        case "setup-upcoming": if let next = nextInterview { setUpInterview(.upcoming(next.id)) }
        case "setup-custom": setUpInterview(.custom)
        case "resume": selectedTab = .resume
        case "resume-parsing":
            selectedTab = .resume
            Task { await uploadResume(named: MockData.resumeFileName) }
        case "resume-version":
            selectedTab = .resume
            if let first = tailoredResumes.first { resumePath = [.resumeVersion(first.id)] }
        case "library": selectedTab = .questions
        case "library-focus": path = [.library(focus: .answerStructure)]
        case "question": path = [.question(library[1])]
        case "practice": path = [.practice]
        case "history": path = [.history]
        case "collection":
            selectedTab = .questions
            if let first = playlists.first { questionsPath = [.collection(.playlist(first.id))] }
        case "see-all": path = [.history]
        case "profile": path = [.profile]
        case "upcoming": path = [.upcoming]
        case "progress":
            selectedTab = .progress
        case "detail": path = [.rehearsal(rehearsals[1].id)]
        case "detail-low": if let first = interviews.last { path = [.rehearsal(first.id)] }
        case "answer":
            path = [.rehearsal(rehearsals[1].id)]
            debugOpensFirstAnswer = true
        case "editor": interviewEditor = InterviewEditorRequest(interview: nextInterview)
        case "editor-new": interviewEditor = InterviewEditorRequest()
        case "interview":
            if let upcoming = nextInterview { startInterview(upcoming, resume: MockData.resume) }
        case "practice-session": activePractice = library[1]
        default: break
        }
    }
}

import SwiftUI
import UserNotifications

extension InterviewReminders {
    /// `-testReminder`: the first upcoming interview's first reminder again,
    /// 8 seconds from now, so a tap can be tried without waiting days.
    static func scheduleTestReminderIfAsked(for interviews: [Interview]) async {
        guard ProcessInfo.processInfo.arguments.contains("-testReminder"),
              let reminder = interviews.lazy.flatMap({ requests(for: $0) }).first else { return }
        let request = UNNotificationRequest(
            identifier: "test-" + reminder.identifier,
            content: reminder.content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 8, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// With `-testReminder`, prints what's scheduled after each change.
    static func logScheduledIfAsked() async {
        guard ProcessInfo.processInfo.arguments.contains("-testReminder") else { return }
        let scheduled = await UNUserNotificationCenter.current().pendingNotificationRequests()
        print("Reminders scheduled (\(scheduled.count)):", scheduled.map(\.identifier).sorted().joined(separator: ", "))
    }
}

extension View {
    /// `-bottom` opens scrolling screens already scrolled to the end, so the
    /// bottom of a page can be screenshotted.
    func debugScrollAnchor() -> some View {
        modifier(DebugScrollToBottom())
    }
}

/// Scrolls once the page has laid out, so the bars' insets are counted and
/// the bottom edge looks as it does after a real scroll.
private struct DebugScrollToBottom: ViewModifier {
    @MainActor static func scrollListsToBottom() { scrollLists(toFraction: 1) }

    @MainActor static func scrollLists(toFraction fraction: CGFloat) {
        func all(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(all) }
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        let scrolls = windows.flatMap { all($0) }.compactMap { $0 as? UIScrollView }.filter { $0.contentSize.height > $0.bounds.height }
        // Every tab's list stays alive underneath, so scroll them all.
        for scroll in scrolls {
            let top = -scroll.adjustedContentInset.top
            let bottom = scroll.contentSize.height + scroll.adjustedContentInset.bottom - scroll.bounds.height
            scroll.setContentOffset(CGPoint(x: 0, y: top + (bottom - top) * fraction), animated: false)
        }
    }

    @State private var position = ScrollPosition()

    func body(content: Content) -> some View {
        if ProcessInfo.processInfo.arguments.contains("-middle") {
            // `-middle` scrolls halfway, for the part of a long page between.
            content.task {
                try? await Task.sleep(for: .seconds(1.2))
                Self.scrollLists(toFraction: 0.5)
            }
        } else if ProcessInfo.processInfo.arguments.contains("-bottom") {
            content
                .scrollPosition($position)
                .task {
                    try? await Task.sleep(for: .seconds(0.8))
                    withAnimation { position.scrollTo(edge: .bottom) }
                    // Lists ignore a scroll position: scroll their UIKit view.
                    try? await Task.sleep(for: .seconds(0.6))
                    Self.scrollListsToBottom()
                }
        } else {
            content
        }
    }
}
#else
import SwiftUI

extension View {
    func debugScrollAnchor() -> some View { self }
}
#endif

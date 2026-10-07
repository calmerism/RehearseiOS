#if DEBUG
import Foundation

/// Opens a screen directly for screenshots, e.g. `-screen practice`.
/// Not part of the product, and compiled out of release builds.
extension AppState {
    func applyDebugLaunchArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screen"), arguments.indices.contains(index + 1) else { return }
        if arguments.contains("-newUser") { load(.newUser) }
        if arguments.contains("-resumeReady") { resume = .ready(MockData.resume) }

        switch arguments[index + 1] {
        case "setup-upcoming": path = nextInterview.map { [.setup(.upcoming($0.id))] } ?? []
        case "setup-custom": selectedTab = .mockInterview
        case "resume": path = [.resume]
        case "library": selectedTab = .library
        case "library-focus": path = [.library(focus: .answerStructure)]
        case "question": path = [.question(library[1])]
        case "practice": path = [.practice(nil)]
        case "history": path = [.history]
        case "progress": selectedTab = .progress
        case "detail": path = [.rehearsal(rehearsals[1].id)]
        case "editor": interviewEditor = InterviewEditorRequest(interview: nextInterview)
        case "editor-new": interviewEditor = InterviewEditorRequest()
        case "interview":
            if let upcoming = nextInterview { startInterview(upcoming, useResume: true) }
        case "practice-session": activePractice = library[1]
        default: break
        }
    }
}
#endif

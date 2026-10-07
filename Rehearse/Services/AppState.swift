import Foundation
import Observation

/// The tab bar: Home, plus the places a candidate goes on their own.
enum AppTab: Hashable {
    case home
    case progress
    case library
    case mockInterview
}

/// Every destination below a tab's root. Each tab keeps its own stack, so
/// "back" always means "where I came from".
enum Route: Hashable {
    case setup(SetupMode)
    case resume
    /// The library, optionally pre-filtered to questions that build a skill.
    case library(focus: Skill?)
    case question(Question)
    /// Practice, optionally starting from a specific question.
    case practice(Question?)
    case history
    case rehearsal(Rehearsal.ID)
    case progress
}

enum SetupMode: Hashable {
    /// Rehearse one of the candidate's real upcoming interviews; its details are known.
    case upcoming(Interview.ID)
    /// A generic mock the candidate configures themselves.
    case custom
}

/// Opens the upcoming-interview sheet: empty to add one, or with an existing
/// interview to reschedule it.
struct InterviewEditorRequest: Identifiable {
    let id = UUID()
    var interview: Interview?
}

/// A live interview that is about to start or in progress.
struct InterviewSession: Identifiable {
    let id = UUID()
    let interview: Interview
    let resume: ResumeContext?
}

/// Presentation scenarios, so each Home context can be shown on demand.
enum DemoScenario {
    case returning
    case newUser
}

/// In-memory state for the prototype. No persistence, no network.
@Observable
final class AppState {
    var selectedTab: AppTab = .home
    /// The Home tab's stack; the interview and practice flows return here.
    var path: [Route] = []
    var progressPath: [Route] = []
    var libraryPath: [Route] = []
    var mockInterviewPath: [Route] = []
    /// The candidate's real interviews, soonest first.
    private(set) var upcomingInterviews: [Interview] = []
    var resume: ResumeStatus = .none
    var rehearsals: [Rehearsal] = []
    let library = MockData.questions

    /// Presented full screen: the interview and practice are focused tasks.
    var activeInterview: InterviewSession?
    var activePractice: Question?
    /// The add or edit sheet for an upcoming interview.
    var interviewEditor: InterviewEditorRequest?

    init(scenario: DemoScenario = .returning) {
        load(scenario)
        #if DEBUG
        applyDebugLaunchArguments()
        #endif
    }

    func load(_ scenario: DemoScenario) {
        selectedTab = .home
        path = []
        progressPath = []
        libraryPath = []
        mockInterviewPath = []
        resume = .none
        switch scenario {
        case .returning:
            upcomingInterviews = MockData.upcomingInterviews
            rehearsals = MockData.rehearsals
        case .newUser:
            upcomingInterviews = []
            rehearsals = []
        }
    }

    // MARK: - Derived context

    var interviews: [Rehearsal] { rehearsals.filter { $0.kind == .interview } }
    var lastInterview: Rehearsal? { interviews.first }
    var isNewUser: Bool { interviews.isEmpty }

    /// The weakness to work on next, from the most recent interview.
    var currentFocus: Skill? { lastInterview?.feedback?.focus }

    /// True right after an interview, when acting on feedback matters most.
    var hasFreshFeedback: Bool {
        guard let last = lastInterview else { return false }
        return Calendar.current.isDateInToday(last.date)
    }

    /// Practice sessions on the current focus since the last interview.
    var practiceCountSinceLastInterview: Int {
        guard let last = lastInterview, let focus = currentFocus else { return 0 }
        return rehearsals.filter { $0.kind == .practice && $0.practiceFocus == focus && $0.date > last.date }.count
    }

    func rehearsalCount(for interview: Interview) -> Int {
        interviews.filter { $0.interview?.id == interview.id }.count
    }

    /// The most recent score from rehearsing this interview, if any.
    func lastScore(for interview: Interview) -> Int? {
        interviews.first { $0.interview?.id == interview.id }?.feedback?.overall
    }

    var practiceSessions: [Rehearsal] { rehearsals.filter { $0.kind == .practice } }

    func recommendedQuestions(limit: Int = 3) -> [Question] {
        guard let focus = currentFocus else { return [] }
        let role = nextInterview?.role ?? lastInterview?.interview?.role
        return MockFeedbackService.recommendedQuestions(for: focus, role: role, from: library, limit: limit)
    }

    /// Scores oldest → newest, for spotting a trend.
    func trend(_ score: KeyPath<Feedback, Int>) -> [Int] {
        interviews.reversed().compactMap { $0.feedback?[keyPath: score] }
    }

    var overallTrend: [Int] { trend(\.overall) }

    /// The skill a practice question targets: the current weakness if the
    /// question exercises it, otherwise whatever the question builds.
    func focus(for question: Question) -> Skill? {
        if let currentFocus, question.skills.contains(currentFocus) { return currentFocus }
        return question.skills.first
    }

    func rehearsal(id: Rehearsal.ID) -> Rehearsal? {
        rehearsals.first { $0.id == id }
    }

    /// The interview taken just before this one, for "since last time".
    func previousInterview(before rehearsal: Rehearsal) -> Rehearsal? {
        interviews.first { $0.date < rehearsal.date }
    }

    /// Past attempts at one library question, newest first.
    func practiceHistory(for question: Question) -> [Rehearsal] {
        rehearsals.filter { $0.kind == .practice && $0.practiceQuestion?.id == question.id }
    }

    // MARK: - Upcoming interview

    /// The soonest real interview, which sets the role for recommendations.
    var nextInterview: Interview? { upcomingInterviews.first }

    func upcomingInterview(id: Interview.ID) -> Interview? {
        upcomingInterviews.first { $0.id == id }
    }

    /// Adds a new interview, or updates one by identity so rehearsals already
    /// done for it still count after it's rescheduled.
    func saveUpcomingInterview(_ interview: Interview) {
        if let index = upcomingInterviews.firstIndex(where: { $0.id == interview.id }) {
            upcomingInterviews[index] = interview
        } else {
            upcomingInterviews.append(interview)
        }
        upcomingInterviews.sort { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }

    func removeUpcomingInterview(id: Interview.ID) {
        upcomingInterviews.removeAll { $0.id == id }
        path.removeAll { $0 == .setup(.upcoming(id)) }
    }

    // MARK: - Interview

    func startInterview(_ interview: Interview, useResume: Bool) {
        activeInterview = InterviewSession(interview: interview, resume: useResume ? resume.context : nil)
    }

    /// Saves a finished interview to history; Home, History and Progress all
    /// read from here, so they update immediately.
    @discardableResult
    func saveInterview(_ session: MockInterviewService, usedResume: Bool) -> Rehearsal {
        let feedback = MockFeedbackService.feedback(
            for: session.interview,
            plannedTurns: session.turns,
            answeredTurns: session.answeredTurns,
            usedResume: usedResume
        )
        let rehearsal = Rehearsal(
            kind: .interview,
            date: .now,
            interview: session.interview,
            feedback: feedback,
            transcript: session.transcript
        )
        rehearsals.insert(rehearsal, at: 0)
        return rehearsal
    }

    /// Leaves the interview flow and returns Home.
    func closeInterview() {
        activeInterview = nil
        returnHome(to: [])
    }

    /// Leaves the interview flow straight into practice for the flagged weakness.
    func closeInterviewAndPractice(_ question: Question?) {
        activeInterview = nil
        returnHome(to: [.practice(question)])
    }

    /// The setup an interview started from is finished with, whichever tab it was in.
    private func returnHome(to homePath: [Route]) {
        selectedTab = .home
        path = homePath
        mockInterviewPath = []
    }

    // MARK: - Practice

    func savePractice(_ question: Question, focus: Skill?) {
        rehearsals.insert(
            Rehearsal(kind: .practice, date: .now, practiceQuestion: question, practiceFocus: focus),
            at: 0
        )
    }

    // MARK: - Resume

    /// Stands in for upload + parsing. One mock file parses; the other fails,
    /// so the error state can be demonstrated.
    func uploadResume(named fileName: String) async {
        resume = .parsing(fileName: fileName)
        try? await Task.sleep(for: .seconds(2.2))
        guard resume == .parsing(fileName: fileName) else { return }
        if fileName == MockData.unreadableResumeFileName {
            resume = .failed(fileName: fileName, reason: "This looks like a photo, so we couldn’t read the text. Try a PDF or Word file instead.")
        } else {
            resume = .ready(MockData.resume)
        }
    }

    func removeResume() {
        resume = .none
    }
}

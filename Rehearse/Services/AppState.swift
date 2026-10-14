import Foundation
import SwiftUI
import Observation

/// The dock's tabs: Home, Questions, Practice and Profile. The mock
/// interview sits between them as a button, not a tab.
/// The dock's two tabs. Practice is reached from Home and Your Score, and
/// Profile from Home's header.
enum AppTab: Hashable, CaseIterable {
    case home
    case questions
}

/// Every destination below a tab's root. Each tab keeps its own stack, so
/// "back" always means "where I came from".
enum Route: Hashable {
    case resume
    case resumeVersion(ResumeVersion.ID)
    /// The library, pre-filtered to questions that build a skill.
    case library(focus: Skill?)
    case question(Question)
    case collection(QuestionCollection)
    case rehearsal(Rehearsal.ID)
    case progress
    case history
    case practice
    case profile
    /// Every upcoming interview, from Home's See All.
    case upcoming
}

enum SetupMode: Hashable {
    /// Rehearse one of the candidate's real upcoming interviews; its details are known.
    case upcoming(Interview.ID)
    /// A generic mock the candidate configures themselves.
    case custom
}

/// Opens the mock interview setup sheet.
struct SetupRequest: Identifiable {
    let id = UUID()
    let mode: SetupMode
}

/// How firmly feedback is worded. A preference only in this prototype.
enum FeedbackStyle: String, CaseIterable, Identifiable {
    case supportive = "Supportive"
    case standard = "Standard"
    case tough = "Tough"

    var id: Self { self }
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
    /// Signed out on launch, so the login screen comes first. Any sign in
    /// opens the app; nothing is checked in this prototype.
    var isSignedIn = false
    /// The name the candidate signed up with; the prototype's own until then.
    var candidateName = MockData.candidateName
    /// First launch shows the welcome before the login.
    var hasSeenWelcome = false
    /// Set by Get Started, so the login opens on Sign Up.
    var opensSignUp = false
    /// A new account sets up its profile before Home.
    var needsProfileSetup = false
    /// What the candidate is preparing for, from profile setup.
    var targetRole = "Software Engineer"
    var experienceLevel = MockData.candidateExperienceLevel
    var selectedTab: AppTab = .home
    /// The Home tab's stack; the interview flow returns here.
    var path: [Route] = []
    #if DEBUG
    /// `-screen answer` opens the first answer's review, for screenshots.
    var debugOpensFirstAnswer = false
    #endif
    var questionsPath: [Route] = []
    /// The candidate's real interviews, soonest first.
    private(set) var upcomingInterviews: [Interview] = []
    /// Real interviews already done, most recent first. Upcoming ones join
    /// them once their day has passed (`pastInterviews`).
    private(set) var completedInterviews: [Interview] = []

    /// Every real interview whose time has come, most recent first.
    var pastInterviews: [Interview] {
        let passed = upcomingInterviews.filter { ($0.date ?? .distantFuture) < .now }
        return (passed + completedInterviews).sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    /// The most recent mock interview rehearsing this real one, if any.
    func lastRehearsal(for interview: Interview) -> Rehearsal? {
        interviews.first { $0.interview?.id == interview.id }
    }
    /// The resume on the candidate's Profile.
    var resume: ResumeStatus = .none
    /// The Profile resume rewritten for particular jobs, newest first.
    private(set) var tailoredResumes: [ResumeVersion] = []
    var rehearsals: [Rehearsal] = []
    let library = MockData.questions
    /// Saved questions, newest first, like liked songs.
    var savedQuestionIDs: [Question.ID] = []
    var playlists: [QuestionPlaylist] = []

    /// Presented full screen: the interview and practice are focused tasks.
    var activeInterview: InterviewSession?
    var activePractice: Question?
    /// The add or edit sheet for an upcoming interview.
    var interviewEditor: InterviewEditorRequest?
    /// The mock interview setup sheet.
    var interviewSetup: SetupRequest?
    /// An interview started from the setup sheet, presented once it closes.
    private var pendingInterview: InterviewSession?

    // Profile preferences. Stored, but they don't change feedback yet.
    var feedbackStyle: FeedbackStyle = .standard
    var flagsFillerWords = true
    var remindersOn = true

    init(scenario: DemoScenario = .returning) {
        load(scenario)
        #if DEBUG
        applyDebugLaunchArguments()
        #endif
    }

    func load(_ scenario: DemoScenario) {
        selectedTab = .home
        path = []
        questionsPath = []
        resume = .none
        tailoredResumes = []
        switch scenario {
        case .returning:
            upcomingInterviews = MockData.upcomingInterviews
            completedInterviews = MockData.completedInterviews
            rehearsals = MockData.rehearsals
            savedQuestionIDs = Self.withImportant(MockData.savedQuestionIDs)
            playlists = MockData.playlists
        case .newUser:
            upcomingInterviews = []
            completedInterviews = []
            rehearsals = []
            savedQuestionIDs = Self.withImportant([])
            playlists = []
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

    /// Skills flagged in the last few interviews, most often first, with how
    /// many of them flagged each. The current focus leads on a tie.
    func flaggedSkills(inLast count: Int = 3) -> [(skill: Skill, count: Int)] {
        let recent = interviews.prefix(count)
        return Skill.allCases
            .map { skill in (skill: skill, count: recent.filter { $0.feedback?.focus == skill }.count) }
            .filter { $0.count > 0 }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.skill == currentFocus }
    }

    /// Consecutive days, up to today, with at least one rehearsal. A day
    /// without one yet today doesn't break the streak.
    var dayStreak: Int {
        let calendar = Calendar.current
        let days = Set(rehearsals.map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: .now)
        if !days.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day) ?? day }
        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    var averageScore: Int? {
        let scores = interviews.compactMap { $0.feedback?.overall }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / scores.count
    }

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

    // MARK: - Collections

    func isSaved(_ question: Question) -> Bool {
        savedQuestionIDs.contains(question.id)
    }

    func toggleSaved(_ question: Question) {
        if let index = savedQuestionIDs.firstIndex(of: question.id) {
            savedQuestionIDs.remove(at: index)
        } else {
            savedQuestionIDs.insert(question.id, at: 0)
        }
    }

    /// Saved starts with the questions nearly every interview includes,
    /// after any the candidate saved, so the two live in one place.
    private static func withImportant(_ saved: [Question.ID]) -> [Question.ID] {
        saved + MockData.importantQuestionIDs.filter { !saved.contains($0) }
    }

    func questions(in collection: QuestionCollection) -> [Question] {
        let ids: [Question.ID] = switch collection {
        case .saved: savedQuestionIDs
        case .playlist(let id): playlist(id: id)?.questionIDs ?? []
        }
        return ids.compactMap { id in library.first { $0.id == id } }
    }

    func playlist(id: QuestionPlaylist.ID) -> QuestionPlaylist? {
        playlists.first { $0.id == id }
    }

    @discardableResult
    func createPlaylist(named name: String, with question: Question? = nil) -> QuestionPlaylist {
        let playlist = QuestionPlaylist(name: name, questionIDs: question.map { [$0.id] } ?? [])
        playlists.append(playlist)
        return playlist
    }

    func renamePlaylist(id: QuestionPlaylist.ID, to name: String) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[index].name = name
    }

    func deletePlaylist(id: QuestionPlaylist.ID) {
        playlists.removeAll { $0.id == id }
        questionsPath.removeAll { $0 == .collection(.playlist(id)) }
    }

    /// Adds to the end, once; a question already there stays where it is.
    func add(_ question: Question, toPlaylist id: QuestionPlaylist.ID) {
        guard let index = playlists.firstIndex(where: { $0.id == id }),
              !playlists[index].questionIDs.contains(question.id) else { return }
        playlists[index].questionIDs.append(question.id)
    }

    func remove(_ question: Question, from collection: QuestionCollection) {
        switch collection {
        case .saved:
            savedQuestionIDs.removeAll { $0 == question.id }
        case .playlist(let id):
            guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
            playlists[index].questionIDs.removeAll { $0 == question.id }
        }
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
        for index in tailoredResumes.indices where tailoredResumes[index].interviewID == id {
            tailoredResumes[index].interviewID = nil
        }
        if case .upcoming(id)? = interviewSetup?.mode { interviewSetup = nil }
    }

    // MARK: - Interview

    func setUpInterview(_ mode: SetupMode) {
        interviewSetup = SetupRequest(mode: mode)
    }

    /// From the setup sheet, the interview waits for the sheet to close, since
    /// one modal can't present over another that is leaving.
    func startInterview(_ interview: Interview, resume: ResumeContext?) {
        let session = InterviewSession(interview: interview, resume: resume)
        if interviewSetup != nil {
            pendingInterview = session
            interviewSetup = nil
        } else {
            activeInterview = session
        }
    }

    /// The same interview again, straight away, with the resume it would
    /// get from setup. From the end of a live interview the new one takes
    /// its place.
    func rehearseAgain(_ rehearsal: Rehearsal) {
        guard let interview = rehearsal.interview else { return }
        let upcomingID = upcomingInterview(id: interview.id)?.id
        let resume = defaultResumeChoice(for: upcomingID).flatMap(resumeContext(for:))
        activeInterview = InterviewSession(interview: interview, resume: resume)
    }

    func interviewSetupDismissed() {
        guard let pendingInterview else { return }
        self.pendingInterview = nil
        activeInterview = pendingInterview
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
        selectedTab = .home
        path = []
    }

    /// Leaves the interview flow straight into practice for the flagged
    /// weakness, pushed on Home so "back" returns there.
    /// Leaves the interview flow onto a page pushed on Home.
    func closeInterview(showing route: Route) {
        activeInterview = nil
        selectedTab = .home
        path = [route]
    }

    func closeInterviewAndPractice() {
        activeInterview = nil
        selectedTab = .home
        path = [.practice]
    }

    // MARK: - Practice

    func savePractice(_ question: Question, focus: Skill?) {
        rehearsals.insert(
            Rehearsal(kind: .practice, date: .now, practiceQuestion: question, practiceFocus: focus),
            at: 0
        )
    }

    // MARK: - Resume

    /// Stands in for reading a file. Documents parse; a photo fails, so the
    /// error state can be demonstrated.
    static func readResume(named fileName: String) async -> ResumeStatus {
        try? await Task.sleep(for: .seconds(2.2))
        let photo = ["heic", "jpg", "jpeg", "png"].contains((fileName as NSString).pathExtension.lowercased())
        if fileName == MockData.unreadableResumeFileName || photo {
            return .failed(fileName: fileName, reason: "This looks like a photo, so we couldn’t read the text. Try a PDF or Word file instead.")
        }
        var context = MockData.resume
        context.fileName = fileName
        return .ready(context)
    }

    /// Adds or replaces the Profile resume. Tailored versions were made from
    /// the old file, so they go with it.
    func uploadResume(named fileName: String) async {
        resume = .parsing(fileName: fileName)
        let result = await Self.readResume(named: fileName)
        guard resume == .parsing(fileName: fileName) else { return }
        resume = result
        if result.context != nil { tailoredResumes = [] }
    }

    /// A resume written by the builder becomes the Profile one. Tailored
    /// versions were made from the old one, so they go.
    func useBuiltResume(_ context: ResumeContext) {
        resume = .ready(context)
        tailoredResumes = []
    }

    func removeResume() {
        resume = .none
        tailoredResumes = []
    }

    func tailoredResume(id: ResumeVersion.ID) -> ResumeVersion? {
        tailoredResumes.first { $0.id == id }
    }

    /// Saves a version, and makes it the only one used for its interview.
    func saveTailoredResume(_ version: ResumeVersion) {
        if let interviewID = version.interviewID {
            for index in tailoredResumes.indices where tailoredResumes[index].interviewID == interviewID {
                tailoredResumes[index].interviewID = nil
            }
        }
        tailoredResumes.insert(version, at: 0)
    }

    /// Each interview uses at most one version, so linking moves it here.
    func linkTailoredResume(id: ResumeVersion.ID, to interviewID: Interview.ID?) {
        for index in tailoredResumes.indices {
            if tailoredResumes[index].id == id {
                tailoredResumes[index].interviewID = interviewID
            } else if interviewID != nil, tailoredResumes[index].interviewID == interviewID {
                tailoredResumes[index].interviewID = nil
            }
        }
    }

    func removeTailoredResume(id: ResumeVersion.ID) {
        tailoredResumes.removeAll { $0.id == id }
        path.removeAll { $0 == .resumeVersion(id) }
    }

    /// What an interview starts with: the version made for it, otherwise the
    /// Profile resume, otherwise nothing.
    func defaultResumeChoice(for interviewID: Interview.ID?) -> ResumeChoice? {
        if let interviewID, let version = tailoredResumes.first(where: { $0.interviewID == interviewID }) {
            return .tailored(version.id)
        }
        return resume.context == nil ? nil : .original
    }

    func resumeContext(for choice: ResumeChoice) -> ResumeContext? {
        switch choice {
        case .original: resume.context
        case .tailored(let id): tailoredResume(id: id)?.context
        case .uploaded(let context): context
        }
    }
}

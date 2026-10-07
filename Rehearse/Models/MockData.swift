import Foundation

/// All predefined content for the presentation prototype. Wherever the real
/// product would use AI (resume parsing, question generation, follow-ups,
/// evaluation, recommendations) the outcome is written out here instead.
enum MockData {
    static let candidateName = "Alex"
    static let candidateExperienceLevel = "Internship"

    // MARK: - Upcoming interviews

    /// Soonest first, as the app keeps them.
    static var upcomingInterviews: [Interview] {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: 9, to: .now) ?? .now
        let date = calendar.date(bySettingHour: 10, minute: 30, second: 0, of: day) ?? day
        let atlassian = Interview(
            id: secondInterviewID,
            role: "Backend Engineer",
            company: "Atlassian",
            experienceLevel: candidateExperienceLevel,
            type: .behavioral,
            date: date,
            durationMinutes: 20
        )
        return [upcomingInterview, atlassian]
    }

    static var upcomingInterview: Interview {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: 3, to: .now) ?? .now
        let date = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: day) ?? day
        return Interview(
            id: upcomingInterviewID,
            role: "Software Engineer",
            company: "Apple",
            experienceLevel: candidateExperienceLevel,
            type: .technical,
            date: date,
            durationMinutes: 20
        )
    }

    private static let upcomingInterviewID = UUID()
    private static let secondInterviewID = UUID()

    // MARK: - Resume

    /// Picking this file in the mock file picker parses successfully.
    static let resumeFileName = "Alex_Resume.pdf"
    /// Picking this one demonstrates the parsing-failure state.
    static let unreadableResumeFileName = "Resume_photo.heic"

    static let resume = ResumeContext(
        fileName: resumeFileName,
        highlights: [
            ResumeHighlight(
                id: "finlo",
                title: "Payment reconciliation service",
                source: "Software Engineering Intern at Finlo",
                detail: "Go service matching ~40k bank transactions a day against the ledger."
            ),
            ResumeHighlight(
                id: "campus-eats",
                title: "Campus Eats",
                source: "Personal project",
                detail: "React Native food-ordering app used by ~2,000 students."
            ),
            ResumeHighlight(
                id: "scheduler",
                title: "Course schedule optimizer",
                source: "University project",
                detail: "Python tool that builds clash-free timetables."
            )
        ],
        skills: ["Go", "Swift", "React Native", "PostgreSQL", "Redis", "Python"]
    )

    // MARK: - Question library

    static let questions: [Question] = [
        Question(id: "c-yourself", text: "Tell me about yourself.", category: .common, difficulty: .easy, role: nil, skills: [.answerStructure]),
        Question(id: "c-proud", text: "Walk me through a project you’re proud of.", category: .common, difficulty: .medium, role: nil, skills: [.answerStructure, .concreteResults]),
        Question(id: "c-why", text: "Why do you want to work here?", category: .common, difficulty: .easy, role: nil, skills: []),
        Question(id: "c-weakness", text: "What’s something you’re actively working to improve?", category: .common, difficulty: .medium, role: nil, skills: [.concreteResults]),
        Question(id: "c-future", text: "Where do you want to be in a few years?", category: .common, difficulty: .easy, role: nil, skills: []),

        Question(id: "b-disagree", text: "Tell me about a time you disagreed with a teammate.", category: .behavioral, difficulty: .medium, role: nil, skills: [.answerStructure]),
        Question(id: "b-deadline", text: "Tell me about a time you were about to miss a deadline.", category: .behavioral, difficulty: .medium, role: nil, skills: [.answerStructure, .concreteResults]),
        Question(id: "b-ownership", text: "Tell me about a problem you took ownership of when nobody else would.", category: .behavioral, difficulty: .medium, role: nil, skills: [.concreteResults]),
        Question(id: "b-feedback", text: "Tell me about feedback that changed how you work.", category: .behavioral, difficulty: .easy, role: nil, skills: [.answerStructure]),
        Question(id: "b-incomplete", text: "Tell me about a decision you made with incomplete information.", category: .behavioral, difficulty: .hard, role: nil, skills: [.tradeoffs]),

        Question(id: "swe-slow-api", text: "How would you find out why an API endpoint suddenly got slow?", category: .roleBased, difficulty: .medium, role: "Software Engineer", skills: [.answerStructure]),
        Question(id: "swe-process-thread", text: "Explain the difference between a process and a thread.", category: .roleBased, difficulty: .easy, role: "Software Engineer", skills: [.answerStructure]),
        Question(id: "swe-shortener", text: "How would you design a URL shortener?", category: .roleBased, difficulty: .hard, role: "Software Engineer", skills: [.tradeoffs]),
        Question(id: "ios-scroll", text: "A long list in your app stutters when scrolling. How do you investigate?", category: .roleBased, difficulty: .medium, role: "iOS Engineer", skills: [.answerStructure]),
        Question(id: "ios-state", text: "How would you structure state in a mid-sized SwiftUI app?", category: .roleBased, difficulty: .medium, role: "iOS Engineer", skills: [.tradeoffs]),
        Question(id: "be-retry", text: "How would you make a payments API safe to retry?", category: .roleBased, difficulty: .hard, role: "Backend Engineer", skills: [.tradeoffs]),
        Question(id: "be-queue", text: "When would you put a queue between two services instead of a direct call?", category: .roleBased, difficulty: .medium, role: "Backend Engineer", skills: [.tradeoffs]),
        Question(id: "pe-first", text: "How do you decide what to build first for a new feature?", category: .roleBased, difficulty: .medium, role: "Product Engineer", skills: [.tradeoffs, .answerStructure])
    ]

    // MARK: - Interview turns

    static let financePaymentsTurn = InterviewTurn(
        id: "t-finlo",
        question: "I see you built a payment reconciliation service at Finlo. Walk me through it.",
        origin: "About your Finlo internship",
        mockAnswer: "So it’s a Go service with a worker pool, eight workers pulling from a queue, and failed matches get retried with backoff. It matches about 40,000 bank transactions a day against our ledger…",
        followUp: .init(
            question: "You mentioned retrying failed matches. How did you make sure a transaction was never reconciled twice?",
            reason: "You mentioned retries",
            mockAnswer: "Every match writes an idempotency key in the same database transaction, so a retry sees the key and skips it."
        ),
        moment: .init(
            kind: .weakness(.answerStructure),
            note: "On the Finlo service, you described the worker pool and retries before saying what the service was for. The point arrived about 40 seconds in."
        )
    )

    static let campusEatsTurn = InterviewTurn(
        id: "t-campus-eats",
        question: "Campus Eats reached about 2,000 students. What broke first as usage grew?",
        origin: "About Campus Eats",
        mockAnswer: "Order notifications. They were sent from the client, so if a student closed the app, the restaurant could wait 30 seconds or more.",
        followUp: .init(
            question: "Why move notifications to the server rather than fixing the client?",
            reason: "You said notifications came from the client",
            mockAnswer: "The client can’t be trusted to be running. A server-side trigger on order creation fixed it for every device at once."
        ),
        moment: .init(
            kind: .strength,
            note: "On Campus Eats, the real numbers (2,000 students, 30 second delays) made the impact easy to see."
        )
    )

    static let cachingTurn = InterviewTurn(
        id: "t-caching",
        question: "Tell me about a difficult technical problem you solved.",
        mockAnswer: "We set up Redis with a five-minute TTL in front of the product endpoint, and response times dropped from about 900 milliseconds to under 100. The problem was the API slowing down under load…",
        followUp: .init(
            question: "How did you decide what data was safe to cache?",
            reason: "You mentioned caching",
            mockAnswer: "Anything that rarely changed and wasn’t user-specific. Product details yes, prices and stock no."
        ),
        moment: .init(
            kind: .weakness(.answerStructure),
            note: "In the performance answer, you started with the Redis setup before explaining what problem you were solving."
        )
    )

    static let debuggingTurn = InterviewTurn(
        id: "t-debug",
        question: "Tell me about a bug that took you a long time to find.",
        mockAnswer: "A sync job that sometimes overwrote newer data. It turned out to be a race condition between two background tasks.",
        followUp: .init(
            question: "How did you confirm that was actually the root cause?",
            reason: "You said it was a race condition",
            mockAnswer: "I added timestamps to every write, reproduced it under load, and saw the older write land second."
        ),
        moment: .init(
            kind: .strength,
            note: "You narrowed the bug down step by step. That’s exactly what interviewers want to hear."
        )
    )

    static let decisionTurn = InterviewTurn(
        id: "t-decision",
        question: "Tell me about a technical decision you’d make differently now.",
        mockAnswer: "We looked at Firebase, Supabase, and running our own Postgres, and each had pros and cons… in the end we went with Firebase, which I’d change now.",
        moment: .init(
            kind: .weakness(.answerStructure),
            note: "On the decision you’d change, you listed three options before saying which one you picked and why."
        )
    )

    static func roleTurn(for role: String) -> InterviewTurn {
        switch role {
        case "iOS Engineer":
            InterviewTurn(
                id: "t-role-ios",
                question: "A long list in your app stutters when scrolling. How do you investigate?",
                mockAnswer: "Profile it in Instruments first, then check for heavy work in row bodies and images decoded on the main thread.",
                moment: .init(kind: .strength, note: "You measured with Instruments before guessing.")
            )
        case "Backend Engineer":
            InterviewTurn(
                id: "t-role-backend",
                question: "How would you make a payments API safe to retry?",
                mockAnswer: "Require an idempotency key per request and store the result, so a repeated request returns the same response.",
                moment: .init(kind: .strength, note: "Your answer on safe retries was spot on.")
            )
        case "Product Engineer":
            InterviewTurn(
                id: "t-role-product",
                question: "How do you decide what to build first for a new feature?",
                mockAnswer: "Find the smallest version that tests the riskiest assumption, ship it to a few users, and measure.",
                moment: .init(kind: .strength, note: "You started with the riskiest assumption. Good call.")
            )
        default:
            InterviewTurn(
                id: "t-role-swe",
                question: "How would you find out why an API endpoint suddenly got slow?",
                mockAnswer: "First check whether it’s every request or a subset, then look at latency per dependency to see where the time goes.",
                moment: .init(kind: .strength, note: "You worked out where the time was going instead of guessing.")
            )
        }
    }

    static let finloDisagreementTurn = InterviewTurn(
        id: "b-finlo",
        question: "At Finlo, tell me about a time you disagreed with someone on the team.",
        origin: "About your Finlo internship",
        mockAnswer: "My lead wanted to keep the nightly batch job. I thought we should reconcile continuously. We discussed it a lot and eventually the team moved to a continuous approach.",
        followUp: .init(
            question: "Looking back, what would you do differently in how you raised it?",
            reason: "You said there was a lot of discussion",
            mockAnswer: "I’d bring data earlier, like how many mismatches the nightly batch was missing, instead of arguing from opinion."
        ),
        moment: .init(
            kind: .weakness(.concreteResults),
            note: "In the Finlo disagreement, it was unclear what you did versus what “the team” did, and the outcome had no number on it."
        )
    )

    static let disagreementTurn = InterviewTurn(
        id: "b-disagree",
        question: "Tell me about a time you disagreed with a teammate.",
        mockAnswer: "On a group project we disagreed about splitting the work by feature or by layer. We talked it through and the team went with features.",
        followUp: .init(
            question: "What would you do differently in how you raised it?",
            reason: "You said you talked it through",
            mockAnswer: "Suggest a quick trial of both instead of debating."
        ),
        moment: .init(
            kind: .weakness(.concreteResults),
            note: "In the disagreement story, “the team went with” hid what you personally did and how it turned out."
        )
    )

    static let deadlineTurn = InterviewTurn(
        id: "b-deadline",
        question: "Tell me about a time you were about to miss a deadline.",
        mockAnswer: "Two days before a hackathon demo our payments integration wasn’t working. I proposed cutting it and faking checkout, and we demoed on time.",
        followUp: .init(
            question: "How did you decide what to cut?",
            reason: "You said you cut the payments integration",
            mockAnswer: "I asked what the judges needed to see. Checkout was the end of the flow, not the point of it."
        ),
        moment: .init(kind: .strength, note: "Your deadline story was easy to follow from start to finish.")
    )

    static let setbackTurn = InterviewTurn(
        id: "b-setback",
        question: "Tell me about something that didn’t go the way you planned.",
        mockAnswer: "Our first Campus Eats launch had almost no restaurants on it, so students opened it once and left.",
        moment: .init(
            kind: .weakness(.concreteResults),
            note: "When describing the launch that didn’t go well, you didn’t say what changed afterwards or what you learned."
        )
    )

    static let feedbackTurn = InterviewTurn(
        id: "b-feedback",
        question: "Tell me about feedback that changed how you work.",
        mockAnswer: "A reviewer told me my pull requests were too big to review. Now I keep them under 300 lines and review time dropped noticeably.",
        moment: .init(kind: .strength, note: "Your feedback story showed exactly what you changed.")
    )

    static let shortenerTurn = InterviewTurn(
        id: "s-shortener",
        question: "How would you design a URL shortener?",
        mockAnswer: "Hash the long URL, take the first seven characters as the code, store it in a key-value store, and redirect on lookup.",
        followUp: .init(
            question: "How would you avoid two long URLs getting the same short code?",
            reason: "You proposed hashing the URL",
            mockAnswer: "Check for a collision on write and re-hash with a salt if the code is taken."
        ),
        moment: .init(
            kind: .weakness(.tradeoffs),
            note: "You went with hashing but didn’t mention the other option (a counter), so it looked like a guess."
        )
    )

    static let viralLinkTurn = InterviewTurn(
        id: "s-viral",
        question: "One link goes viral. How do you keep redirects fast?",
        mockAnswer: "Cache hot codes at the edge with a short TTL, so most requests never reach the database.",
        followUp: .init(
            question: "What happens if a link is deleted while it’s still cached?",
            reason: "You suggested caching hot links",
            mockAnswer: "It would keep redirecting until the TTL expires, so deletes should also purge the cache."
        ),
        moment: .init(kind: .strength, note: "You spotted the cache-invalidation problem yourself in the follow-up.")
    )

    static let finloScaleTurn = InterviewTurn(
        id: "s-finlo-scale",
        question: "How would you redesign your Finlo reconciliation service for ten times the volume?",
        origin: "About your Finlo internship",
        mockAnswer: "Partition transactions by account so workers can scale horizontally, and move matching state out of memory into Postgres.",
        moment: .init(
            kind: .weakness(.tradeoffs),
            note: "On scaling the Finlo service, you didn’t say what partitioning by account would cost you."
        )
    )

    static let analyticsTurn = InterviewTurn(
        id: "s-analytics",
        question: "How would you add click analytics without slowing down redirects?",
        mockAnswer: "Redirect first and write the click event to a queue asynchronously, then aggregate in batches.",
        moment: .init(kind: .strength, note: "You kept analytics out of the way of redirects.")
    )

    static func motivationTurn(company: String) -> InterviewTurn {
        InterviewTurn(
            id: "t-why-\(company)",
            question: "Last one from me. Why \(company)?",
            mockAnswer: "I use \(company)’s products every day, and I want to work on software at that scale.",
            moment: .init(kind: .strength, note: "You had a ready answer for why \(company).")
        )
    }

    // MARK: - Seeded history

    /// A returning candidate's history. It tells a story the Progress screen
    /// can show: overall scores rising, Answer Structure still recurring.
    static var rehearsals: [Rehearsal] {
        let calendar = Calendar.current
        func daysAgo(_ days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: .now) ?? .now }
        let upcoming = upcomingInterview
        let generic = Interview(role: "Software Engineer", experienceLevel: candidateExperienceLevel, type: .technical)
        let behavioral = Interview(role: "Software Engineer", experienceLevel: candidateExperienceLevel, type: .behavioral)

        return [
            Rehearsal(
                kind: .practice,
                date: daysAgo(1),
                practiceQuestion: questions.first { $0.id == "b-disagree" },
                practiceFocus: .answerStructure
            ),
            Rehearsal(
                kind: .interview,
                date: daysAgo(2),
                interview: upcoming,
                feedback: Feedback(
                    overall: 74,
                    communication: 72,
                    communicationNote: "Clear and calm, but long answers lost the thread.",
                    answerQuality: 78,
                    answerQualityNote: "Technically solid, with real examples to back it up.",
                    summary: "Your examples were strong, but a lot of answers started with the details before you got to the point, so they were harder to follow.",
                    strengths: ["You debugged step by step instead of guessing.", "You talked about real projects, not made-up ones."],
                    focus: .answerStructure,
                    focusEvidence: "In the caching answer, you described the Redis setup before explaining the problem it solved."
                ),
                transcript: [cachingTurn, debuggingTurn, decisionTurn].map {
                    TranscriptEntry(question: $0.question, answer: $0.mockAnswer, isFollowUp: false)
                }
            ),
            Rehearsal(
                kind: .interview,
                date: daysAgo(6),
                interview: generic,
                feedback: Feedback(
                    overall: 71,
                    communication: 70,
                    communicationNote: "Good pace, but some answers trailed off.",
                    answerQuality: 73,
                    answerQualityNote: "Right answers, but not much about why.",
                    summary: "Good instincts, but answers wandered before they got to the point.",
                    strengths: ["You were comfortable thinking out loud."],
                    focus: .answerStructure,
                    focusEvidence: "On the technical decision question, you listed every option before saying which one you chose."
                )
            ),
            Rehearsal(
                kind: .interview,
                date: daysAgo(9),
                interview: behavioral,
                feedback: Feedback(
                    overall: 64,
                    communication: 68,
                    communicationNote: "Friendly, but lots of filler words in the longer answers.",
                    answerQuality: 60,
                    answerQualityNote: "Stories lacked outcomes.",
                    summary: "Your stories were relevant, but it was often unclear what you did and how it ended.",
                    strengths: ["You had a good example for every question."],
                    focus: .concreteResults,
                    focusEvidence: "In the disagreement story, “the team decided” hid what you personally did."
                )
            )
        ]
    }
}

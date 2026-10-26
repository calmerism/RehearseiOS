import Foundation
import Supabase

/// Reads and writes the signed-in account's profile, settings, Saved
/// questions, playlists, interviews and rehearsals.
/// Row level security limits every query to the account's own rows, so no
/// query here filters by user.
nonisolated enum SyncService {
    /// Everything the app loads after signing in.
    struct Account: Sendable {
        var questions: [Question]
        var profile: Profile?
        var interviews: [Interview]
        var rehearsals: [Rehearsal]
        var playlists: [QuestionPlaylist]
    }

    /// The `profiles` row: who the candidate is, their settings, and their
    /// Saved questions in order.
    struct Profile: Codable, Sendable, Equatable {
        var fullName: String
        var targetRole: String
        var experienceLevel: String
        var flagsFillerWords: Bool
        var remindersOn: Bool
        var savedQuestionIDs: [String]?

        enum CodingKeys: String, CodingKey {
            case fullName = "full_name"
            case targetRole = "target_role"
            case experienceLevel = "experience_level"
            case flagsFillerWords = "flags_filler_words"
            case remindersOn = "reminders_on"
            case savedQuestionIDs = "saved_question_ids"
        }
    }

    // MARK: - Rows

    /// A row of `interviews`, as `supabase/schema.sql` defines it.
    private struct InterviewRow: Codable, Sendable {
        var id: UUID
        var role: String
        var company: String?
        var experienceLevel: String
        var interviewType: InterviewType
        var scheduledAt: Date?
        var durationMinutes: Int

        init(_ interview: Interview) {
            id = interview.id
            role = interview.role
            company = interview.company
            experienceLevel = interview.experienceLevel
            interviewType = interview.type
            scheduledAt = interview.date
            durationMinutes = interview.durationMinutes
        }

        var interview: Interview {
            Interview(id: id, role: role, company: company, experienceLevel: experienceLevel,
                      type: interviewType, date: scheduledAt, durationMinutes: durationMinutes)
        }

        enum CodingKeys: String, CodingKey {
            case id, role, company
            case experienceLevel = "experience_level"
            case interviewType = "interview_type"
            case scheduledAt = "scheduled_at"
            case durationMinutes = "duration_minutes"
        }
    }

    /// A row of `rehearsals`. The interview it rehearsed is kept whole as
    /// `interviewSnapshot`, since a custom mock has no row of its own; a
    /// real one is also linked by `interviewID`.
    private struct RehearsalRow: Codable, Sendable {
        var id: UUID
        var kind: Rehearsal.Kind
        var interviewID: UUID?
        var interviewSnapshot: Interview?
        var practiceQuestionID: String?
        var practiceFocus: Skill?
        var overallScore: Int?
        var feedback: Feedback?
        var transcript: [TranscriptEntry]
        var happenedAt: Date

        init(_ rehearsal: Rehearsal, realInterviewIDs: Set<UUID>) {
            id = rehearsal.id
            kind = rehearsal.kind
            interviewSnapshot = rehearsal.interview
            interviewID = rehearsal.interview.map(\.id).flatMap { realInterviewIDs.contains($0) ? $0 : nil }
            practiceQuestionID = rehearsal.practiceQuestion?.id
            practiceFocus = rehearsal.practiceFocus
            overallScore = rehearsal.feedback?.overall
            feedback = rehearsal.feedback
            transcript = rehearsal.transcript
            happenedAt = rehearsal.date
        }

        func rehearsal(questions: [Question]) -> Rehearsal {
            Rehearsal(
                id: id,
                kind: kind,
                date: happenedAt,
                interview: interviewSnapshot,
                feedback: feedback,
                transcript: transcript,
                practiceQuestion: practiceQuestionID.flatMap { id in questions.first { $0.id == id } },
                practiceFocus: practiceFocus
            )
        }

        enum CodingKeys: String, CodingKey {
            case id, kind, feedback, transcript
            case interviewID = "interview_id"
            case interviewSnapshot = "interview_snapshot"
            case practiceQuestionID = "practice_question_id"
            case practiceFocus = "practice_focus"
            case overallScore = "overall_score"
            case happenedAt = "happened_at"
        }
    }

    /// A row of the shared `questions` bank. Skills the app doesn't know
    /// are skipped rather than failing the whole load.
    private struct QuestionRow: Decodable, Sendable {
        var id: String
        var text: String
        var category: QuestionCategory
        var difficulty: Difficulty
        var role: String?
        var skills: [String]
        var area: String?

        var question: Question {
            Question(id: id, text: text, category: category, difficulty: difficulty,
                     role: role, skills: skills.compactMap(Skill.init(rawValue:)), area: area)
        }
    }

    /// A row of `playlists`.
    private struct PlaylistRow: Codable, Sendable {
        var id: UUID
        var name: String
        var questionIDs: [String]

        init(_ playlist: QuestionPlaylist) {
            id = playlist.id
            name = playlist.name
            questionIDs = playlist.questionIDs
        }

        var playlist: QuestionPlaylist {
            QuestionPlaylist(id: id, name: name, questionIDs: questionIDs)
        }

        enum CodingKeys: String, CodingKey {
            case id, name
            case questionIDs = "question_ids"
        }
    }

    // MARK: - Reading

    /// The question bank, sorted by id.
    /// Supabase returns at most 1,000 rows a request, and the bank has
    /// thousands, so it's read a page at a time until a page comes back short.
    static func loadQuestions() async throws -> [Question] {
        guard let client = Backend.client else { return [] }
        let pageSize = 1000
        var questions: [Question] = []
        while true {
            let start = questions.count
            let rows: [QuestionRow] = try await client.from("questions")
                .select("id, text, category, difficulty, role, skills, area")
                .order("id", ascending: true)
                .range(from: start, to: start + pageSize - 1)
                .execute().value
            questions += rows.map(\.question)
            if rows.count < pageSize { return questions }
        }
    }

    /// The question bank and the account's profile, playlists, interviews
    /// (soonest first) and rehearsals (newest first).
    static func load() async throws -> Account {
        guard let client = Backend.client else { return Account(questions: [], interviews: [], rehearsals: [], playlists: []) }
        async let bank = loadQuestions()
        async let profiles: [Profile] = client.from("profiles")
            .select("full_name, target_role, experience_level, flags_filler_words, reminders_on, saved_question_ids")
            .limit(1)
            .execute().value
        async let playlistRows: [PlaylistRow] = client.from("playlists")
            .select("id, name, question_ids")
            .order("created_at", ascending: true)
            .execute().value
        async let interviewRows: [InterviewRow] = client.from("interviews")
            .select("id, role, company, experience_level, interview_type, scheduled_at, duration_minutes")
            .order("scheduled_at", ascending: true)
            .execute().value
        async let rehearsalRows: [RehearsalRow] = client.from("rehearsals")
            .select("id, kind, interview_id, interview_snapshot, practice_question_id, practice_focus, overall_score, feedback, transcript, happened_at")
            .order("happened_at", ascending: false)
            .execute().value
        let questions = try await bank
        return try await Account(
            questions: questions,
            profile: profiles.first,
            interviews: interviewRows.map(\.interview),
            rehearsals: rehearsalRows.map { $0.rehearsal(questions: questions) },
            playlists: playlistRows.map(\.playlist)
        )
    }

    // MARK: - Writing

    /// Adds the interview, or updates it if it's already saved.
    static func save(_ interview: Interview) async throws {
        guard let client = Backend.client else { return }
        try await client.from("interviews").upsert(InterviewRow(interview)).execute()
    }

    /// Saves the profile and settings. The row exists from sign-up.
    static func save(_ profile: Profile, for userID: UUID) async throws {
        guard let client = Backend.client else { return }
        try await client.from("profiles").update(profile).eq("id", value: userID).execute()
    }

    static func save(_ playlist: QuestionPlaylist) async throws {
        guard let client = Backend.client else { return }
        try await client.from("playlists").upsert(PlaylistRow(playlist)).execute()
    }

    static func deletePlaylist(id: QuestionPlaylist.ID) async throws {
        guard let client = Backend.client else { return }
        try await client.from("playlists").delete().eq("id", value: id).execute()
    }

    static func deleteInterview(id: Interview.ID) async throws {
        guard let client = Backend.client else { return }
        try await client.from("interviews").delete().eq("id", value: id).execute()
    }

    /// Saves a finished mock interview or practice answer. `realInterviewIDs`
    /// are the account's saved interviews, so a rehearsal of one links to it.
    static func save(_ rehearsal: Rehearsal, realInterviewIDs: Set<UUID>) async throws {
        guard let client = Backend.client else { return }
        try await client.from("rehearsals")
            .upsert(RehearsalRow(rehearsal, realInterviewIDs: realInterviewIDs))
            .execute()
    }
}

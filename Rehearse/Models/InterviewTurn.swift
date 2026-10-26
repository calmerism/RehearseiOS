import Foundation

/// One topic in a mock interview: a main question and, sometimes, a follow-up
/// that the (mocked) answer opens up. Everything an AI would produce later —
/// the follow-up, the transcript, the evaluation — is predefined here.
struct InterviewTurn: Identifiable, Hashable {
    let id: String
    let question: String
    /// Where the question came from, e.g. "About your Finlo internship".
    var origin: String?
    /// The answer the prototype pretends it heard, shown as a transcript.
    let mockAnswer: String
    var followUp: FollowUp?
    /// The predefined evaluation of this answer, used to build feedback.
    let moment: Moment

    struct FollowUp: Hashable {
        let question: String
        /// Ties the follow-up to the previous answer, e.g. "You mentioned retries".
        let reason: String
        let mockAnswer: String
    }

    struct Moment: Hashable, nonisolated Codable {
        enum Kind: Hashable, nonisolated Codable {
            case strength
            case weakness(Skill)
        }

        let kind: Kind
        let note: String
        /// The same, in a few words, for the Insights list.
        var short: String? = nil

        var headline: String { short ?? note }
    }
}

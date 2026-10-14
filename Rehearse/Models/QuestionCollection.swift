import Foundation

/// A list of questions the candidate made, like a playlist in Music.
struct QuestionPlaylist: Identifiable, Hashable {
    var id = UUID()
    var name: String
    /// In the order they were added.
    var questionIDs: [Question.ID] = []
}

/// One of the groups at the top of the library: Saved, which holds the
/// questions the candidate saved along with the ones nearly every interview
/// includes, or one of their playlists.
enum QuestionCollection: Hashable {
    case saved
    case playlist(QuestionPlaylist.ID)
}

import Foundation

/// What Rehearse understood from the candidate's resume. In the product this
/// would come from a parser; in the prototype it is predefined.
struct ResumeContext: Hashable {
    var fileName: String
    var highlights: [ResumeHighlight]
    var skills: [String]
}

/// A project or role the interviewer can ask about.
struct ResumeHighlight: Identifiable, Hashable {
    let id: String
    let title: String
    let source: String
    let detail: String
}

enum ResumeStatus: Equatable {
    case none
    case parsing(fileName: String)
    case ready(ResumeContext)
    case failed(fileName: String, reason: String)

    var context: ResumeContext? {
        if case .ready(let context) = self { return context }
        return nil
    }
}

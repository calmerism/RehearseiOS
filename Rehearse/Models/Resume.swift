import Foundation

/// What Rehearse understood from the candidate's resume. In the product this
/// would come from a parser; in the prototype it is predefined.
struct ResumeContext: Hashable {
    var fileName: String
    var highlights: [ResumeHighlight]
    var skills: [String]
    /// "B.Tech Computer Science, City Engineering College, 2027", when known.
    var education: String? = nil
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

// MARK: - Tailored versions

/// The candidate's resume rewritten for one job. Each suggestion leads with a
/// different story, so the candidate picks an angle rather than a near copy.
/// In the product this would come from a model; in the prototype it is written
/// out in `MockData`.
struct ResumeVersion: Identifiable, Hashable {
    let id = UUID()
    let company: String?
    let role: String
    /// The story it opens with: "Campus Eats", or "Balanced" for none.
    let lead: String
    /// Why this angle suits the job.
    let summary: String
    let context: ResumeContext
    let changes: [ResumeChange]
    /// What the job asks for that the resume doesn't show.
    let gaps: [ResumeGap]
    /// The upcoming interview this version is for. Its mock uses it.
    var interviewID: Interview.ID?

    /// "Apple", or the role when there's no company.
    var target: String { company ?? role }

    /// "Leads with Campus Eats"
    var angle: String { lead == "Balanced" ? lead : "Leads with \(lead)" }

    /// What changed on one project.
    func changes(to highlightID: ResumeHighlight.ID) -> [ResumeChange] {
        changes.filter { $0.highlightID == highlightID }
    }

    /// Projects left out of this version.
    var cuts: [ResumeChange] { changes.filter { $0.kind == .cut } }

    /// Changes that aren't about one project, such as skill order.
    var otherChanges: [ResumeChange] { changes.filter { $0.highlightID == nil } }
}

/// One edit from the original resume, shown so the candidate can trust it.
struct ResumeChange: Identifiable, Hashable {
    enum Kind: String {
        case movedUp = "Moved Up"
        case rewritten = "Rewritten"
        case cut = "Cut"

        var symbol: String {
            switch self {
            case .movedUp: "arrow.up"
            case .rewritten: "pencil"
            case .cut: "minus"
            }
        }
    }

    let id = UUID()
    let kind: Kind
    /// The project it changed, if it's about one.
    var highlightID: ResumeHighlight.ID?
    let title: String
    /// The new wording for a rewrite, or the reason for a move or cut.
    let detail: String
    /// The original wording, for a rewrite.
    var before: String?
}

/// Something the job asks for that the resume doesn't show, with a library
/// question to rehearse it, since the interviewer is likely to probe it.
struct ResumeGap: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
    let questionID: Question.ID?
}

/// Which resume a mock interview uses.
enum ResumeChoice: Hashable {
    /// The resume on the candidate's Profile.
    case original
    case tailored(ResumeVersion.ID)
    /// A file added during setup, for this interview only.
    case uploaded(ResumeContext)
}

// MARK: - Building one

/// What the candidate tells the resume builder: the basics, and each
/// project or job in their own words, in any language. The resume's lines
/// are written from these notes, in English.
struct ResumeDraft: Hashable {
    var name: String
    var email: String
    var role: String
    var college: String
    var degree: String
    var graduationYear: Int
    var projects: [ProjectNote]
    var skills: String

    /// The written resume: each project's notes turned into one line.
    func written() -> ResumeContext {
        let highlights = projects.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }.map { project in
            ResumeHighlight(id: project.id, title: project.title, source: project.place, detail: project.writtenLine)
        }
        let skillList = skills.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let fileName = name.split(separator: " ").joined(separator: "_") + "_Resume.pdf"
        return ResumeContext(fileName: fileName, highlights: highlights, skills: skillList, education: "\(degree), \(college), \(graduationYear)")
    }
}

/// One project or job, as the candidate described it.
struct ProjectNote: Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    /// "Internship at Finlo", "Personal project".
    var place: String
    /// What they did, the way they'd say it.
    var notes: String

    /// The resume line written from the notes. In the product a language
    /// model writes it; the prototype has the sample projects' lines written
    /// out and tidies anything else.
    var writtenLine: String {
        if let line = MockData.writtenLines[id], notes == MockData.sampleNotes[id] { return line }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "" }
        let line = first.uppercased() + trimmed.dropFirst()
        return line.hasSuffix(".") ? line : line + "."
    }
}

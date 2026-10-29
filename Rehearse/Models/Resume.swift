import Foundation

/// What Rehearse understood from the candidate's resume. In the product this
/// would come from a parser; in the prototype it is predefined.
struct ResumeContext: Hashable {
    var fileName: String
    /// The candidate's name as written on the page, when it's known.
    var name: String? = nil
    var highlights: [ResumeHighlight]
    var skills: [String]
    /// "B.Tech Computer Science, City Engineering College, 2027", when known.
    var education: String? = nil
    /// The file's own text, when it was read from a real file.
    var text: String? = nil
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
    var createdOn: Date = .now

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

/// A resume that was on the Profile before the current one, kept so it can
/// still be used for a mock.
struct PastResume: Identifiable, Hashable {
    let id = UUID()
    let context: ResumeContext
    let uploadedOn: Date
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

    /// Nothing filled in yet, graduating next year.
    static var blank: ResumeDraft {
        ResumeDraft(name: "", email: "", role: "", college: "", degree: "",
                    graduationYear: Calendar.current.component(.year, from: .now) + 1, projects: [], skills: "")
    }

    /// The written resume: each project's notes turned into one line.
    func written() -> ResumeContext {
        let highlights = projects.filter(\.isComplete).map { project in
            ResumeHighlight(id: project.id, title: project.title, source: project.kind.rawValue, detail: project.writtenLine)
        }
        let skillList = skills.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        // Not a file, so no file extension: just whose it is.
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let fileName = trimmedName.isEmpty ? "Your Resume" : "\(trimmedName)’s Resume"
        return ResumeContext(fileName: fileName, name: trimmedName.isEmpty ? nil : trimmedName, highlights: highlights, skills: skillList, education: "\(degree), \(college), \(graduationYear)")
    }
}

/// What kind of project it was, the resume line's source.
enum ProjectKind: String, CaseIterable, Identifiable, Hashable {
    case personal = "Personal Project"
    case academic = "Academic Project"
    case internship = "Internship"
    case work = "Work Project"
    case hackathon = "Hackathon"
    case openSource = "Open Source"
    case freelance = "Freelance"
    case other = "Other"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .personal: "person"
        case .academic: "graduationcap"
        case .internship: "briefcase"
        case .work: "building.2"
        case .hackathon: "bolt"
        case .openSource: "chevron.left.forwardslash.chevron.right"
        case .freelance: "laptopcomputer"
        case .other: "folder"
        }
    }
}

extension ResumeDraft {
    /// The notes back from a built resume, when its own notes weren't kept:
    /// each project's line becomes its description, so the page can be
    /// edited rather than only looked at.
    init(context: ResumeContext, role: String) {
        let parts = (context.education ?? "").components(separatedBy: ", ")
        self.init(
            name: context.name ?? "",
            email: "",
            role: role,
            college: parts.count > 1 ? parts[1] : "",
            degree: parts.first ?? "",
            graduationYear: parts.count > 2 ? Int(parts[2]) ?? Calendar.current.component(.year, from: .now) + 1 : Calendar.current.component(.year, from: .now) + 1,
            projects: context.highlights.map { ProjectNote(id: $0.id, title: $0.title, kind: ProjectKind(describing: $0.source), notes: $0.detail) },
            skills: context.skills.joined(separator: ", ")
        )
    }

}

extension ProjectKind {
    /// The kind a resume line's source names, such as "Internship at
    /// Finlo" or "University project".
    init(describing source: String) {
        if let exact = ProjectKind(rawValue: source) { self = exact; return }
        let text = source.lowercased()
        let matches: [(String, ProjectKind)] = [
            ("intern", .internship), ("personal", .personal), ("hackathon", .hackathon),
            ("open source", .openSource), ("freelance", .freelance),
            ("university", .academic), ("college", .academic), ("academic", .academic), ("course", .academic),
            ("work", .work), ("job", .work),
        ]
        self = matches.first { text.contains($0.0) }?.1 ?? .other
    }
}

/// One project or job, as the candidate described it, field by field.
struct ProjectNote: Identifiable, Hashable {
    var id = UUID().uuidString
    var title: String
    var kind: ProjectKind = .personal
    /// What they did on it: "Built the backend and the payments flow".
    var role = ""
    /// Everyone who worked on it, the candidate included.
    var teamSize = 1
    /// What the project is, the way they'd say it, in any language.
    var notes: String
    var features = ""
    /// Results, impact and what they learned.
    var outcomes = ""

    /// A project needs a name and a description before a line can be
    /// written from it.
    var isComplete: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Nothing typed in it yet.
    var isBlank: Bool {
        [title, role, notes, features, outcomes].allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// The resume line written from the notes. In the product a language
    /// model writes it; the prototype has the sample projects' lines written
    /// out and tidies anything else.
    var writtenLine: String {
        if let line = MockData.writtenLines[id], notes == MockData.sampleNotes[id] { return line }
        return [notes, outcomes].map(Self.sentence).filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func sentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "" }
        let line = first.uppercased() + trimmed.dropFirst()
        return line.hasSuffix(".") ? line : line + "."
    }
}

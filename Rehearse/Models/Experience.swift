import Foundation

/// Where the candidate is in their career, asked in profile setup. Each
/// stage asks only what fits it: a student their year of study, a working
/// professional their years of work, a recent graduate nothing more.
enum CareerStage: String, CaseIterable, Identifiable {
    case student, graduate, professional

    var id: Self { self }

    var title: String {
        switch self {
        case .student: "Student"
        case .graduate: "Recent Graduate"
        case .professional: "Working Professional"
        }
    }

    var detail: String {
        switch self {
        case .student: "Studying, aiming for an internship or first job"
        case .graduate: "Finished studying in the last year"
        case .professional: "Working, aiming for your next role"
        }
    }

    var symbol: String {
        switch self {
        case .student: "book.closed"
        case .graduate: "graduationcap"
        case .professional: "briefcase"
        }
    }
}

/// The experience level as it's saved and shown on Profile:
/// "Student, 2nd year", "New Graduate", "5 years experience".
enum Experience {
    static let studyYears = 1...4
    static let workYears = 0...20

    /// "1st year" to "4th year or later".
    static func studyYearText(_ year: Int) -> String {
        switch year {
        case 1: "1st year"
        case 2: "2nd year"
        case 3: "3rd year"
        default: "4th year or later"
        }
    }

    /// "Less than 1 year", "1 year", "20+ years".
    static func workYearsText(_ years: Int) -> String {
        switch years {
        case ..<1: "Less than 1 year"
        case 1: "1 year"
        case workYears.upperBound...: "\(workYears.upperBound)+ years"
        default: "\(years) years"
        }
    }

    static func level(stage: CareerStage, studyYear: Int, workYears: Int) -> String {
        switch stage {
        case .student: "Student, \(studyYearText(studyYear))"
        case .graduate: "New Graduate"
        case .professional: workYears < 1 ? "Under 1 year experience" : "\(workYearsText(workYears)) experience"
        }
    }
}

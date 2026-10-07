import Foundation

/// The local profile used throughout the prototype. It deliberately contains
/// only presentation data; authentication and account persistence are outside
/// the scope of Rehearse V1.
struct UserProfile: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var firstName: String
    var academicYear: String
    var fieldOfStudy: String

    init(
        id: UUID = UUID(),
        firstName: String,
        academicYear: String,
        fieldOfStudy: String
    ) {
        self.id = id
        self.firstName = firstName
        self.academicYear = academicYear
        self.fieldOfStudy = fieldOfStudy
    }

    var educationSummary: String {
        "\(academicYear) · \(fieldOfStudy)"
    }
}

import SwiftUI

/// A saved tailored resume: the angle it takes, which interview uses it, what
/// changed and what to rehearse that it doesn't show.
struct ResumeVersionView: View {
    let versionID: ResumeVersion.ID

    @Environment(AppState.self) private var appState
    @State private var isConfirmingDeletion = false

    var body: some View {
        if let version = appState.tailoredResume(id: versionID) {
            List {
                TabHeaderSection()
                Section {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        Text(version.company.map { "\(version.role) at \($0)" } ?? version.role)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(version.angle)
                            .cardTitleStyle()
                        Text(version.summary)
                            .foregroundStyle(.secondary)
                            .padding(.top, AppTheme.Spacing.xxs)
                    }
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .accessibilityElement(children: .combine)
                    LabeledContent("File", value: version.context.fileName)
                }

                if !appState.upcomingInterviews.isEmpty {
                    Section {
                        Picker("Use For", selection: interviewBinding) {
                            Text("No Interview").tag(Interview.ID?.none)
                            ForEach(appState.upcomingInterviews) { interview in
                                Text(interview.company ?? interview.role).tag(Interview.ID?.some(interview.id))
                            }
                        }
                    } footer: {
                        Text("Mock interviews for this interview start with this version.")
                    }
                }

                ResumeVersionDetails(version: version)

                Section {
                    Button("Delete Version", role: .destructive) { isConfirmingDeletion = true }
                }
            }
            .appListStyle()
            .scrollingTitle("For \(version.target)")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Delete this version?", isPresented: $isConfirmingDeletion, titleVisibility: .visible) {
                Button("Delete Version", role: .destructive) { appState.removeTailoredResume(id: versionID) }
            } message: {
                Text("Your original resume stays as it is.")
            }
        }
    }

    private var interviewBinding: Binding<Interview.ID?> {
        Binding(
            get: { appState.tailoredResume(id: versionID)?.interviewID },
            set: { appState.linkTailoredResume(id: versionID, to: $0) }
        )
    }
}

#Preview {
    let appState = AppState()
    appState.resume = .ready(MockData.resume)
    let version = MockData.tailoredVersions(company: "Apple", role: "Software Engineer")[0]
    appState.saveTailoredResume(version)
    return NavigationStack { ResumeVersionView(versionID: version.id) }
        .environment(appState)
}

import SwiftUI

/// The candidate, how ready they are, what they're preparing for and how
/// feedback should feel. Laid out like Settings: grouped rows, one job each.
struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var isConfirmingSignOut = false

    var body: some View {
        @Bindable var appState = appState

        List {
            TabHeaderSection()

            Section {
                header
            }

            Section {
                NavigationLink(value: Route.progress) {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
            }

            Section {
                NavigationLink(value: Route.resume) {
                    LabeledContent {
                        Text(resumeStatus)
                    } label: {
                        Label("Resume", systemImage: "doc.text")
                    }
                }
                LabeledContent {
                    Text(appState.experienceLevel)
                } label: {
                    Label("Experience Level", systemImage: "graduationcap")
                }
            } footer: {
                Text("Questions are picked for your experience level and the projects on your resume.")
            }

            Section {
                Toggle(isOn: $appState.flagsFillerWords) {
                    Label("Flag Filler Words", systemImage: "waveform.badge.exclamationmark")
                }
            } header: {
                Text("Feedback")
                .listHeadingInset()
            } footer: {
                Text("Filler words are “um,” “like” and “you know.”")
            }

            Section {
                Toggle(isOn: $appState.remindersOn) {
                    Label("Interview Reminders", systemImage: "bell.badge")
                }
                Link(destination: URL(string: "https://support.apple.com")!) {
                    Label("Help & Support", systemImage: "questionmark.circle")
                }
            } header: {
                Text("Settings")
                .listHeadingInset()
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    isConfirmingSignOut = true
                }
                .frame(maxWidth: .infinity)
            }
        }
        .appListStyle()
        .screenTitle("Profile")
        .confirmationDialog("Sign out of Rehearse?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) { appState.load(.newUser) }
        } message: {
            Text("In this prototype, signing out starts over as a new candidate.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // The same placeholder as Home's header, larger.
            ProfileAvatar(size: 64)
            // Just the name: the interviews and level are listed below.
            Text(appState.candidateName)
                .cardTitleStyle()
        }
        .padding(.vertical, AppTheme.Spacing.xxs)
        .accessibilityElement(children: .combine)
    }

    private var resumeStatus: String {
        switch appState.resume {
        case .none: "Not added"
        case .parsing: "Reading…"
        case .ready: "Added"
        case .failed: "Couldn’t read"
        }
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .environment(AppState())
}

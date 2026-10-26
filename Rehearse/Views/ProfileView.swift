import SwiftUI

/// The candidate, how ready they are, what they're preparing for and how
/// feedback should feel. Laid out like Settings: grouped rows, one job each.
struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var isConfirmingSignOut = false
    @State private var isConfirmingDelete = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var notificationsBlocked = false
    @Environment(\.openURL) private var openURL

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
                Text("Counts “um,” “like” and “you know” in your answers and scores them under Communication.")
            }

            Section {
                Toggle(isOn: remindersBinding) {
                    Label("Interview Reminders", systemImage: "bell.badge")
                }
                Link(destination: URL(string: "https://support.apple.com")!) {
                    Label("Help & Support", systemImage: "questionmark.circle")
                }
            } header: {
                Text("Settings")
                .listHeadingInset()
            } footer: {
                Text("Reminders come 3 days, 1 day and 2 hours before each upcoming interview.")
            }

            Section {
                Button("Sign Out", role: .destructive) {
                    isConfirmingSignOut = true
                }
                .frame(maxWidth: .infinity)
            }

            // Only a real account can be deleted, as the App Store requires.
            if appState.account != nil {
                Section {
                    Button(role: .destructive) {
                        isConfirmingDelete = true
                    } label: {
                        if isDeleting {
                            ProgressView()
                        } else {
                            Text("Delete Account")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(isDeleting)
                } footer: {
                    Text("Deletes your account and everything in it: interviews, scores, resumes and playlists. This can’t be undone.")
                }
            }

            Section {
                Link(destination: URL(string: "https://github.com/open-interview/open-interview")!) {
                    Label("Question Bank", systemImage: "books.vertical")
                }
            } header: {
                Text("About")
                    .listHeadingInset()
            } footer: {
                Text("Practice questions come from the open-interview project, used under the MIT licence.")
            }
        }
        .appListStyle()
        .screenTitle("Profile")
        .confirmationDialog("Sign out of Rehearse?", isPresented: $isConfirmingSignOut, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                if Backend.isConfigured { appState.signOut() } else { appState.load(.newUser) }
            }
        } message: {
            Text(Backend.isConfigured ? "You’ll need to log in again to see your interviews." : "In this prototype, signing out starts over as a new candidate.")
        }
        .confirmationDialog("Delete your account?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) {
                isDeleting = true
                Task {
                    do {
                        try await appState.deleteAccount()
                    } catch {
                        deleteError = error.localizedDescription
                    }
                    isDeleting = false
                }
            }
        } message: {
            Text("Your interviews, scores, resumes and playlists will be deleted for good.")
        }
        .alert("Notifications Are Off", isPresented: $notificationsBlocked) {
            Button("Open Settings") { openURL(URL(string: UIApplication.openSettingsURLString)!) }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("Allow notifications for Rehearse in Settings to get reminders before your interviews.")
        }
        .alert("Couldn’t Delete Your Account", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    /// Turning reminders on asks iOS first; if notifications are blocked,
    /// the switch stays off and Settings is offered instead.
    private var remindersBinding: Binding<Bool> {
        Binding {
            appState.remindersOn
        } set: { on in
            guard on else {
                appState.remindersOn = false
                return
            }
            Task {
                let allowed = await InterviewReminders.requestPermission()
                appState.remindersOn = allowed
                notificationsBlocked = !allowed
            }
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

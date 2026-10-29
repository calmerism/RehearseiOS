import SwiftUI
import UserNotifications

@main
struct RehearseApp: App {
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsLaunchReveal = true

    init() {
        // Set before launch finishes, so a tapped reminder that opens the
        // app is still delivered.
        UNUserNotificationCenter.current().delegate = ReminderTapHandler.shared
    }

    private var remindersActive: Bool {
        appState.remindersOn && appState.isSignedIn && !appState.needsProfileSetup
    }

    var body: some Scene {
        WindowGroup {
            // Straight to an account, then the profile a new account sets
            // up, then the app.
            Group {
                if !appState.isSignedIn {
                    LoginView()
                        .transition(.opacity)
                } else if appState.needsProfileSetup {
                    ProfileSetupView()
                        .transition(.opacity)
                } else {
                    RootView()
                        .transition(.opacity)
                }
            }
            .phoneWidth()
            .environment(appState)
            .tint(AppTheme.brand)
            // The launch screen's suit on black, lifting away to the app.
            .overlay {
                if showsLaunchReveal {
                    LaunchReveal { showsLaunchReveal = false }
                }
            }
            // Widgets show what Home shows, and open where they were tapped.
            .onAppear { appState.publishWidgetSnapshot() }
            .onChange(of: appState.widgetSnapshot) { appState.publishWidgetSnapshot() }
            .onOpenURL { appState.open($0) }
            // Reminders open their interview once there's an account to open
            // it in.
            .task(id: appState.isSignedIn) {
                if appState.isSignedIn { ReminderTapHandler.shared.open = { appState.open($0) } }
            }
            // Interview Reminders follow the upcoming interviews. Not during
            // profile setup, which asks about notifications in its own step
            // rather than as soon as an interview is added.
            .task(id: ReminderPlan(on: remindersActive, interviews: appState.upcomingInterviews)) {
                await InterviewReminders.update(for: appState.upcomingInterviews, on: remindersActive)
                #if DEBUG
                if appState.remindersOn { await InterviewReminders.scheduleTestReminderIfAsked(for: appState.upcomingInterviews) }
                await InterviewReminders.logScheduledIfAsked()
                #endif
            }
            // A real account from last time stays signed in.
            .task { await appState.restoreAccount() }
            // Saves that failed get another go when the app is back in front.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await appState.retryUnsavedChanges() } }
            }
            // Profile, settings and Saved questions save as they change.
            .onChange(of: appState.profileSnapshot) { appState.syncProfile() }
        }
    }
}

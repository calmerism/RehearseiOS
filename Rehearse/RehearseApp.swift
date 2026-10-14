import SwiftUI

@main
struct RehearseApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            // First launch: a welcome, then an account, then the profile a
            // new account sets up, then the app.
            Group {
                if !appState.isSignedIn {
                    if appState.hasSeenWelcome {
                        LoginView()
                            .transition(.opacity)
                    } else {
                        WelcomeView()
                            .transition(.opacity)
                    }
                } else if appState.needsProfileSetup {
                    ProfileSetupView()
                        .transition(.opacity)
                } else {
                    RootView()
                        .transition(.opacity)
                }
            }
            .environment(appState)
            .tint(AppTheme.brand)
        }
    }
}

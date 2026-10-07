import SwiftUI

@main
struct RehearseApp: App {
    @State private var appState = AppState()

    init() {
        AppFont.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .tint(AppTheme.ink)
                .font(.app(.body))
                // Jakarta sets tight; a little leading keeps wrapped lines readable.
                .lineSpacing(2)
        }
    }
}

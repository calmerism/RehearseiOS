import SwiftUI

/// A system tab bar: Home, plus Progress, the library and a custom mock
/// interview. Each tab has its own navigation stack. The live interview and
/// practice answers are presented full screen because they are focused tasks
/// that must be explicitly finished or left.
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
            Tab(value: .home) {
                stack(path: $appState.path) { HomeView() }
            } label: {
                tabIcon("Home", systemImage: "house")
            }
            Tab(value: .progress) {
                stack(path: $appState.progressPath) { ProgressOverviewView() }
            } label: {
                tabIcon("Progress", systemImage: "chart.bar")
            }
            Tab(value: .library) {
                stack(path: $appState.libraryPath) { QuestionLibraryView(initialFocus: nil) }
            } label: {
                tabIcon("Library", systemImage: "text.book.closed")
            }
            Tab(value: .mockInterview) {
                stack(path: $appState.mockInterviewPath) { InterviewSetupView(mode: .custom) }
            } label: {
                tabIcon("Rehearse", systemImage: "person.wave.2")
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .fullScreenCover(item: $appState.activeInterview) { session in
            LiveInterviewView(session: session)
        }
        .fullScreenCover(item: $appState.activePractice) { question in
            PracticeSessionView(question: question, focus: appState.focus(for: question))
        }
        .sheet(item: $appState.interviewEditor) { request in
            UpcomingInterviewEditor(interview: request.interview)
        }
    }

    /// Icons only, as in the reference; the name is still read by VoiceOver.
    private func tabIcon(_ title: String, systemImage: String) -> some View {
        Image(systemName: systemImage)
            .accessibilityLabel(title)
    }

    private func stack<Root: View>(path: Binding<[Route]>, @ViewBuilder root: () -> Root) -> some View {
        NavigationStack(path: path) {
            root()
                .navigationDestination(for: Route.self, destination: destination)
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .setup(let mode): InterviewSetupView(mode: mode)
        case .resume: ResumeView()
        case .library(let focus): QuestionLibraryView(initialFocus: focus)
        case .question(let question): QuestionDetailView(question: question)
        case .practice(let question): PracticeView(initialQuestion: question)
        case .history: HistoryView()
        case .rehearsal(let id): RehearsalDetailView(rehearsalID: id)
        case .progress: ProgressOverviewView()
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
}

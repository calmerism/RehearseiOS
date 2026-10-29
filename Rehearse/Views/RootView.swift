import SwiftUI

/// Four tabs in the system tab bar, which iOS draws in Liquid Glass: Home,
/// Library (the questions), Resume and Progress. Profile opens from
/// Home's header. A mock interview starts from Home, and
/// Practice from Home and Your Score. Each tab has its own navigation
/// stack. The live interview and practice answers are presented full
/// screen because they are focused tasks that must be explicitly finished
/// or left.
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Tab(tab.title, systemImage: tab.symbol, value: tab) {
                    Group {
                        switch tab {
                        case .home: stack(path: $appState.path) { HomeView() }
                        case .questions: stack(path: $appState.questionsPath) { QuestionLibraryView(initialFocus: nil) }
                        case .resume: stack(path: $appState.resumePath) { ResumeView() }
                        case .progress: stack(path: $appState.progressPath) { ProgressOverviewView() }
                        }
                    }
                    // The page fades out behind the tab bar, which iOS
                    // draws above it.
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            stops: [
                                .init(color: AppTheme.background.opacity(0), location: 0),
                                .init(color: AppTheme.background.opacity(0.85), location: 0.6),
                                .init(color: AppTheme.background, location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 120)
                        .ignoresSafeArea(edges: .bottom)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
                }
            }
        }
        .tint(AppTheme.brand)
        .sheet(item: $appState.interviewSetup, onDismiss: appState.interviewSetupDismissed) { request in
            NavigationStack {
                InterviewSetupView(mode: request.mode)
            }
            .phoneWidth()
        }
        .fullScreenCover(item: $appState.activeInterview) { session in
            LiveInterviewView(session: session)
                .phoneWidth()
        }
        .fullScreenCover(item: $appState.activePractice) { question in
            PracticeSessionView(question: question, focus: appState.focus(for: question))
                .phoneWidth()
        }
        .sheet(item: $appState.interviewEditor) { request in
            UpcomingInterviewEditor(interview: request.interview)
                .phoneWidth()
        }
    }

    private func stack<Root: View>(path: Binding<[Route]>, @ViewBuilder root: () -> Root) -> some View {
        NavigationStack(path: path) {
            root()
                .environment(\.isTabRoot, true)
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                        .environment(\.isTabRoot, false)
                        .toolbarTitleDisplayMode(.inline)
                }
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .resumeVersion(let id): ResumeVersionView(versionID: id)
        case .library(let focus): QuestionLibraryView(initialFocus: focus)
        case .question(let question): QuestionDetailView(question: question)
        case .collection(let collection): QuestionCollectionView(collection: collection)
        case .rehearsal(let id): RehearsalDetailView(rehearsalID: id)
        case .progress: ProgressOverviewView()
        case .history: HistoryView()
        case .practice: PracticeView()
        case .upcoming: UpcomingInterviewsView()
        case .profile: ProfileView()
        }
    }
}

private extension AppTab {
    var title: String {
        switch self {
        case .home: "Home"
        case .questions: "Library"
        case .resume: "Resume"
        case .progress: "Progress"
        }
    }

    /// Filled, as the system tab bar draws its symbols.
    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .questions: "books.vertical.fill"
        case .resume: "doc.text.fill"
        case .progress: "chart.line.uptrend.xyaxis"
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
}

extension View {
    /// Only the left edge swipes back on this page, never the middle of it,
    /// so it never slides sideways while it's being read. Other pages keep
    /// iOS 26's swipe back from anywhere.
    func edgeSwipeBackOnly() -> some View {
        background(EdgeSwipeBackOnly())
    }
}

/// Turns off iOS 26's swipe back from anywhere while its page is showing,
/// and turns it back on when the page goes, keeping the left-edge swipe.
private struct EdgeSwipeBackOnly: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        private weak var stack: UINavigationController?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            stack = navigationController
            stack?.interactiveContentPopGestureRecognizer?.isEnabled = false
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            stack?.interactiveContentPopGestureRecognizer?.isEnabled = true
        }
    }
}

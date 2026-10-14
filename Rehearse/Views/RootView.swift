import SwiftUI

/// Two tabs, Home and Library, in the dock, with the mock interview's
/// button between them. The interview is the app's main action, so it gets
/// the accent disc rather than a tab; it opens the setup sheet over whatever
/// tab is showing. Profile opens from Home's header, and Practice from Home
/// and Your Score. Each tab has
/// its own navigation stack. The live interview and practice answers are
/// presented full screen because they are focused tasks that must be
/// explicitly finished or left.
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        // Every tab stays alive underneath, so each keeps its place and stack.
        ZStack {
            tab(.home) { stack(path: $appState.path) { HomeView() } }
            tab(.questions) { stack(path: $appState.questionsPath) { QuestionLibraryView(initialFocus: nil) } }
        }
        // The pages' own background behind them, so a page fading in or out
        // shows the same gray rather than the window's white.
        .background(AppTheme.background.ignoresSafeArea())
        // Like the system tab bar, the dock stays put under the keyboard.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // Pages blur and fade out under the status bar and behind the dock,
        // so content never meets either with a hard edge.
        .overlay {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    EdgeFade(edge: .top)
                        .frame(height: proxy.safeAreaInsets.top + EdgeFade.reach)
                    Spacer(minLength: 0)
                    EdgeFade(edge: .bottom)
                        .frame(height: proxy.safeAreaInsets.bottom + Dock.height(withButton: true) + EdgeFade.reach)
                }
                .ignoresSafeArea()
            }
            .ignoresSafeArea(.keyboard)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .overlay(alignment: .bottom) {
            Dock(selection: $appState.selectedTab, showsMockInterview: showsMockInterviewButton) {
                appState.setUpInterview(.custom)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .sheet(item: $appState.interviewSetup, onDismiss: appState.interviewSetupDismissed) { request in
            NavigationStack {
                InterviewSetupView(mode: request.mode)
            }
        }
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

    private func tab<Content: View>(_ value: AppTab, @ViewBuilder content: () -> Content) -> some View {
        let isSelected = appState.selectedTab == value
        // A fade-through: the old page is gone in a blink, then the new one
        // fades in and settles from a touch smaller. The two are never
        // see-through at once, so the switch never looks washed out.
        return content()
            .animation(isSelected ? .smooth(duration: 0.32).delay(0.06) : nil) {
                $0.scaleEffect(isSelected ? 1 : 0.98)
            }
            .animation(isSelected ? .easeOut(duration: 0.18).delay(0.06) : .easeIn(duration: 0.06)) {
                $0.opacity(isSelected ? 1 : 0)
            }
            .allowsHitTesting(isSelected)
            .accessibilityHidden(!isSelected)
    }

    /// Home's own page has the Take a Mock Interview card, so the dock leaves
    /// out its mock interview button there; every other page has it.
    private var showsMockInterviewButton: Bool {
        !(appState.selectedTab == .home && appState.path.isEmpty)
    }

    private func stack<Root: View>(path: Binding<[Route]>, rootHasButton: Bool = true, @ViewBuilder root: () -> Root) -> some View {
        NavigationStack(path: path) {
            root()
                .dockInset(withButton: rootHasButton)
                .environment(\.isTabRoot, true)
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                        .dockInset()
                        .environment(\.isTabRoot, false)
                        .toolbarTitleDisplayMode(.inline)
                }
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .resume: ResumeView()
        case .resumeVersion(let id): ResumeVersionView(versionID: id)
        case .library(let focus): QuestionLibraryView(initialFocus: focus)
        case .question(let question): QuestionDetailView(question: question)
        case .collection(let collection): QuestionCollectionView(collection: collection)
        case .rehearsal(let id): RehearsalDetailView(rehearsalID: id)
        case .progress: ProgressOverviewView()
        case .history: HistoryView()
        case .practice: PracticeView()
        case .profile: ProfileView()
        case .upcoming: UpcomingInterviewsView()
        }
    }
}

// MARK: - Dock

/// The app's tab bar: one solid capsule with three even slots, Home, then
/// the mock interview's button with the Rehearse mark, then Library. The
/// mock interview is the main action, so its button sits on the bar's top
/// edge in a rounded notch. Home starts a mock interview from its card, so
/// there the button shrinks away, the notch closes and the two tabs share
/// the bar.
struct Dock: View {
    /// How much of the screen the dock covers above the home indicator,
    /// including the mock interview button rising out of it.
    static func height(withButton: Bool) -> CGFloat { barHeight + (withButton ? rise : 0) + AppTheme.Spacing.xs }
    static let barHeight: CGFloat = 64
    /// Room round the highlight, so it sits inside the bar's round ends.
    static let inset: CGFloat = 6
    /// How far the mock interview button rises above the bar.
    static let rise: CGFloat = 30
    static let slots: CGFloat = 3
    /// The bar's width with each slot about 90pt across.
    static let slotWidth: CGFloat = 90
    static let fullWidth: CGFloat = slots * slotWidth + 2 * inset
    /// The bar's width with only the two tabs.
    static let compactWidth: CGFloat = (slots - 1) * slotWidth + 2 * inset
    static let morph = Animation.spring(duration: 0.45, bounce: 0.18)
    /// The button grows from its center once the tabs have made room, and
    /// shrinks before they close up.
    static let growInSlot = AnyTransition.asymmetric(
        insertion: .scale(scale: 0.2).combined(with: .opacity).animation(morph.delay(0.14)),
        removal: .scale(scale: 0.2).combined(with: .opacity).animation(.easeIn(duration: 0.16))
    )

    @Binding var selection: AppTab
    /// Off on Home's own page, which starts a mock interview from its card;
    /// the two tabs then share the bar evenly.
    var showsMockInterview = true
    let startInterview: () -> Void
    /// The highlight's left and right ends, in three-slot terms. They move on
    /// separate springs, so the highlight stretches toward the new tab and
    /// the far end catches up.
    @State private var leadingEdge: CGFloat
    @State private var trailingEdge: CGFloat

    init(selection: Binding<AppTab>, showsMockInterview: Bool = true, startInterview: @escaping () -> Void) {
        _selection = selection
        self.showsMockInterview = showsMockInterview
        self.startInterview = startInterview
        _leadingEdge = State(initialValue: selection.wrappedValue.slot)
        _trailingEdge = State(initialValue: selection.wrappedValue.slot)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            background
            tabs
            mockInterviewButton
        }
        .frame(height: Self.barHeight + Self.rise, alignment: .bottom)
        // Wide enough for three slots with the button in the middle; without
        // it, the two tabs close up into a compact bar.
        .frame(maxWidth: showsMockInterview ? Self.fullWidth : Self.compactWidth)
        .animation(Self.morph.delay(showsMockInterview ? 0 : 0.14), value: showsMockInterview)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppTheme.Spacing.md)
        // Also when something else changes the tab, like finishing an interview.
        .onChange(of: selection) { old, new in
            let lead = Animation.spring(duration: 0.3, bounce: 0.12)
            let follow = Animation.spring(duration: 0.5, bounce: 0.2)
            let movingRight = new.slot > old.slot
            withAnimation(movingRight ? lead : follow) { trailingEdge = new.slot }
            withAnimation(movingRight ? follow : lead) { leadingEdge = new.slot }
        }
    }

    /// One solid shape with a hairline edge and a soft shadow, so nothing
    /// behind shows through or blurs, notched round the button.
    private var background: some View {
        let shape = DockShape(
            notch: showsMockInterview ? 1 : 0,
            discCenterY: MockInterviewDockButton.size / 2 - Self.rise,
            discRadius: MockInterviewDockButton.size / 2
        )
        return shape
            .fill(Color(.tertiarySystemBackground))
            .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.12), radius: 14, y: 5)
            .frame(height: Self.barHeight)
            // The notch opens with the tabs and closes after the button.
            .animation(Self.morph.delay(showsMockInterview ? 0 : 0.14), value: showsMockInterview)
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            item(.home)
            // The button's slot. It narrows to nothing on Home rather than
            // leaving, so the tabs beside it only ever slide.
            Color.clear.frame(maxWidth: showsMockInterview ? .infinity : 0)
            item(.questions)
        }
        .padding(Self.inset)
        .background(alignment: .leading) { indicator }
        // The tabs make room first and close up last.
        .animation(Self.morph.delay(showsMockInterview ? 0 : 0.14), value: showsMockInterview)
        .frame(height: Self.barHeight)
    }

    /// Centered on the bar's top edge, in the notch.
    private var mockInterviewButton: some View {
        ZStack {
            if showsMockInterview {
                MockInterviewDockButton(action: startInterview)
                    .transition(Self.growInSlot)
            }
        }
        .animation(Self.morph, value: showsMockInterview)
        .frame(maxWidth: .infinity)
        .padding(.bottom, Self.barHeight + Self.rise - MockInterviewDockButton.size)
    }

    /// One highlight behind the selected tab. It's always there and only
    /// changes shape, so it morphs between tabs instead of fading out and
    /// back in.
    private var indicator: some View {
        GeometryReader { proxy in
            let slots = showsMockInterview ? Self.slots : Self.slots - 1
            let slot = (proxy.size.width - Self.inset * 2) / slots
            let lead = position(leadingEdge)
            let trail = position(trailingEdge)
            let start = min(lead, trail)
            let span = abs(trail - lead) + 1
            Capsule()
                .fill(Color(.systemFill).opacity(0.7))
                .frame(width: slot * span, height: proxy.size.height - Self.inset * 2)
                .offset(x: Self.inset + slot * start, y: Self.inset)
        }
    }

    /// A highlight edge, kept in three-slot terms, placed in the bar as it
    /// is now: without the middle slot, Library moves in by one.
    private func position(_ edge: CGFloat) -> CGFloat {
        guard !showsMockInterview else { return edge }
        if edge <= 0 { return edge }
        if edge >= 2 { return edge - 1 }
        return edge / 2
    }

    private func item(_ tab: AppTab) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 21, weight: .medium))
                    .frame(height: 26)
                // 11pt, the smallest size iOS sets text at (Caption 2).
                Text(tab.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
            }
            // The color switches at once, as in the system tab bar; easing it
            // smears the symbols between colors.
            .animation(nil) { $0.foregroundStyle(isSelected ? AppTheme.brand : Color.primary) }
            .contentTransition(.identity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Capsule())
        }
        .buttonStyle(DockPressStyle())
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The dock's bar: a capsule whose top edge dips in a rounded notch round the
/// mock interview button, leaving a little air between the two. `notch` runs
/// from 0, a plain capsule, to 1, the full notch, so the shape animates.
struct DockShape: Shape {
    var notch: CGFloat
    /// The button's center, from the bar's top edge, and its radius.
    let discCenterY: CGFloat
    let discRadius: CGFloat
    /// The air between the button and the notch, and the rounding where the
    /// notch meets the top edge.
    var gap: CGFloat = 6
    var fillet: CGFloat = 16

    var animatableData: CGFloat {
        get { notch }
        set { notch = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, r = h / 2
        let cx = rect.midX, cy = discCenterY
        let radius = (discRadius + gap) * notch
        let f = fillet * notch
        var points: [CGPoint] = []
        func arc(_ c: CGPoint, _ rad: CGFloat, from a0: CGFloat, to a1: CGFloat) {
            let steps = 24
            for i in 0...steps {
                let a = a0 + (a1 - a0) * CGFloat(i) / CGFloat(steps)
                points.append(CGPoint(x: c.x + rad * cos(a), y: c.y + rad * sin(a)))
            }
        }
        points.append(CGPoint(x: r, y: 0))
        // The notch, only once its circle reaches below the top edge.
        let reach = radius + f
        if radius > cy, reach > cy - f, f > 0 {
            let d = sqrt(max(reach * reach - (cy - f) * (cy - f), 0))
            let toC = atan2(cy - f, d)
            arc(CGPoint(x: cx - d, y: f), f, from: -.pi / 2, to: toC)
            // Going the short way round the bottom, start is the larger angle.
            var start = atan2(f - cy, -d)
            let end = atan2(f - cy, d)
            if start < end { start += 2 * .pi }
            arc(CGPoint(x: cx, y: cy), radius, from: start, to: end)
            arc(CGPoint(x: cx + d, y: f), f, from: .pi - toC, to: 1.5 * .pi)
        }
        points.append(CGPoint(x: w - r, y: 0))
        arc(CGPoint(x: w - r, y: r), r, from: -.pi / 2, to: .pi / 2)
        points.append(CGPoint(x: r, y: h))
        arc(CGPoint(x: r, y: r), r, from: .pi / 2, to: 1.5 * .pi)
        var path = Path()
        path.addLines(points.map { CGPoint(x: $0.x + rect.minX, y: $0.y + rect.minY) })
        path.closeSubpath()
        return path
    }
}

private extension View {
    /// Room for the dock, so the end of every page scrolls clear of it. Set
    /// on each screen in a stack,
    /// because insets from outside a navigation stack don't reach its pages.
    /// Room for the bar, and for the button rising out of it where it shows.
    func dockInset(withButton: Bool = true) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) { Color.clear.frame(height: Dock.height(withButton: withButton)) }
            // The app's own fades stand in for the system's edge blur, top
            // and bottom.
            .scrollEdgeEffectHidden(true, for: .all)
    }
}

private extension AppTab {
    /// Where the tab sits among the dock's three slots; the mock
    /// interview button takes the middle one.
    var slot: CGFloat {
        switch self {
        case .home: 0
        case .questions: 2
        }
    }

    var title: String {
        switch self {
        case .home: "Home"
        case .questions: "Library"
        }
    }

    /// Filled, as the system tab bar draws its symbols.
    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .questions: "books.vertical.fill"
        }
    }
}

/// The mock interview's button: the app icon's suit on the icon's white disc, in
/// the middle of the dock, so the main action stands apart and is always one tap
/// away.
struct MockInterviewDockButton: View {
    let action: () -> Void
    @State private var taps = 0

    static let size: CGFloat = 60

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            // The app icon's own suit, in full color, so the button and the
            // icon match.
            Image("SuitLogo")
                .resizable()
                .scaledToFit()
                .frame(width: Self.size * 0.72, height: Self.size * 0.72)
                .frame(width: Self.size, height: Self.size)
                // The icon's own background, so the orange tie stands out as
                // it does on the icon.
                .background(AppTheme.iconFill, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(PlayPressStyle())
        // Just enough lift to sit above the page, kept off the notch beneath.
        .shadow(color: .black.opacity(0.12), radius: 4, y: 1)
        .sensoryFeedback(.impact(weight: .medium), trigger: taps)
        .accessibilityLabel("Mock Interview")
        .accessibilityHint("Set up a mock interview")
    }
}

#Preview {
    RootView()
        .environment(AppState())
}

/// The mock interview button sinks a little while held, then springs back.
private struct PlayPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(duration: 0.3, bounce: 0.25), value: configuration.isPressed)
    }
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

/// A soft edge for scrolling pages: the page background fading in toward the
/// screen edge, so content dissolves rather than being cut off. A plain fade,
/// with no blur.
private struct EdgeFade: View {
    /// How far the fade reaches past the status bar, or above the dock.
    static let reach: CGFloat = 28

    let edge: VerticalEdge

    var body: some View {
        let toward: UnitPoint = edge == .top ? .top : .bottom
        let away: UnitPoint = edge == .top ? .bottom : .top
        LinearGradient(
            stops: [
                .init(color: AppTheme.background, location: 0),
                .init(color: AppTheme.background, location: 0.35),
                .init(color: AppTheme.background.opacity(0), location: 1),
            ],
            startPoint: toward,
            endPoint: away
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A quiet press for the dock: it dims while held, with no bounce.
private struct DockPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

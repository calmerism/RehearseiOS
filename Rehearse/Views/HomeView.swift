import SwiftUI

/// Answers one question: what should I do next? A greeting, a card to take a
/// mock interview, the candidate's real interviews as one paged card, how the
/// last mock went, the skills to work on and their mock interviews so far.
struct HomeView: View {
    @Environment(AppState.self) private var appState
    /// The upcoming interview on top of the stack.
    @State private var upcomingFront = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                TabHeader()
                greeting
                mockInterviewCard
                upcomingSection
                lastScoreCard
                focusAreas
                starterQuestions
                recentInterviews
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.top, AppTheme.Spacing.xs)
            .padding(.bottom, AppTheme.Spacing.xl)
        }
        .debugScrollAnchor()
        .groupedBackground()
        .logoTitle("Rehearse") {
            HStack(spacing: AppTheme.Spacing.md) {
                demoMenu
                NavigationLink(value: Route.profile) {
                    ProfileAvatar(size: 36)
                }
                .accessibilityLabel("Profile")
            }
        }
    }

    // MARK: - Greeting

    /// One line under the wordmark: a greeting for the time of day, for new
    /// and returning candidates alike.
    private var greeting: some View {
        Text(Self.greeting(isNewUser: appState.isNewUser, name: appState.candidateName))
            .font(.title3.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, AppTheme.Spacing.headingMargin - AppTheme.Spacing.md)
            // Tucked up under the wordmark, past the header's own padding,
            // with a little room before the first card.
            .padding(.top, -AppTheme.Spacing.sm)
            .padding(.bottom, AppTheme.Spacing.xs)
            .accessibilityAddTraits(.isHeader)
    }

    static func greeting(isNewUser: Bool, name: String, now: Date = .now) -> String {
        switch Calendar.current.component(.hour, from: now) {
        case 5..<12: return "Good morning, \(name)"
        case 12..<17: return "Good afternoon, \(name)"
        default: return "Good evening, \(name)"
        }
    }

    // MARK: - Mock interview

    /// The same setup sheet as the dock's button, which Home leaves out. The
    /// colors are inverted from the other cards: a solid accent card with a
    /// white Start button, so it reads as the way in.
    private var mockInterviewCard: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Text("Take a Mock Interview")
                .font(.headline)
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            Button {
                appState.setUpInterview(.custom)
            } label: {
                Label("Start", systemImage: "play.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.buttonFill)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .frame(height: Self.startHeight)
                    .background(.white, in: Capsule())
                    // A full 44pt to tap, past the capsule's edge.
                    .contentShape(Capsule().inset(by: -4))
            }
            .buttonStyle(InvertedButtonStyle())
            .fixedSize()
            .accessibilityHint("Set up a mock interview")
            .sensoryFeedback(.impact(weight: .light), trigger: appState.interviewSetup != nil)
        }
        // The button sits the same small distance from the top, right and
        // bottom edges, so its round end follows the card's corner; the
        // title starts as far in as the corner curves, so it isn't crowded.
        .padding(.leading, AppTheme.Spacing.lg)
        .padding(.trailing, Self.startInset)
        .padding(.vertical, Self.startInset)
        .background(AppTheme.buttonFill, in: RoundedRectangle(cornerRadius: Self.startHeight / 2 + Self.startInset, style: .continuous))
    }

    private static let startHeight: CGFloat = 44
    private static let startInset: CGFloat = 8

    // MARK: - Upcoming interviews

    @ViewBuilder
    private var upcomingSection: some View {
        // With no interviews the card below is the way to add one, so the
        // heading doesn't offer a second.
        if appState.upcomingInterviews.isEmpty {
            SectionTitle(title: "Upcoming Interviews")
            addInterviewCard
        } else {
            // The heading opens every upcoming interview, so it takes no
            // room of its own.
            SectionTitle(
                title: "Upcoming Interviews",
                actionTitle: "Add Interview",
                actionImage: "plus",
                action: { appState.interviewEditor = InterviewEditorRequest() },
                titleDestination: .upcoming
            )
            upcomingCarousel
        }
    }

    /// Every upcoming interview as the same card, stacked like a pile of
    /// cards with the next ones showing beneath, soonest on top. Swiping the
    /// top card either way sends it to the back. Page dots down the right
    /// side, in the margin, say which one is on top and how many there are.
    private var upcomingCarousel: some View {
        let interviews = appState.upcomingInterviews
        return CardStack(count: interviews.count, front: $upcomingFront) { index in
            upcomingCard(interviews[index])
        }
        .overlay(alignment: .trailing) {
            if interviews.count > 1 {
                StackDots(count: interviews.count, current: upcomingFront % interviews.count)
                    // Centered in the 16pt page margin beside the cards.
                    .offset(x: AppTheme.Spacing.md / 2 + StackDots.width / 2)
            }
        }
        .padding(.bottom, CardStackMetrics.peek * CGFloat(min(interviews.count - 1, 2)))
    }

    /// One upcoming interview, with the one action that prepares for it.
    private func upcomingCard(_ interview: Interview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: AppTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(interview.company ?? interview.role)
                        .cardTitleStyle()
                    if interview.company != nil {
                        // Second in line after the company, so a size up from
                        // the details and in black.
                        Text(interview.role)
                            .font(.body)
                    }
                }
                .lineLimit(1)
                Spacer(minLength: 0)
                DateTile(date: interview.date)
            }

            // "In 3 days at 3:00 PM" / "20-minute Technical Interview", as
            // Calendar lists an event's details: black text at medium weight,
            // under the role, with gray icons so the green status and the
            // button stay the loudest things on the card.
            VStack(alignment: .leading, spacing: 6) {
                if let date = interview.date {
                    Label("\(interview.countdownText ?? date.formatted(date: .abbreviated, time: .omitted)) at \(date.formatted(date: .omitted, time: .shortened))", systemImage: "clock")
                }
                Label("\(interview.durationMinutes)-minute \(interview.type.interviewName)", systemImage: "briefcase")
            }
            .font(.subheadline.weight(.medium))
            .labelStyle(DetailLabelStyle(iconColor: .secondary))
            .symbolVariant(.fill)
            .foregroundStyle(Color.primary)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Whether it's been rehearsed, and the one action, on one line.
            HStack(spacing: AppTheme.Spacing.sm) {
                preparationLabel(for: interview)
                Spacer(minLength: 0)
                Button {
                    appState.setUpInterview(.upcoming(interview.id))
                } label: {
                    Label("Quick Prep", systemImage: "bolt.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .sensoryFeedback(.impact(weight: .light), trigger: appState.interviewSetup != nil)
            }
            .padding(.top, 4)
            // Pinned to the bottom, so every card's button is on the same line
            // when a taller card sets the stack's height. (A Spacer here would
            // add the stack's spacing twice even at zero height.)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        // The same 16pt inset as every other card.
        .padding(AppTheme.Spacing.md)
        .cardBackground()
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .contextMenu {
            Button("Edit", systemImage: "pencil") { edit(interview) }
        }
        .accessibilityAction(named: "Edit \(interview.title)") { edit(interview) }
    }

    /// Whether this interview has been rehearsed: "Practiced" in green, or
    /// "Not practiced yet" in gray. No date, since the score card below
    /// names the day.
    @ViewBuilder
    private func preparationLabel(for interview: Interview) -> some View {
        if appState.rehearsalCount(for: interview) > 0 {
            PracticedLabel()
        } else {
            Text("Not practiced yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var addInterviewCard: some View {
        ActionRowCard(
            systemImage: "plus",
            title: "Add an Upcoming Interview",
            detail: "Practice for the actual role, company and date."
        ) {
            appState.interviewEditor = InterviewEditorRequest()
        }
    }

    private func edit(_ interview: Interview) {
        appState.interviewEditor = InterviewEditorRequest(interview: interview)
    }

    // MARK: - Last mock score

    /// The most recent interview of any kind, so the score is always the latest.
    @ViewBuilder
    private var lastScoreCard: some View {
        if let last = appState.lastInterview, let feedback = last.feedback {
            NavigationLink(value: Route.rehearsal(last.id)) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    // What it is in gray with Details on the right, as Health
                    // heads a card, then the interview's name as the title.
                    // No symbol, so both lines start on the same edge.
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        CardHeader(title: "Last Mock Interview", detail: "Details", showsChevron: true)
                        Text(last.title)
                            .font(.headline)
                            .lineLimit(1)
                    }
                    HStack(spacing: AppTheme.Spacing.lg) {
                        ScoreRing(score: feedback.overall, caption: "out of 100", size: 96)
                        // The best and the weakest of the five areas, so the
                        // card says what to keep and what to fix.
                        let ranked = feedback.areas.sorted { $0.score > $1.score }
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                            if let highest = ranked.first {
                                ScoreBar(title: highest.area.title, score: highest.score)
                            }
                            if let lowest = ranked.last {
                                ScoreBar(title: lowest.area.title, score: lowest.score)
                            }
                        }
                        .font(.subheadline)
                    }
                }
                .padding(AppTheme.Spacing.md)
                .cardBackground()
                .foregroundStyle(Color.primary)
            }
            .buttonStyle(CardButtonStyle())
        }
    }

    // MARK: - Focus areas

    /// The skills recent interviews flagged, not individual questions. The
    /// current focus opens Practice; an older one opens questions that build it.
    @ViewBuilder
    private var focusAreas: some View {
        let flagged = appState.flaggedSkills()
        if !flagged.isEmpty {
            SectionTitle(title: "What to Work On")
            VStack(spacing: 0) {
                ForEach(Array(flagged.enumerated()), id: \.element.skill) { index, item in
                    if index > 0 { Divider().padding(.leading, AppTheme.Spacing.md) }
                    focusRow(item.skill, count: item.count)
                }
            }
            .cardBackground()
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        }
    }

    /// The whole row opens practice, with a chevron, as rows do elsewhere.
    /// Every row states the same fact, so they compare at a glance; the
    /// current focus is first.
    private func focusRow(_ skill: Skill, count: Int) -> some View {
        let isCurrent = skill == appState.currentFocus
        let total = min(appState.interviews.count, 3)
        return NavigationLink(value: isCurrent ? Route.practice : Route.library(focus: skill)) {
            HStack(spacing: AppTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.title)
                        .font(.headline)
                    Text(total < 2 ? "From your first interview" : "Came up in \(count) of your last \(total) interviews")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: AppTheme.Spacing.xs)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            .foregroundStyle(Color.primary)
        }
        .buttonStyle(CardRowButtonStyle())
        .accessibilityHint("Practice \(skill.title)")
    }

    // MARK: - New candidate

    /// Before the first interview there's nothing to review yet, so Home
    /// offers a few easy questions to warm up on.
    @ViewBuilder
    private var starterQuestions: some View {
        if appState.isNewUser {
            let starters = appState.library.filter { $0.difficulty == .easy }.prefix(3)
            SectionTitle(title: "Warm Up", actionTitle: "See All", destination: .library(focus: nil))
            VStack(spacing: 0) {
                ForEach(Array(starters.enumerated()), id: \.element.id) { index, question in
                    if index > 0 { Divider().padding(.leading, AppTheme.Spacing.md) }
                    Button {
                        appState.activePractice = question
                    } label: {
                        HStack {
                            QuestionRow(question: question, endsWithPeriod: true)
                            Spacer(minLength: AppTheme.Spacing.xs)
                            Image(systemName: "mic.fill")
                                .foregroundStyle(AppTheme.brand)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(CardRowButtonStyle())
                    .accessibilityHint("Answer this question out loud")
                }
            }
            .cardBackground()
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        }
    }

    // MARK: - Recent interviews

    /// One card for every mock interview so far: how many, how they score on
    /// average, and the latest two. "See All" pushes the full history.
    @ViewBuilder
    private var recentInterviews: some View {
        let interviews = appState.interviews
        if !interviews.isEmpty {
            SectionTitle(title: "Recent Interviews", actionTitle: "See All", destination: .history)
            VStack(spacing: 0) {
                ForEach(Array(interviews.prefix(2).enumerated()), id: \.element.id) { index, rehearsal in
                    if index > 0 { Divider().padding(.leading, AppTheme.Spacing.md) }
                    NavigationLink(value: Route.rehearsal(rehearsal.id)) {
                        InterviewRow(rehearsal: rehearsal)
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.vertical, AppTheme.Spacing.sm)
                    }
                    .buttonStyle(CardRowButtonStyle())
                }
            }
            .cardBackground()
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        }
    }

    // MARK: - Presenter controls

    /// Not part of the product: lets a presenter switch Home between contexts.
    private var demoMenu: some View {
        Menu {
            Section("Prototype scenario") {
                Button("Returning candidate") { appState.load(.returning) }
                Button("New candidate") { appState.load(.newUser) }
            }
            Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") {
                withAnimation(.smooth(duration: 0.4)) { appState.isSignedIn = false }
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
        }
        .accessibilityLabel("Demo scenarios")
    }
}

/// The candidate's picture before they've added one, as Apple draws a
/// contact without a photo: their first initial in white, rounded, on a
/// disc shaded like the app icon's tie, so it matches the rest of the app.
struct ProfileAvatar: View {
    var size: CGFloat = 36
    @Environment(AppState.self) private var appState

    private var initial: String {
        appState.candidateName.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? ""
    }

    var body: some View {
        Text(initial)
            .font(.system(size: size * 0.46, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            // Lighter at the top, as in Contacts, down to the button orange
            // so the white initial stays readable.
            .background(
                LinearGradient(
                    colors: [AppTheme.avatarTop, AppTheme.buttonFill],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: Circle()
            )
            .accessibilityHidden(true)
    }
}

/// Which card in a stack is on top: a column of dots, the current one a
/// longer capsule in the accent, as the system page control marks a page.
private struct StackDots: View {
    static let width: CGFloat = 6
    let count: Int
    let current: Int

    var body: some View {
        VStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? AppTheme.graphic : Color(.systemGray4))
                    .frame(width: Self.width, height: index == current ? 16 : Self.width)
            }
        }
        .animation(.smooth(duration: 0.3), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Interview \(current + 1) of \(count)")
    }
}

/// Fades a little while held, as the primary button does.
private struct InvertedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// A card that starts something, as Reminders offers a new item: the glyph
/// and title in the accent, the reason beneath in gray.
private struct ActionRowCard: View {
    let systemImage: String
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.brand)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(AppTheme.brand)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(AppTheme.Spacing.md)
            .cardBackground()
            .multilineTextAlignment(.leading)
        }
        .buttonStyle(CardButtonStyle())
    }
}

/// A past interview: what it was for, its kind and date, and its score.
struct InterviewRow: View {
    let rehearsal: Rehearsal

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rehearsal.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(rehearsal.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: AppTheme.Spacing.xs)
            if let score = rehearsal.score {
                Text("\(score)")
                    .font(.rowScore)
                    .accessibilityLabel("Score \(score)")
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .foregroundStyle(Color.primary)
        .accessibilityElement(children: .combine)
    }
}

/// Cards piled on one another, the top one in full and the next two peeking
/// out beneath it, smaller and fainter, like a stack in Wallet. The stack
/// follows the finger: as the top card slides sideways it tilts away in
/// perspective and the card beneath rises to take its place. Let go far
/// enough and the top card leaves and fades back in at the bottom of the
/// pile; otherwise everything springs back.
struct CardStack<Card: View>: View {
    let count: Int
    @Binding var front: Int
    @ViewBuilder let card: (Int) -> Card

    @State private var drag: CGFloat = 0
    @State private var isThrowing = false
    /// The card that just went to the back, faded in once it's there.
    @State private var arriving: Int?
    @State private var swaps = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far a drag goes before the next card is fully in front.
    private let travel: CGFloat = 220

    /// From 0 at rest to 1 when the top card is out of the way.
    private var progress: CGFloat { min(abs(drag) / travel, 1) }

    var body: some View {
        let top = count > 0 ? front % count : 0
        EqualHeightStack {
            ForEach(0..<count, id: \.self) { index in
                let depth = (index - top + count) % count
                // Cards behind move up a place as the top card leaves.
                let position = depth == 0 ? 0 : CGFloat(depth) - progress
                card(index)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .shadow(color: .black.opacity(depth == 0 ? 0.08 : 0), radius: 14, y: 6)
                    .scaleEffect(scale(at: position), anchor: .bottom)
                    .offset(y: min(position, 2) * CardStackMetrics.peek)
                    // The card sent to the back grows into place from behind.
                    .scaleEffect(index == arriving ? 0.9 : 1, anchor: .bottom)
                    .opacity(index == arriving ? 0 : opacity(at: position))
                    .modifier(TopCardMotion(drag: depth == 0 ? drag : 0, progress: depth == 0 ? progress : 0, isFlat: reduceMotion))
                    .zIndex(Double(count - depth))
                    .allowsHitTesting(depth == 0)
                    .accessibilityHidden(depth != 0)
            }
        }
        // Alongside the page's scrolling: only a mostly sideways drag moves the card.
        .simultaneousGesture(count > 1 ? swipe : nil)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: swaps)
        #if DEBUG
        .task { await playDemoSwipes() }
        #endif
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(by: 1)
            case .decrement: step(by: -1)
            @unknown default: break
            }
        }
    }

    private func scale(at position: CGFloat) -> CGFloat {
        1 - min(position, 3) * 0.05
    }

    private func opacity(at position: CGFloat) -> Double {
        position > 2 ? 0 : 1 - Double(position) * 0.27
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard !isThrowing, abs(value.translation.width) > abs(value.translation.height) else { return }
                // Rubber-banded past the travel distance, like an overscroll.
                let x = value.translation.width
                drag = abs(x) <= travel ? x : (x > 0 ? 1 : -1) * (travel + (abs(x) - travel) * 0.4)
            }
            .onEnded { value in
                guard !isThrowing else { return }
                let projected = value.predictedEndTranslation.width
                guard drag != 0, abs(projected) > travel * 0.6 else {
                    withAnimation(.smooth(duration: 0.35)) { drag = 0 }
                    return
                }
                throwTopCard(toward: projected > 0 ? 1 : -1)
            }
    }

    /// Finishes the slide, then quietly moves the card to the back. The next
    /// card is already in front by then, so nothing jumps.
    private func throwTopCard(toward direction: CGFloat) {
        isThrowing = true
        let leaving = front % count
        // Fully off screen, so it never shows over the card coming up.
        withAnimation(.spring(duration: 0.3, bounce: 0)) {
            drag = direction * travel * 2.2
        } completion: {
            var settle = Transaction()
            settle.disablesAnimations = true
            withTransaction(settle) {
                arriving = leaving
                front = (front + 1) % count
                drag = 0
            }
            swaps += 1
            withAnimation(.smooth(duration: 0.4)) {
                arriving = nil
            } completion: {
                isThrowing = false
            }
        }
    }

    #if DEBUG
    /// `-demoSwipe` plays finger-like swipes for screen recordings, since
    /// the simulator can't be touched from a script: a short drag that springs
    /// back, then a swipe left and a swipe right that go through.
    private func playDemoSwipes() async {
        guard ProcessInfo.processInfo.arguments.contains("-demoSwipe"), count > 1 else { return }
        try? await Task.sleep(for: .seconds(1.5))
        for (distance, flicks) in [(-90.0, false), (-200.0, true), (180.0, true), (-210.0, true)] {
            // About 0.4 seconds of finger movement at 60 frames a second, easing out.
            for frame in 1...24 {
                let t = Double(frame) / 24
                drag = distance * (1 - pow(1 - t, 2))
                try? await Task.sleep(for: .milliseconds(16))
            }
            if flicks {
                throwTopCard(toward: distance > 0 ? 1 : -1)
            } else {
                withAnimation(.smooth(duration: 0.35)) { drag = 0 }
            }
            try? await Task.sleep(for: .seconds(1.6))
        }
    }
    #endif

    private func step(by step: Int) {
        withAnimation(.smooth(duration: 0.35)) {
            front = (front + step + count) % count
        }
        swaps += 1
    }
}

/// The top card's motion: it follows the finger and turns slightly away in
/// perspective, staying solid so it never blends with the card beneath.
private struct TopCardMotion: ViewModifier {
    let drag: CGFloat
    let progress: CGFloat
    var isFlat = false

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(isFlat ? 0 : Double(drag / 18).clamped(to: -14...14)),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .scaleEffect(1 - progress * 0.04)
            .offset(x: drag)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

enum CardStackMetrics {
    /// How far each card behind shows below the one in front.
    static let peek: CGFloat = 10
}

/// Lays its children on top of one another, all as tall as the tallest, so
/// the cards in a stack line up whatever their content.
struct EqualHeightStack: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let height = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for subview in subviews {
            subview.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
        }
    }
}

extension QuestionCategory {
    var symbol: String {
        switch self {
        case .common: "text.bubble"
        case .behavioral: "person.2"
        case .roleBased: "laptopcomputer"
        }
    }
}

#Preview("Returning") {
    NavigationStack { HomeView() }
        .environment(AppState())
}

#Preview("New") {
    NavigationStack { HomeView() }
        .environment(AppState(scenario: .newUser))
}

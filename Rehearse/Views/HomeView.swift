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
                unsavedNotice
                mockInterviewCard
                upcomingSection
                lastScoreCard
                recentInterviews
                focusAreas
                starterQuestions
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

    // MARK: - Unsaved changes

    /// Shown only while a change couldn't be saved to the account, as Notes
    /// says when it can't sync.
    @ViewBuilder
    private var unsavedNotice: some View {
        if !appState.unsavedChanges.isEmpty {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "exclamationmark.icloud.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.graphic)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Some changes aren’t saved yet")
                        .font(.subheadline.weight(.semibold))
                    Text("They’re kept on this phone and will save when you’re back online.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: AppTheme.Spacing.xs)
                Button("Try Again") {
                    Task { await appState.retryUnsavedChanges() }
                }
                .font(.subheadline.weight(.semibold))
                .disabled(appState.isRetryingSaves)
            }
            .padding(AppTheme.Spacing.md)
            .cardBackground()
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            .transition(.opacity)
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
            // Adding another is on the Upcoming Interviews page itself.
            SectionTitle(title: "Upcoming Interviews", titleDestination: .upcoming)
            upcomingCarousel
        }
    }

    /// Every upcoming interview as the same card, stacked like a pile of
    /// cards with the next ones showing beneath, soonest on top. Swiping left
    /// tucks the top card in behind the stack and brings the next forward;
    /// swiping right brings it back out. It stops at the last one. Page dots
    /// centered under the stack, as Wallet and the Home Screen page, say
    /// which one is on top.
    private var upcomingCarousel: some View {
        let interviews = appState.upcomingInterviews
        return VStack(spacing: AppTheme.Spacing.sm) {
            CardStack(count: interviews.count, front: $upcomingFront) { index in
                upcomingCard(interviews[index], number: index + 1)
            }
            .padding(.bottom, CardStackMetrics.peek * CGFloat(min(interviews.count - 1, 2)))
            if interviews.count > 1 {
                StackDots(count: interviews.count, current: min(upcomingFront, interviews.count - 1))
            }
        }
    }

    /// One upcoming interview, with the one action that prepares for it.
    /// `number` is its place in the stack, soonest first.
    private func upcomingCard(_ interview: Interview, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: AppTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: AppTheme.Spacing.xs) {
                        // Its place in the stack: a solid accent disc with a
                        // rounded white figure, as tall as the title's capitals.
                        Text("\(number)")
                            .font(.footnote.weight(.heavy).monospacedDigit())
                            .fontDesign(.rounded)
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(AppTheme.brand, in: Circle())
                            .accessibilityLabel("Interview \(number)")
                        Text(interview.company ?? interview.role)
                            .cardTitleStyle()
                    }
                    if interview.company != nil {
                        // Second in line after the company, so a size up from
                        // the details and in black.
                        Text(interview.role)
                            .font(.body)
                    }
                }
                .lineLimit(1)
                Spacer(minLength: 0)
                CountdownTile(date: interview.date)
            }

            // "29 Oct, 3:00 PM" / "20 mins Tech Interview", as Calendar
            // lists an event's details: black text at medium weight, under
            // the role, with gray icons so the green status and the button
            // stay the loudest things on the card. The tile says how soon;
            // this says when.
            VStack(alignment: .leading, spacing: 6) {
                if let date = interview.date {
                    Label("\(date.formatted(.dateTime.day().month(.abbreviated))), \(date.formatted(date: .omitted, time: .shortened))", systemImage: "clock")
                }
                Label("\(interview.durationMinutes) mins \(interview.type == .technical ? "Tech" : "Non-Tech") Interview", systemImage: "briefcase")
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

    /// Whether this interview has been rehearsed, in words with a symbol:
    /// a filled green tick and "Practiced", or a dashed circle and "Not
    /// practiced yet" in gray. A tick alone didn't say what it meant.
    @ViewBuilder
    private func preparationLabel(for interview: Interview) -> some View {
        let isPracticed = appState.rehearsalCount(for: interview) > 0
        Label {
            Text(isPracticed ? "Practiced" : "Not practiced yet")
                .font(.subheadline.weight(isPracticed ? .semibold : .regular))
        } icon: {
            Image(systemName: isPracticed ? "checkmark.circle.fill" : "circle.dashed")
                .font(.title3)
        }
        .foregroundStyle(isPracticed ? AppTheme.practiced : Color.secondary)
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
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

    /// The most recent interview, in one compact card: what it was, and
    /// the way into its feedback, with the ring filled to the score on the
    /// right with the score in it.
    @ViewBuilder
    private var lastScoreCard: some View {
        if let last = appState.lastInterview, let feedback = last.feedback {
            NavigationLink(value: Route.rehearsal(last.id)) {
                HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
                    // What it was. The whole card opens the feedback, with
                    // the chevron as its one sign, so no button of its own.
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last Mock Interview")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(last.title)
                            .font(.headline)
                            .lineLimit(2)
                    }
                    Spacer(minLength: AppTheme.Spacing.xs)
                    ScoreRing(score: feedback.overall, size: 52)
                        .accessibilityHidden(true)
                    // At the card's edge, as a row's chevron sits.
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .padding(AppTheme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardBackground()
                .foregroundStyle(Color.primary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Last mock interview, \(last.title), scored \(feedback.overall)")
                .accessibilityHint("Opens its feedback")
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
            let starters = appState.warmUp
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
            SectionTitle(title: "History", titleDestination: .history)
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
                appState.signOut()
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
    static let size: CGFloat = 7
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? AppTheme.graphic : Color(.systemGray4))
                    .frame(width: index == current ? 18 : Self.size, height: Self.size)
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
        }
        .foregroundStyle(Color.primary)
        .accessibilityElement(children: .combine)
    }
}

/// A pile of cards: the top one in full and the next two peeking out
/// beneath it, smaller and fainter, like a stack in Wallet. It has an end:
/// cards already seen wait out of sight behind, so it never loops.
///
/// Swiping left, the top card follows the finger, tilting a little, and the
/// card beneath rises. Let go and it slides fully clear of the stack, then
/// goes in behind it and fades. Swiping right does the reverse: the card
/// before comes out from behind, clear of the stack, then slides over the
/// top. A card only changes layer while it's clear of the others, so
/// nothing ever pops through.
struct CardStack<Card: View>: View {
    let count: Int
    @Binding var front: Int
    @ViewBuilder let card: (Int) -> Card

    @State private var drag: CGFloat = 0
    /// Decided at the start of each drag, so a drag is either the card's or
    /// the page's, never both.
    @State private var isSideways: Bool?
    @State private var isMoving = false
    @State private var moving: Int?
    @State private var moveX: CGFloat = 0
    @State private var moveIsBehind = false
    @State private var moveIsOnTop = false
    @State private var width: CGFloat = 360
    @State private var swaps = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far a drag goes before the next card is fully in front.
    private var travel: CGFloat { width * 0.6 }
    /// Far enough aside that a card is clear of the stack.
    private var aside: CGFloat { width + 24 }

    private var top: Int { min(max(front, 0), max(count - 1, 0)) }
    private var hasNext: Bool { top < count - 1 }
    private var hasPrevious: Bool { top > 0 }
    /// From 0 at rest to 1 when the top card is out of the way.
    private var progress: CGFloat { drag < 0 && hasNext ? min(-drag / travel, 1) : 0 }

    var body: some View {
        EqualHeightStack {
            ForEach(0..<count, id: \.self) { index in
                let depth = index - top
                card(index)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .modifier(placement(for: index, depth: depth))
                    .allowsHitTesting(depth == 0 && !isMoving)
                    .accessibilityHidden(depth != 0)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .simultaneousGesture(count > 1 ? swipe : nil)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: swaps)
        #if DEBUG
        .task { await playDemoSwipes() }
        #endif
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: sendTopCardBehind()
            case .decrement: bringPreviousCardBack()
            @unknown default: break
            }
        }
    }

    private func placement(for index: Int, depth: Int) -> CardPlacement {
        let behind = CardPlacement(x: 0, y: 2 * CardStackMetrics.peek, scale: scale(at: 2.6), opacity: 0, z: -1, tilt: 0, shadow: 0)
        if index == moving {
            if moveIsBehind {
                var place = behind
                place.x = moveX
                place.z = moveIsOnTop ? Double(count + 1) : -1
                return place
            }
            return CardPlacement(x: moveX, y: 0, scale: 1, opacity: 1, z: moveIsOnTop ? Double(count + 1) : -1, tilt: tilt(for: moveX), shadow: 0.08)
        }
        if depth < 0 { return behind }
        let position = depth == 0 ? 0 : CGFloat(depth) - progress
        return CardPlacement(
            x: depth == 0 ? drag : 0,
            y: min(position, 2) * CardStackMetrics.peek,
            scale: depth == 0 ? 1 - progress * 0.03 : scale(at: position),
            opacity: opacity(at: position),
            z: Double(count - depth),
            tilt: depth == 0 ? tilt(for: drag) : 0,
            shadow: depth == 0 ? 0.08 : 0
        )
    }

    /// A slight turn away as the card moves aside, in proportion.
    private func tilt(for x: CGFloat) -> Double {
        reduceMotion ? 0 : Double(x / max(width, 1)) * 8
    }

    private func scale(at position: CGFloat) -> CGFloat {
        1 - min(position, 3) * 0.05
    }

    private func opacity(at position: CGFloat) -> Double {
        position > 2 ? 0 : 1 - Double(position) * 0.27
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !isMoving else { return }
                if isSideways == nil {
                    isSideways = abs(value.translation.width) > abs(value.translation.height)
                }
                guard isSideways == true else { return }
                let x = value.translation.width
                // With nowhere to go the card only gives a little, so the
                // end of the stack is felt.
                if x < 0 {
                    drag = hasNext ? x : x * 0.15
                } else {
                    drag = hasPrevious ? min(x, 80) * 0.6 : x * 0.15
                }
            }
            .onEnded { value in
                defer { isSideways = nil }
                guard isSideways == true, !isMoving else { return }
                let projected = value.predictedEndTranslation.width
                if projected < -travel * 0.5, hasNext {
                    sendTopCardBehind()
                } else if projected > travel * 0.35, hasPrevious {
                    bringPreviousCardBack()
                } else {
                    withAnimation(.spring(duration: 0.35, bounce: 0.25)) { drag = 0 }
                }
            }
    }

    /// Clear of the stack first, then behind it.
    private func sendTopCardBehind() {
        guard hasNext, !isMoving else { return }
        isMoving = true
        let card = top
        var hold = Transaction()
        hold.disablesAnimations = true
        withTransaction(hold) {
            moving = card
            moveX = drag
            moveIsBehind = false
            moveIsOnTop = true
        }
        withAnimation(.spring(duration: 0.32, bounce: 0)) {
            moveX = -aside
            drag = 0
            front = card + 1
        } completion: {
            // Clear of the stack, so going under shows no jump.
            withTransaction(hold) { moveIsOnTop = false }
            swaps += 1
            withAnimation(.spring(duration: 0.42, bounce: 0)) {
                moveX = 0
                moveIsBehind = true
            } completion: {
                moving = nil
                isMoving = false
            }
        }
    }

    /// Out from behind to clear of the stack, then over the top.
    private func bringPreviousCardBack() {
        guard hasPrevious, !isMoving else { return }
        isMoving = true
        let card = top - 1
        var hold = Transaction()
        hold.disablesAnimations = true
        withTransaction(hold) {
            moving = card
            moveX = 0
            moveIsBehind = true
            moveIsOnTop = false
        }
        withAnimation(.spring(duration: 0.3, bounce: 0)) {
            moveX = -aside
            moveIsBehind = false
            drag = 0
        } completion: {
            withTransaction(hold) { moveIsOnTop = true }
            swaps += 1
            withAnimation(.spring(duration: 0.42, bounce: 0.1)) {
                moveX = 0
                front = card
            } completion: {
                moving = nil
                isMoving = false
            }
        }
    }

    #if DEBUG
    /// `-demoSwipe` plays finger-like swipes for screen recordings, since
    /// the simulator can't be dragged from a script.
    private func playDemoSwipes() async {
        guard ProcessInfo.processInfo.arguments.contains("-demoSwipe"), count > 1 else { return }
        try? await Task.sleep(for: .seconds(1.5))
        for distance in [-120.0, 120.0] {
            for frame in 1...20 {
                let t = Double(frame) / 20
                let x = distance * (1 - pow(1 - t, 2))
                drag = x < 0 ? (hasNext ? x : x * 0.15) : (hasPrevious ? min(x, 80) * 0.6 : x * 0.15)
                try? await Task.sleep(for: .milliseconds(16))
            }
            if distance < 0 { sendTopCardBehind() } else { bringPreviousCardBack() }
            try? await Task.sleep(for: .seconds(1.6))
        }
    }
    #endif
}

/// One card's place in the stack. Every value animates, so a card always
/// moves smoothly from one place to the next.
private struct CardPlacement: ViewModifier {
    var x: CGFloat
    var y: CGFloat
    var scale: CGFloat
    var opacity: Double
    var z: Double
    var tilt: Double
    var shadow: Double

    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(shadow), radius: 14, y: 6)
            .scaleEffect(scale, anchor: .bottom)
            .rotation3DEffect(.degrees(tilt), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            .offset(x: x, y: y)
            .opacity(opacity)
            .zIndex(z)
    }
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

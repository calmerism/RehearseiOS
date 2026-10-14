import SwiftUI

// MARK: - Welcome

/// The first thing a new install shows: a welcome with the app's icon, then
/// two pages that each show a live piece of the app rather than describe it:
/// a score filling in, and a real interview on its way. Get Started opens
/// Sign Up; an existing account goes to Log In.
struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    @State private var page = 0

    private let pages: [(title: String, detail: String)] = [
        ("Practice out loud.", "Speak your answers to real interview questions, one at a time."),
        ("See exactly how you did.", "Scored on the six things interviewers look for."),
        ("Ready for the real one.", "Add the date, and every practice gets you ready for that interview."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Text("\(Text("Rehearse").tracking(-0.6))\(Text(".").foregroundStyle(AppTheme.brand))")
                .font(.title3.bold())
                .padding(.top, AppTheme.Spacing.xs)
                .accessibilityLabel("Rehearse")

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    WelcomePage(index: index, isActive: page == index, title: pages[index].title, detail: pages[index].detail)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: AppTheme.Spacing.md) {
                PageDots(count: pages.count, current: page)
                PrimaryButton(title: page == pages.count - 1 ? "Get Started" : "Continue") {
                    if page < pages.count - 1 {
                        withAnimation(.smooth(duration: 0.4)) { page += 1 }
                    } else {
                        appState.opensSignUp = true
                        withAnimation(.smooth(duration: 0.4)) { appState.hasSeenWelcome = true }
                    }
                }
                Button("I Already Have an Account") {
                    withAnimation(.smooth(duration: 0.4)) { appState.hasSeenWelcome = true }
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.brand)
                .frame(minHeight: 44)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.xs)
        }
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity)
        .groupedBackground()
        #if DEBUG
        .onAppear {
            // `-page N` opens the welcome at a page, for screenshots.
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "-page"), arguments.indices.contains(index + 1),
               let number = Int(arguments[index + 1]) { page = number }
        }
        #endif
    }
}

/// Which page is showing: the current one a longer capsule, as the system's
/// own page control does.
private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? AppTheme.graphic : AppTheme.track)
                    .frame(width: index == current ? 20 : 7, height: 7)
            }
        }
        .animation(.smooth(duration: 0.3), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

/// One welcome page: the piece of the app it's about, then a headline and a
/// line. The piece plays when its page comes into view.
private struct WelcomePage: View {
    let index: Int
    let isActive: Bool
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Group {
                switch index {
                case 0: QuestionVignette(isActive: isActive)
                case 1: ScoreVignette(isActive: isActive)
                default: UpcomingVignette(isActive: isActive)
                }
            }
            .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text(title)
                    .font(.system(size: 38, weight: .bold))
                    .tracking(-1)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.Spacing.xs)
            .padding(.bottom, AppTheme.Spacing.md)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.md)
    }
}

/// Questions as a deck, as the Library keeps them: two waiting behind, and
/// the one on top being asked, word by word, with the button to answer it
/// starting to record once it's been said.
private struct QuestionVignette: View {
    let isActive: Bool
    @State private var replay = 0
    @State private var isRecording = false
    /// The question fades out before it's asked again, so the loop never jumps.
    @State private var questionShown = true

    var body: some View {
        ZStack {
            // The questions still to come, tucked behind.
            ForEach([(-7.0, 0.6, 30.0, 34.0), (5.0, 0.85, 16.0, 18.0)], id: \.0) { angle, opacity, inset, drop in
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(height: 220)
                    .padding(.horizontal, inset)
                    .rotationEffect(.degrees(angle))
                    .offset(y: drop)
                    .opacity(opacity)
                    .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
            }
            card
        }
        .padding(.horizontal, AppTheme.Spacing.xs)
        .task(id: isActive) {
            guard isActive else { return }
            replay += 1
            while !Task.isCancelled {
                // Asked, word by word.
                try? await Task.sleep(for: .seconds(2.9))
                // Answered.
                withAnimation(.spring(duration: 0.5, bounce: 0.15)) { isRecording = true }
                try? await Task.sleep(for: .seconds(2.4))
                // Eased out together, then asked again.
                withAnimation(.easeInOut(duration: 0.45)) {
                    isRecording = false
                    questionShown = false
                }
                try? await Task.sleep(for: .seconds(0.5))
                replay += 1
                withAnimation(.easeOut(duration: 0.25)) { questionShown = true }
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            Text("Question 1 of 4")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            RevealingQuestion(text: "Tell me about a project you’re proud of.", font: .system(size: 24, weight: .semibold), replay: replay)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(questionShown ? 1 : 0)
                .blur(radius: questionShown ? 0 : 4)
            Spacer(minLength: 0)
            HStack(spacing: AppTheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .strokeBorder(isRecording ? AppTheme.record.opacity(0.35) : Color(.systemGray4), lineWidth: 3)
                        .frame(width: 50, height: 50)
                    RoundedRectangle(cornerRadius: isRecording ? 5 : 20, style: .continuous)
                        .fill(isRecording ? AppTheme.record : AppTheme.buttonFill)
                        .frame(width: isRecording ? 18 : 40, height: isRecording ? 18 : 40)
                        .overlay {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .scaleEffect(isRecording ? 0.3 : 1)
                                .opacity(isRecording ? 0 : 1)
                        }
                }
                Text(isRecording ? "Listening" : "Tap to answer")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isRecording ? AppTheme.record : Color.secondary)
                    .contentTransition(.opacity)
            }
        }
        .padding(AppTheme.Spacing.lg)
        .frame(height: 230)
        .cardBackground()
        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("An interview question, and the button to answer it")
    }
}

/// A score filling in, with the six areas interviewers look for behind it.
private struct ScoreVignette: View {
    let isActive: Bool
    @State private var shown = false

    /// The tallest a bar grows, at 100.
    private static let barHeight: CGFloat = 130

    /// All six areas the score is the average of: (78 + 71 + 87 + 78 + 74 + 80) / 6.
    private let areas: [(ScoreArea, Int)] = [(.technical, 78), (.problemSolving, 71), (.communication, 87), (.projectDepth, 78), (.uncertainty, 74), (.confidence, 80)]

    var body: some View {
        // The score, then its six areas as bars that grow in, side by side,
        // as Screen Time charts a week: each with its score above and its
        // symbol below. Pictures rather than a table of words.
        VStack(spacing: AppTheme.Spacing.xl) {
            ScoreRing(score: 78, caption: "out of 100", size: 140)
                .id(isActive)
            HStack(alignment: .bottom, spacing: AppTheme.Spacing.md) {
                ForEach(Array(areas.enumerated()), id: \.offset) { offset, item in
                    VStack(spacing: AppTheme.Spacing.xs) {
                        Text("\(item.1)")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .opacity(shown ? 1 : 0)
                        // A full-height track with the score filled from the
                        // bottom, in the ring's color for that score.
                        Capsule()
                            .fill(AppTheme.track)
                            .frame(width: 26, height: Self.barHeight)
                            .overlay(alignment: .bottom) {
                                Capsule()
                                    .fill(ScoreRing.color(for: item.1))
                                    .frame(height: shown ? Self.barHeight * CGFloat(item.1) / 100 : 26)
                            }
                        Image(systemName: item.0.symbol)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(height: 24)
                    }
                    .frame(maxWidth: .infinity)
                    .animation(.spring(duration: 0.7, bounce: 0.2).delay(0.3 + Double(offset) * 0.08), value: shown)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(item.0.title), \(item.1)")
                }
            }
            .frame(height: Self.barHeight + 70, alignment: .bottom)
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
        .onChange(of: isActive, initial: true) { _, active in
            shown = false
            if active {
                Task {
                    try? await Task.sleep(for: .seconds(0.1))
                    shown = true
                }
            }
        }
    }
}

/// The candidate's real interview on its stack, and the reminder for it
/// sliding in, as it would on the Lock Screen.
private struct UpcomingVignette: View {
    let isActive: Bool
    @State private var showsBanner = false

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            NotificationPreview(title: "Apple interview in 3 days", message: "A quick practice now keeps your answers sharp.")
                .opacity(showsBanner ? 1 : 0)
                .offset(y: showsBanner ? 0 : -24)
                .scaleEffect(showsBanner ? 1 : 0.96)
            ZStack(alignment: .top) {
                // The next ones peek out beneath, as on Home.
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground).opacity(0.6))
                    .frame(height: 170)
                    .padding(.horizontal, 28)
                    .offset(y: 20)
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground).opacity(0.85))
                    .frame(height: 170)
                    .padding(.horizontal, 14)
                    .offset(y: 10)
                interviewCard
            }
            .padding(.bottom, 20)
        }
        .onChange(of: isActive, initial: true) { _, active in
            showsBanner = false
            guard active else { return }
            withAnimation(.spring(duration: 0.6, bounce: 0.3).delay(0.5)) { showsBanner = true }
        }
    }

    private var interviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apple")
                        .cardTitleStyle()
                    Text("Software Engineer")
                }
                Spacer()
                VStack(spacing: -2) {
                    Text("OCT")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("15")
                        .font(.title2.bold())
                }
                .frame(width: 56, height: 56)
                .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Text("In 3 days at 3:00 PM")
                .font(.subheadline.weight(.medium))
            HStack {
                Text("Not practiced yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Label("Quick Prep", systemImage: "bolt.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .frame(minHeight: 44)
                    .background(AppTheme.buttonFill, in: Capsule())
            }
        }
        .padding(AppTheme.Spacing.md)
        .cardBackground()
        .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
        .accessibilityElement(children: .combine)
    }
}

/// A notification as iOS draws one: the app's icon, its name and the time,
/// the title and the message, on a frosted banner.
struct NotificationPreview: View {
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
            // The real app icon, as iOS shows it on a notification.
            AppLogo(size: 38)
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("now")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Profile setup

/// A new account's profile, a question at a time: the role, the experience
/// level, a real interview if there is one, the resume and reminders, then
/// a summary that opens Home. Anything optional can be skipped, and every
/// answer can be changed later in Profile.
struct ProfileSetupView: View {
    @Environment(AppState.self) private var appState

    private enum Step: Int, CaseIterable {
        case role, experience, interview, resume, reminders, done
    }

    @State private var step: Step = .role
    @State private var movingForward = true
    @State private var role = ""
    @State private var experience = Interview.experienceLevels[0]
    @State private var customExperience = ""
    @State private var hasInterview: Bool?
    @State private var company = ""
    @State private var interviewDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var interviewType: InterviewType = .technical
    @State private var resumeSource: ResumeSource?
    @State private var isReadingResume = false
    @State private var couldNotRead = false
    @FocusState private var isTyping: Bool

    private static let roleSuggestions = ["Software Engineer", "iOS Engineer", "Data Analyst", "Product Designer"]

    var body: some View {
        VStack(spacing: 0) {
            if step != .done {
                topBar
            }
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    content
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.top, AppTheme.Spacing.lg)
                .padding(.bottom, AppTheme.Spacing.xl)
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: movingForward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: movingForward ? .leading : .trailing).combined(with: .opacity)
                ))
            }
            .scrollDismissesKeyboard(.interactively)
            bottomButtons
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.sm)
        }
        .groupedBackground()
        .resumeSources($resumeSource) { readResume($0) }
        #if DEBUG
        .onAppear {
            // `-step N` opens setup at a step, for screenshots.
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "-step"), arguments.indices.contains(index + 1),
               let number = Int(arguments[index + 1]), let debugStep = Step(rawValue: number) {
                role = "iOS Engineer"
                hasInterview = true
                company = "Apple"
                step = debugStep
            }
        }
        #endif
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Button {
                go(to: Step(rawValue: step.rawValue - 1) ?? .role, forward: false)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .opacity(step == .role ? 0 : 1)
            .disabled(step == .role)
            .accessibilityLabel("Back")

            SegmentedProgress(total: Step.allCases.count - 1, completed: step.rawValue + 1)

            Button("Skip") { advance(skipping: true) }
                .font(.body)
                .frame(minWidth: 44, minHeight: 44)
                .opacity(isOptional ? 1 : 0)
                .disabled(!isOptional)
        }
        .foregroundStyle(AppTheme.brand)
        .padding(.horizontal, AppTheme.Spacing.xs)
    }

    private var isOptional: Bool {
        [.interview, .resume, .reminders].contains(step)
    }

    @ViewBuilder
    private var bottomButtons: some View {
        switch step {
        case .resume:
            VStack(spacing: AppTheme.Spacing.xs) {
                PrimaryButton(title: appState.resume.context == nil ? "Choose a File" : "Continue") {
                    if appState.resume.context == nil { resumeSource = .file } else { advance() }
                }
                .disabled(isReadingResume)
                if appState.resume.context == nil {
                    // No resume yet: one can be written from notes.
                    Button("Build One for Me") { resumeSource = .build }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.brand)
                        .frame(minHeight: 44)
                        .disabled(isReadingResume)
                }
            }
        case .reminders:
            VStack(spacing: AppTheme.Spacing.xs) {
                PrimaryButton(title: "Turn On Reminders") {
                    appState.remindersOn = true
                    advance()
                }
                Button("Not Now") {
                    appState.remindersOn = false
                    advance()
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.brand)
                .frame(minHeight: 44)
            }
        case .done:
            VStack(spacing: AppTheme.Spacing.xs) {
                PrimaryButton(title: "Start First Interview") {
                    withAnimation(.smooth(duration: 0.4)) { appState.needsProfileSetup = false }
                    // Straight into the first interview, from Home.
                    appState.startInterview(firstInterview, resume: appState.resume.context)
                }
                Button("Go to Home") {
                    withAnimation(.smooth(duration: 0.4)) { appState.needsProfileSetup = false }
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.brand)
                .frame(minHeight: 44)
            }
        default:
            PrimaryButton(title: "Continue") { advance() }
                .disabled(!canContinue)
        }
    }

    private var canContinue: Bool {
        switch step {
        case .role: !role.trimmingCharacters(in: .whitespaces).isEmpty
        case .experience: experience != Interview.customExperience || !customExperience.trimmingCharacters(in: .whitespaces).isEmpty
        case .interview: hasInterview != nil && (hasInterview == false || !company.trimmingCharacters(in: .whitespaces).isEmpty)
        default: true
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case .role: roleStep
        case .experience: experienceStep
        case .interview: interviewStep
        case .resume: resumeStep
        case .reminders: remindersStep
        case .done: doneStep
        }
    }

    private func heading(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .tracking(-0.5)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppTheme.Spacing.headingMargin - AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.xs)
    }

    private static let roles: [(title: String, symbol: String)] = [
        ("Software Engineer", "chevron.left.forwardslash.chevron.right"),
        ("iOS Engineer", "iphone"),
        ("Data Analyst", "chart.bar.xaxis"),
        ("Product Designer", "paintbrush.pointed"),
    ]

    private var roleStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            heading("What role are you preparing for?", "Questions are picked for it.")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Self.roles, id: \.title) { item in
                    ChoiceTile(symbol: item.symbol, title: item.title, isSelected: role == item.title) {
                        role = item.title
                        isTyping = false
                    }
                }
            }
            TextField("Another role", text: Binding(
                get: { Self.roles.contains { $0.title == role } ? "" : role },
                set: { role = $0 }
            ))
                .focused($isTyping)
                .submitLabel(.continue)
                .onSubmit { if canContinue { advance() } }
                .padding(.horizontal, AppTheme.Spacing.md)
                .frame(minHeight: 52)
                .cardBackground()
        }
    }

    private static let experienceDetails: [String: (symbol: String, detail: String)] = [
        "Internship": ("graduationcap.fill", "Studying, and after an internship"),
        "New Graduate": ("star.fill", "Finished studying, after a first job"),
        Interview.customExperience: ("pencil", "Describe your own level"),
    ]

    private var experienceStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            heading("How much experience do you have?", "So questions match where you are.")
            VStack(spacing: 12) {
                ForEach(Interview.experienceLevels + [Interview.customExperience], id: \.self) { level in
                    let details = Self.experienceDetails[level] ?? ("person.fill", "")
                    ChoiceCard(symbol: details.symbol, title: level, detail: details.detail, isSelected: experience == level) {
                        experience = level
                    }
                }
            }
            if experience == Interview.customExperience {
                TextField("Enter Experience Level", text: $customExperience)
                    .focused($isTyping)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .frame(minHeight: 52)
                    .cardBackground()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.smooth(duration: 0.25), value: experience)
    }

    private var interviewStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            heading("Do you have an interview coming up?", "We’ll help you prepare for that exact one.")
            HStack(spacing: 12) {
                ChoiceTile(symbol: "calendar.badge.checkmark", title: "Yes, I do", isSelected: hasInterview == true) { hasInterview = true }
                ChoiceTile(symbol: "calendar", title: "Not yet", isSelected: hasInterview == false) { hasInterview = false }
            }

            if hasInterview == true {
                VStack(spacing: 0) {
                    TextField("Company", text: $company)
                        .focused($isTyping)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .frame(minHeight: 52)
                    Divider().padding(.leading, AppTheme.Spacing.md)
                    DatePicker("Date", selection: $interviewDate, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .frame(minHeight: 52)
                    Divider().padding(.leading, AppTheme.Spacing.md)
                    HStack {
                        Text("Type")
                        Spacer()
                        Picker("Type", selection: $interviewType) {
                            ForEach(InterviewType.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden()
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .frame(minHeight: 52)
                }
                .tint(AppTheme.brand)
                .cardBackground()
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.smooth(duration: 0.3), value: hasInterview)
    }

    /// A page waiting for the resume, then the resume itself.
    private var resumeStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            heading("Add your resume", "You’ll be asked about your own projects, like a real interview. It stays on your phone.")
            ZStack {
                if let context = appState.resume.context {
                    ResumePage(context: context)
                        .scaleEffect(1.6)
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white, AppTheme.practiced)
                                .offset(x: 50, y: -50)
                        }
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                        .foregroundStyle(.tertiary)
                        .frame(width: ResumePage.width * 1.6, height: ResumePage.height * 1.6)
                        .overlay {
                            if isReadingResume {
                                ProgressView()
                            } else {
                                Image(systemName: "doc.badge.plus")
                                    .font(.system(size: 34))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: ResumePage.height * 1.6 + 20)
            .animation(.spring(duration: 0.5, bounce: 0.25), value: appState.resume.context != nil)
            Text(isReadingResume ? "Reading your resume…" : couldNotRead ? "Couldn’t read that file. Try a PDF or Word file." : appState.resume.context == nil ? "PDF or Word, from Files" : "Questions will use your projects.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }

    /// The reminder as it'll arrive, sliding in.
    private var remindersStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xl) {
            heading("Stay on track", "A reminder before each interview, and a nudge when it’s time to practice.")
            ReminderPreview(company: company.isEmpty ? "Your" : company)
        }
    }

    /// The interview the first one will be: the real one if there is one,
    /// otherwise a technical interview for the chosen role.
    private var firstInterview: Interview {
        if let next = appState.upcomingInterviews.first { return next }
        return Interview(role: appState.targetRole, experienceLevel: appState.experienceLevel, type: .technical)
    }

    /// Not a summary of what was just entered, but the first interview,
    /// ready to start.
    private var doneStep: some View {
        let interview = firstInterview
        let topics = MockInterviewService.topicCapacity(forMinutes: interview.durationMinutes)
        return VStack(spacing: AppTheme.Spacing.lg) {
            VStack(spacing: AppTheme.Spacing.md) {
                // The real app icon, as the Home Screen will show it.
                AppLogo(size: 84)
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
                    .padding(.top, AppTheme.Spacing.lg)
                VStack(spacing: AppTheme.Spacing.xs) {
                    Text("You’re all set, \(appState.candidateName).")
                        .font(.system(size: 30, weight: .bold))
                        .tracking(-0.5)
                        .multilineTextAlignment(.center)
                    Text("Your first interview is ready.")
                        .foregroundStyle(.secondary)
                }
            }

            // The first interview, ready to start.
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text("Your First Interview")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(interview.title)
                        .font(.headline)
                    Text("\(interview.type.interviewName), \(topics) questions, about \(interview.durationMinutes) minutes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if appState.resume.context != nil {
                        Text("Asks about the projects on your resume")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(AppTheme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .cardBackground()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Moving through

    private func advance(skipping: Bool = false) {
        isTyping = false
        if !skipping { save() }
        if let next = Step(rawValue: step.rawValue + 1) { go(to: next, forward: true) }
    }

    private func go(to next: Step, forward: Bool) {
        movingForward = forward
        withAnimation(.smooth(duration: 0.35)) { step = next }
    }

    /// Keeps each answer as soon as it's given.
    private func save() {
        switch step {
        case .role:
            appState.targetRole = role.trimmingCharacters(in: .whitespaces)
        case .experience:
            appState.experienceLevel = experience == Interview.customExperience
                ? customExperience.trimmingCharacters(in: .whitespaces)
                : experience
        case .interview:
            guard hasInterview == true else { return }
            let name = company.trimmingCharacters(in: .whitespaces)
            appState.saveUpcomingInterview(Interview(
                role: appState.targetRole,
                company: name.isEmpty ? nil : name,
                experienceLevel: appState.experienceLevel,
                type: interviewType,
                date: interviewDate
            ))
        default:
            break
        }
    }

    private func readResume(_ fileName: String) {
        isReadingResume = true
        couldNotRead = false
        Task {
            let result = await AppState.readResume(named: fileName)
            withAnimation {
                if result.context != nil { appState.resume = result } else { couldNotRead = true }
            }
            isReadingResume = false
        }
    }
}

/// A big choice, as Setup Assistant offers them: a symbol and a name on a
/// card, outlined in the accent with a check when chosen.
private struct ChoiceTile: View {
    let symbol: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(isSelected ? AppTheme.brand : Color.secondary)
                    .frame(height: 30)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .padding(AppTheme.Spacing.md)
            .cardBackground()
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .strokeBorder(isSelected ? AppTheme.graphic : .clear, lineWidth: 2)
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, AppTheme.graphic)
                        .padding(12)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .scaleEffect(isSelected ? 1 : 0.98)
            .animation(.spring(duration: 0.3, bounce: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// A wide choice: a symbol, a name and a line on what it means.
private struct ChoiceCard: View {
    let symbol: String
    let title: String
    let detail: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppTheme.brand : Color.secondary)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppTheme.graphic : Color(.tertiaryLabel))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(AppTheme.Spacing.md)
            .frame(minHeight: 72)
            .cardBackground()
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .strokeBorder(isSelected ? AppTheme.graphic : .clear, lineWidth: 2)
            }
            .animation(.spring(duration: 0.3, bounce: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The Lock Screen as the reminder will arrive on it: the time large, and
/// the notification sliding in under it.
private struct ReminderPreview: View {
    let company: String
    @State private var arrived = false

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            VStack(spacing: 0) {
                Text("Monday 12 October")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text("9:41")
                    .font(.system(size: 64, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.top, AppTheme.Spacing.lg)
            NotificationPreview(
                title: company == "Your" ? "Your interview is in 3 days" : "\(company) interview in 3 days",
                message: "A quick practice now keeps your answers sharp."
            )
            .padding(.horizontal, AppTheme.Spacing.sm)
            .opacity(arrived ? 1 : 0)
            .offset(y: arrived ? 0 : -30)
            .scaleEffect(arrived ? 1 : 0.95)
            Spacer(minLength: AppTheme.Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
        .background(
            LinearGradient(colors: [Color(red: 0.24, green: 0.27, blue: 0.36), Color(red: 0.52, green: 0.36, blue: 0.32)], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
        )
        .environment(\.colorScheme, .dark)
        .task {
            try? await Task.sleep(for: .seconds(0.5))
            withAnimation(.spring(duration: 0.6, bounce: 0.3)) { arrived = true }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Welcome") {
    WelcomeView()
        .environment(AppState())
}

#Preview("Profile Setup") {
    ProfileSetupView()
        .environment(AppState())
}

import QuickLook
import SwiftUI
import UserNotifications

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

/// A new account's profile, a question at a time: the role, where they are
/// in their career, a real interview if there is one, the resume and
/// notifications, then a finish that opens the first interview or Home.
/// Anything optional can be skipped, every answer stays put going back and
/// forth, and all of it can be changed later in Profile.
struct ProfileSetupView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    private enum Step: Int, CaseIterable {
        case role, experience, interview, resume, notifications, done
    }

    @State private var step: Step = .role
    @State private var movingForward = true
    /// One of `roles`' titles, or `otherRole` for a role typed in.
    @State private var roleChoice: String?
    @State private var otherRole = ""
    @State private var stage: CareerStage?
    @State private var studyYear = 2
    @State private var workYears = 3
    @State private var hasInterview: Bool?
    @State private var company = ""
    @State private var interviewDate = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var interviewType: InterviewType = .technical
    @State private var resumeSource: ResumeSource?
    /// The file being read, while it's read.
    @State private var readingFileName: String?
    @State private var readError: String?
    /// The picked file the current resume was read from; a resume with any
    /// other name was built from notes.
    @State private var uploadedFileName: String?
    @State private var previewURL: URL?
    @State private var previewUnavailable = false
    @State private var isConfirmingDelete = false
    @State private var notificationStatus: UNAuthorizationStatus?
    @State private var isAskingForNotifications = false
    @FocusState private var focusedField: Field?

    private enum Field { case otherRole, company }

    private static let otherRole = "Other"

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
        .quickLookPreview($previewURL)
        .confirmationDialog("Delete this resume?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Resume", role: .destructive) { deleteResume() }
        } message: {
            Text(resumeIsBuilt
                 ? "The resume and the notes it was written from are deleted. You can add another or skip this step."
                 : "It’s removed from Rehearse. The file in Files isn’t touched. You can add another or skip this step.")
        }
        .alert("Can’t Preview This Resume", isPresented: $previewUnavailable) {
            Button("Choose Again") { resumeSource = .file }
            Button("OK", role: .cancel) {}
        } message: {
            Text("The file is no longer available. Choose it again from Files.")
        }
        // Coming back from Settings may have changed the answer.
        .task(id: step) { if step == .notifications { await refreshNotificationStatus() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, step == .notifications { Task { await refreshNotificationStatus() } }
        }
        #if DEBUG
        .onAppear {
            // `-step N` opens setup at a step, for screenshots.
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "-step"), arguments.indices.contains(index + 1),
               let number = Int(arguments[index + 1]), let debugStep = Step(rawValue: number) {
                roleChoice = "iOS Engineer"
                stage = arguments.contains("-professional") ? .professional : .student
                hasInterview = true
                company = "Apple"
                step = debugStep
                // `-openBuilder` opens Build One for Me over the step.
                if arguments.contains("-openBuilder") { resumeSource = .build }
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
                .accessibilityLabel("Step \(step.rawValue + 1) of \(Step.allCases.count - 1)")

            Button("Skip") { advance(skipping: true) }
                .font(.body)
                .frame(minWidth: 44, minHeight: 44)
                .opacity(isOptional ? 1 : 0)
                .disabled(!isOptional)
        }
        .foregroundStyle(AppTheme.brand)
        .padding(.horizontal, AppTheme.Spacing.xs)
    }

    /// Notifications have their own Not Now, so they don't need a Skip.
    private var isOptional: Bool {
        [.interview, .resume].contains(step)
    }

    @ViewBuilder
    private var bottomButtons: some View {
        switch step {
        case .resume:
            VStack(spacing: AppTheme.Spacing.xs) {
                PrimaryButton(title: "Continue") { advance() }
                    .disabled(appState.resume.context == nil || readingFileName != nil)
            }
        case .notifications:
            notificationButtons
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

    /// Asked only while iOS hasn't been asked; once it has, the answer is
    /// respected and Settings is offered instead of asking again.
    @ViewBuilder
    private var notificationButtons: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            switch notificationStatus {
            case .authorized, .provisional, .ephemeral:
                PrimaryButton(title: "Continue") {
                    appState.remindersOn = true
                    advance()
                }
            case .denied:
                PrimaryButton(title: "Continue") {
                    appState.remindersOn = false
                    advance()
                }
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.brand)
                .frame(minHeight: 44)
            default:
                PrimaryButton(title: "Turn On Notifications") {
                    isAskingForNotifications = true
                    Task {
                        appState.remindersOn = await InterviewReminders.requestPermission()
                        await refreshNotificationStatus()
                        isAskingForNotifications = false
                        advance()
                    }
                }
                .disabled(isAskingForNotifications || notificationStatus == nil)
                Button("Not Now") {
                    appState.remindersOn = false
                    advance()
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.brand)
                .frame(minHeight: 44)
                .disabled(isAskingForNotifications)
            }
        }
    }

    private var role: String {
        let choice = roleChoice == Self.otherRole ? otherRole : (roleChoice ?? "")
        return choice.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canContinue: Bool {
        switch step {
        case .role: !role.isEmpty
        case .experience: stage != nil
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
        case .notifications: notificationsStep
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
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// A small label over a group, as Settings heads its sections.
    private func groupLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, AppTheme.Spacing.headingMargin - AppTheme.Spacing.md)
            .padding(.bottom, -AppTheme.Spacing.xs)
            .accessibilityAddTraits(.isHeader)
    }

    private static let roles: [(title: String, symbol: String)] = [
        ("Software Engineer", "chevron.left.forwardslash.chevron.right"),
        ("iOS Engineer", "iphone"),
        ("Data Analyst", "chart.bar.xaxis"),
        ("Product Designer", "paintbrush.pointed"),
        ("Product Manager", "list.bullet.clipboard"),
        (otherRole, "ellipsis.circle"),
    ]

    private var roleStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            heading("What role are you preparing for?", "Questions are picked for it.")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Self.roles, id: \.title) { item in
                    ChoiceTile(symbol: item.symbol, title: item.title, isSelected: roleChoice == item.title) {
                        roleChoice = item.title
                        focusedField = item.title == Self.otherRole ? .otherRole : nil
                    }
                }
            }
            if roleChoice == Self.otherRole {
                // One field, its prompt saying what to type: a label above
                // it would only repeat it.
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "pencil")
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppTheme.brand)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    TextField("Your role", text: $otherRole, prompt: .prompt("Enter your role, e.g. QA Engineer"))
                        .font(.body)
                        .textContentType(.jobTitle)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .otherRole)
                        .submitLabel(.continue)
                        .onSubmit { if canContinue { advance() } }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .frame(minHeight: 56)
                .choiceBackground(isSelected: focusedField == .otherRole)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.smooth(duration: 0.25), value: roleChoice)
    }

    private var experienceStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            heading("Where are you in your career?", "So questions match where you are.")
            VStack(spacing: 12) {
                ForEach(CareerStage.allCases) { option in
                    ChoiceCard(symbol: option.symbol, title: option.title, isSelected: stage == option) {
                        stage = option
                    }
                }
            }
            switch stage {
            case .student:
                ExperienceSlider(
                    question: "Which year of study are you in?",
                    value: $studyYear,
                    range: Experience.studyYears,
                    minimumLabel: "1st",
                    maximumLabel: "4th+",
                    valueText: Experience.studyYearText
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            case .professional:
                ExperienceSlider(
                    question: "How many years of professional experience do you have?",
                    value: $workYears,
                    range: Experience.workYears,
                    minimumLabel: "0",
                    maximumLabel: "20+",
                    valueText: Experience.workYearsText
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            case .graduate, nil:
                EmptyView()
            }
        }
        .animation(.smooth(duration: 0.3), value: stage)
    }

    private var interviewStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            heading("Have an interview coming up?", "We’ll help you prepare for that exact one.")
            HStack(spacing: 12) {
                ChoiceTile(symbol: "calendar.badge.checkmark", title: "Yes, I do", isSelected: hasInterview == true, compact: true) { hasInterview = true }
                ChoiceTile(symbol: "calendar", title: "Not yet", isSelected: hasInterview == false, compact: true) {
                    hasInterview = false
                    focusedField = nil
                }
            }

            if hasInterview == true {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    VStack(spacing: 0) {
                        // A row like Date and Time beneath it: the label on
                        // the left, the name typed on the right.
                        HStack(spacing: AppTheme.Spacing.md) {
                            Text("Company Name")
                            TextField("Company Name", text: $company, prompt: .prompt("Required"))
                                .multilineTextAlignment(.trailing)
                                .textContentType(.organizationName)
                                .textInputAutocapitalization(.words)
                                .focused($focusedField, equals: .company)
                                .submitLabel(.done)
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .frame(minHeight: 52)
                        Divider().padding(.leading, AppTheme.Spacing.md)
                        DatePicker("Date and Time", selection: $interviewDate, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .frame(minHeight: 52)
                    }
                    .tint(AppTheme.brand)
                    .cardBackground()

                    groupLabel("Interview Type")
                    // Both options in one card; each one's ⓘ says who it's for.
                    VStack(spacing: 0) {
                        ForEach(InterviewType.allCases) { option in
                            if option != InterviewType.allCases.first {
                                Divider().padding(.leading, AppTheme.Spacing.md + 28 + AppTheme.Spacing.sm)
                            }
                            TypeOptionRow(type: option, isSelected: interviewType == option) {
                                interviewType = option
                                focusedField = nil
                            }
                        }
                    }
                    .cardBackground()
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, -AppTheme.Spacing.xs)
        .animation(.smooth(duration: 0.3), value: hasInterview)
    }

    // MARK: Resume

    /// Built from notes rather than read from a picked file.
    private var resumeIsBuilt: Bool {
        guard let context = appState.resume.context else { return false }
        return context.fileName != uploadedFileName
    }

    /// Two ways in. A file: the dashed area opens Files from anywhere on
    /// it, then becomes the file with Preview and Replace beneath. No file:
    /// Build One for Me, with what it involves spelled out.
    private var resumeStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            heading("Add your resume", "You’ll be asked about your own projects, like a real interview. It stays on your phone.")

            if let context = appState.resume.context, readingFileName == nil {
                pickedResume(context)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                Button {
                    resumeSource = .file
                } label: {
                    ResumeUploadArea(readingFileName: readingFileName, error: readError)
                }
                .buttonStyle(PressableStyle())
                .disabled(readingFileName != nil)
                .accessibilityHint("Opens Files to choose a PDF or Word document.")
            }

            if appState.resume.context == nil {
                groupLabel("No Resume Yet?")
                BuildResumeCard(isBuilt: false) { resumeSource = .build }
                    .disabled(readingFileName != nil)
            }
        }
        .animation(.smooth(duration: 0.3), value: appState.resume.context)
        .animation(.smooth(duration: 0.3), value: readingFileName)
        .animation(.smooth(duration: 0.3), value: readError)
    }

    /// The resume in use: its first page, its name and where it came from,
    /// then Preview and Replace as rows, as Files lists a document's actions.
    private func pickedResume(_ context: ResumeContext) -> some View {
        VStack(spacing: 0) {
            // The resume itself opens it: the page to read and edit for a
            // built one, Quick Look for a file.
            Button(action: previewResume) {
                HStack(spacing: AppTheme.Spacing.md) {
                    ResumePage(context: context, width: 58)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.fileName)
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                        Label(resumeIsBuilt ? "Built from your notes" : "Uploaded and read", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.practiced)
                        Text(resumeIsBuilt ? "Tap to preview and edit" : "Tap to preview")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                .padding(AppTheme.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityElement(children: .combine)
            .accessibilityHint(resumeIsBuilt ? "Opens the resume to preview and edit" : "Opens a preview of the file")

            Divider().padding(.leading, AppTheme.Spacing.md)
            ActionRow(title: resumeIsBuilt ? "Upload a File Instead" : "Choose a Different File", symbol: "arrow.triangle.2.circlepath") {
                resumeSource = .file
            }
            Divider().padding(.leading, AppTheme.Spacing.md)
            ActionRow(title: "Delete Resume", symbol: "trash", isDestructive: true) {
                isConfirmingDelete = true
            }
            if let readError {
                Divider()
                Label(readError, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.record)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppTheme.Spacing.md)
            }
        }
        .cardBackground()
    }

    /// The picked file in Quick Look (PDF, Word and the rest), or the page
    /// written from notes, editable.
    private func previewResume() {
        if resumeIsBuilt {
            // The builder opens on the page it wrote, to read and edit. If
            // its notes weren't kept, they're taken back from the page.
            if appState.resumeDraft == nil, let context = appState.resume.context {
                appState.resumeDraft = ResumeDraft(context: context, role: appState.targetRole)
            }
            appState.builderOpensOnPage = true
            resumeSource = .build
        } else if let name = uploadedFileName, let file = ResumeReader.keptFile(named: name) {
            previewURL = file
        } else {
            previewUnavailable = true
        }
    }

    // MARK: Notifications

    /// The reminder as it'll arrive, sliding in, and where things stand if
    /// iOS has already been asked.
    private var notificationsStep: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            heading("Turn on notifications", "Get a reminder before each interview you add, and a nudge when it’s time to practice. You can change this anytime in Profile.")
            ReminderPreview(company: company.trimmingCharacters(in: .whitespaces).isEmpty ? "Your" : company)
            switch notificationStatus {
            case .authorized, .provisional, .ephemeral:
                Label("Notifications are already on for Rehearse.", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.practiced)
                    .padding(.horizontal, AppTheme.Spacing.headingMargin - AppTheme.Spacing.md)
            case .denied:
                Label("Notifications are off for Rehearse. You can turn them on in Settings whenever you like.", systemImage: "bell.slash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, AppTheme.Spacing.headingMargin - AppTheme.Spacing.md)
            default:
                EmptyView()
            }
        }
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await InterviewReminders.authorizationStatus()
    }

    // MARK: Done

    /// The interview the first one will be: the real one if there is one,
    /// otherwise a technical interview for the chosen role.
    private var firstInterview: Interview {
        if let next = appState.upcomingInterviews.first { return next }
        return Interview(role: appState.targetRole, experienceLevel: appState.experienceLevel, type: .technical)
    }

    /// A check that says it's done, then the first interview, ready to start.
    private var doneStep: some View {
        let interview = firstInterview
        let topics = MockInterviewService.topicCapacity(forMinutes: interview.durationMinutes)
        return VStack(spacing: AppTheme.Spacing.lg) {
            VStack(spacing: AppTheme.Spacing.md) {
                CompletionCheck()
                    .padding(.top, AppTheme.Spacing.xl)
                VStack(spacing: AppTheme.Spacing.xs) {
                    Text("You’re all set, \(appState.candidateName).")
                        .font(.system(size: 30, weight: .bold))
                        .tracking(-0.5)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text("Your profile is ready, and so is your first interview.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

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
            .cardBackground()
            .accessibilityElement(children: .combine)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Moving through

    private func advance(skipping: Bool = false) {
        focusedField = nil
        if !skipping { save() }
        if let next = Step(rawValue: step.rawValue + 1) { go(to: next, forward: true) }
    }

    private func go(to next: Step, forward: Bool) {
        focusedField = nil
        movingForward = forward
        withAnimation(.smooth(duration: 0.35)) { step = next }
    }

    /// Keeps each answer as soon as it's given.
    private func save() {
        switch step {
        case .role:
            appState.targetRole = role
        case .experience:
            guard let stage else { return }
            appState.experienceLevel = Experience.level(stage: stage, studyYear: studyYear, workYears: workYears)
        case .interview:
            guard hasInterview == true else { return }
            let name = company.trimmingCharacters(in: .whitespaces)
            // Going back and on again updates the same interview rather
            // than adding a second.
            var interview = Interview(
                role: appState.targetRole,
                company: name.isEmpty ? nil : name,
                experienceLevel: appState.experienceLevel,
                type: interviewType,
                date: interviewDate
            )
            if let savedInterviewID { interview.id = savedInterviewID }
            savedInterviewID = interview.id
            appState.saveUpcomingInterview(interview)
        default:
            break
        }
    }

    @State private var savedInterviewID: Interview.ID?

    private static let readableExtensions: Set<String> = ["pdf", "docx", "doc", "rtf", "txt", "heic", "jpg", "jpeg", "png"]

    /// Back to no resume: the kept copy of a picked file, or the builder's
    /// notes for a built one, go with it.
    private func deleteResume() {
        if let name = uploadedFileName, let file = ResumeReader.keptFile(named: name) {
            try? FileManager.default.removeItem(at: file)
        }
        if resumeIsBuilt { appState.resumeDraft = nil }
        withAnimation(.smooth(duration: 0.3)) {
            appState.removeResume()
            uploadedFileName = nil
            readError = nil
        }
    }

    private func readResume(_ fileName: String) {
        readError = nil
        guard Self.readableExtensions.contains((fileName as NSString).pathExtension.lowercased()) else {
            readError = "“\(fileName)” isn’t a file we can read. Choose a PDF or Word document."
            return
        }
        readingFileName = fileName
        Task {
            let result = await AppState.readResume(named: fileName)
            withAnimation {
                switch result {
                case .ready:
                    uploadedFileName = fileName
                    appState.resume = result
                case .failed(_, let reason):
                    readError = reason
                default:
                    break
                }
                readingFileName = nil
            }
        }
    }
}

// MARK: - Pieces

/// Gives a large tappable area the feel of a button: it sinks a little and
/// dims while pressed.
private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.2), value: configuration.isPressed)
    }
}

/// A question answered with a slider: the answer large above it, updating
/// as it moves, and the two ends labelled.
private struct ExperienceSlider: View {
    let question: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let minimumLabel: String
    let maximumLabel: String
    let valueText: (Int) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(question)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            Text(valueText(value))
                .font(.system(.title, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.brand)
                .contentTransition(.numericText(value: Double(value)))
                .animation(.snappy(duration: 0.2), value: value)
                .accessibilityHidden(true)
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0.rounded()) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1
            ) {
                Text(question)
            } minimumValueLabel: {
                Text(minimumLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            } maximumValueLabel: {
                Text(maximumLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .tint(AppTheme.brand)
            .accessibilityValue(valueText(value))
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
        .sensoryFeedback(.selection, trigger: value)
    }
}

/// The resume step's tappable area before there's a resume: waiting for a
/// file, reading one, or why the last one couldn't be read.
private struct ResumeUploadArea: View {
    let readingFileName: String?
    let error: String?

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            if let readingFileName {
                ProgressView()
                    .controlSize(.large)
                Text("Reading \(readingFileName)…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(AppTheme.brand)
                    .frame(width: 60, height: 60)
                    .background(AppTheme.graphic.opacity(0.12), in: Circle())
                VStack(spacing: 2) {
                    Text(error == nil ? "Choose a File" : "Choose Another File")
                        .font(.headline)
                        .foregroundStyle(AppTheme.brand)
                    Text("PDF or Word document, from Files")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.record)
                        .multilineTextAlignment(.center)
                        .padding(.top, AppTheme.Spacing.xxs)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 176)
        .background(AppTheme.cardFill, in: RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [7, 6]))
                .foregroundStyle(error == nil ? AppTheme.graphic.opacity(0.5) : AppTheme.record.opacity(0.6))
        }
        .contentShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// A row that acts on the resume, in the accent, as Files lists actions.
private struct ActionRow: View {
    let title: String
    let symbol: String
    /// Red and without a chevron, for an action that removes something.
    var isDestructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: symbol)
                    .font(.body.weight(.medium))
                    .frame(width: 24)
                Text(title)
                    .font(.body.weight(.medium))
                Spacer(minLength: 0)
                if !isDestructive {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
            .foregroundStyle(isDestructive ? AppTheme.record : AppTheme.brand)
            .padding(.horizontal, AppTheme.Spacing.md)
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }
}

/// Build One for Me: one row that opens the builder, which explains its
/// steps at the top.
private struct BuildResumeCard: View {
    let isBuilt: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "square.and.pencil")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.brand)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.graphic.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(isBuilt ? "Edit in the Builder" : "Build One for Me")
                            .font(.headline)
                            .foregroundStyle(Color.primary)
                        Text("Written from your notes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
            }
            .multilineTextAlignment(.leading)
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .choiceBackground(isSelected: false)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// The finish: a green check drawn into a circle. It's paired with "You're
/// all set" and has its own label, so it never relies on color alone.
private struct CompletionCheck: View {
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(AppTheme.success.opacity(0.14))
                .frame(width: 104, height: 104)
            Circle()
                .fill(AppTheme.practiced)
                .frame(width: 76, height: 76)
            Image(systemName: "checkmark")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
                .symbolEffect(.drawOn, isActive: !shown)
        }
        .scaleEffect(shown ? 1 : 0.7)
        .opacity(shown ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Setup complete")
        .sensoryFeedback(.success, trigger: shown)
        .task {
            guard !shown else { return }
            if reduceMotion {
                shown = true
                return
            }
            try? await Task.sleep(for: .seconds(0.15))
            withAnimation(.spring(duration: 0.5, bounce: 0.35)) { shown = true }
        }
    }
}

/// A big choice, as Setup Assistant offers them: a symbol and a name on a
/// card. Unchosen it's a plain card with a hairline edge; chosen it takes
/// the accent's outline, a tint and a check; disabled it fades back.
private struct ChoiceTile: View {
    let symbol: String
    let title: String
    let isSelected: Bool
    /// One line, symbol beside the name, for a quick yes or no.
    var compact = false
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            if compact { compactLabel } else { label }
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.selection, trigger: isSelected) { _, new in new }
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// A radio check then the name, as Settings lists one-of-two choices.
    private var compactLabel: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            SelectionMark(isSelected: isSelected)
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 58)
        .choiceBackground(isSelected: isSelected)
        .opacity(isEnabled ? 1 : 0.45)
        .animation(.spring(duration: 0.3, bounce: 0.2), value: isSelected)
    }

    private var label: some View {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(isSelected ? AppTheme.brand : Color.primary.opacity(0.7))
                    .frame(height: 30)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .padding(AppTheme.Spacing.md)
            .choiceBackground(isSelected: isSelected)
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, AppTheme.brand)
                        .padding(12)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.spring(duration: 0.3, bounce: 0.3), value: isSelected)
    }
}

/// An interview type as a row: a radio check, its name, and a short line
/// on who it's for.
private struct TypeOptionRow: View {
    let type: InterviewType
    let isSelected: Bool
    let action: () -> Void
    @State private var isShowingInfo = false

    var body: some View {
        HStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    SelectionMark(isSelected: isSelected)
                        .frame(width: 28)
                    Text(type.interviewName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Spacer(minLength: 0)
                }
                .padding(.leading, AppTheme.Spacing.md)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .sensoryFeedback(.selection, trigger: isSelected) { _, new in new }
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)

            // Who it's for, on demand, rather than a line under each.
            Button {
                isShowingInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundStyle(AppTheme.brand)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, AppTheme.Spacing.xs)
            .accessibilityLabel("About \(type.interviewName)")
            .popover(isPresented: $isShowingInfo) {
                Text(type.summary)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 260, alignment: .leading)
                    .padding()
                    .presentationCompactAdaptation(.popover)
            }
        }
        .background(isSelected ? AppTheme.graphic.opacity(0.06) : .clear)
        .animation(.smooth(duration: 0.2), value: isSelected)
    }
}

/// A wide choice: a symbol and a name.
private struct ChoiceCard: View {
    let symbol: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppTheme.brand : Color.primary.opacity(0.7))
                    .frame(width: 30)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                Spacer(minLength: 0)
                SelectionMark(isSelected: isSelected)
            }
            .multilineTextAlignment(.leading)
            .padding(AppTheme.Spacing.md)
            .frame(minHeight: 72)
            .choiceBackground(isSelected: isSelected)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.spring(duration: 0.3, bounce: 0.2), value: isSelected)
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.selection, trigger: isSelected) { _, new in new }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private extension View {
    /// A choice's card: a hairline edge so it reads as tappable, and once
    /// chosen the accent's outline over a faint tint of it.
    func choiceBackground(isSelected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
        return background {
            shape.fill(AppTheme.cardFill)
            if isSelected { shape.fill(AppTheme.graphic.opacity(0.08)) }
        }
        .overlay {
            shape.strokeBorder(isSelected ? AppTheme.graphic : Color(.separator).opacity(0.6), lineWidth: isSelected ? 2 : 0.5)
        }
        .contentShape(shape)
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
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
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

#Preview("Profile Setup") {
    ProfileSetupView()
        .environment(AppState())
}

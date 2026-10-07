import SwiftUI

struct RehearseView: View {
    @Environment(AppState.self) private var appState
    @State private var showSetup = false
    @State private var setupMode: SetupMode = .upcoming
    @State private var showLibrary = false
    @State private var selectedFeedback: Feedback?

    var body: some View {
        NavigationStack {
            AppScreen {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Rehearsal Studio")
                                .font(.largeTitle.weight(.bold))
                                .foregroundStyle(AppTheme.text)
                            Text("Simulate live interviews under realistic timing and pressure.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        // Target scenario showcase
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "TARGET SCENARIO")
                            GroupedSurface(style: .standard) {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(appState.interview.role)
                                                .font(.title3.weight(.bold))
                                                .foregroundStyle(AppTheme.text)
                                            Text("\(appState.interview.company) · \(appState.interview.interviewType)")
                                                .font(.subheadline)
                                                .foregroundStyle(AppTheme.secondaryText)
                                        }
                                        Spacer(minLength: 12)
                                        Text("\(appState.interview.duration) min")
                                            .font(.caption.weight(.semibold).monospacedDigit())
                                            .foregroundStyle(AppTheme.secondaryText)
                                    }

                                    HStack(spacing: 16) {
                                        Label(appState.interview.date.formatted(.dateTime.month(.wide).day()), systemImage: "calendar")
                                        Label("Speech AI Enabled", systemImage: "waveform")
                                    }
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppTheme.secondaryText)

                                    PrimaryButton(title: "Launch Rehearsal", icon: "mic.fill") {
                                        setupMode = .upcoming
                                        showSetup = true
                                    }
                                }
                                .padding(20)
                            }
                        }

                        // Custom scenario configurator
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "CUSTOM PRACTICE")
                            GroupedSurface(style: .subtle) {
                                Button {
                                    AppTheme.Haptics.light()
                                    setupMode = .custom
                                    showSetup = true
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: "slider.horizontal.3")
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.text)
                                            .frame(width: 38, height: 38)
                                            .background(AppTheme.surface, in: Circle())

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Configure Custom Scenario")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(AppTheme.text)
                                            Text("Change role, company, focus area, or time limit")
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.secondaryText)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(AppTheme.tertiaryText)
                                    }
                                    .padding(16)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Question Library entry
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "QUESTION LIBRARY")
                            GroupedSurface(style: .standard) {
                                Button {
                                    AppTheme.Haptics.light()
                                    showLibrary = true
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: "books.vertical.fill")
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.brand)
                                            .frame(width: 38, height: 38)
                                            .background(AppTheme.brandTint, in: Circle())

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Explore Practice Questions")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(AppTheme.text)
                                            Text("20+ curated prompts across Behavioral and Technical")
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.secondaryText)
                                        }

                                        Spacer()

                                        Image(systemName: "arrow.right")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(AppTheme.brand)
                                    }
                                    .padding(16)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 96)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Studio")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showSetup) {
                InterviewSetupView(mode: setupMode)
            }
            .navigationDestination(isPresented: $showLibrary) {
                QuestionLibraryView()
            }
            .navigationDestination(item: $selectedFeedback) { feedback in
                FeedbackView(feedback: feedback)
            }
        }
    }
}

enum SetupMode: Equatable {
    case upcoming
    case custom
}

struct InterviewSetupView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let mode: SetupMode

    @State private var role: String
    @State private var company: String
    @State private var experienceLevel: String
    @State private var interviewType: String
    @State private var duration: Int
    @State private var resumeAttached: Bool
    @State private var showReady = false

    init(mode: SetupMode) {
        self.mode = mode
        let interview = MockData.upcomingInterview
        _role = State(initialValue: interview.role)
        _company = State(initialValue: interview.company)
        _experienceLevel = State(initialValue: interview.experienceLevel)
        _interviewType = State(initialValue: interview.interviewType)
        _duration = State(initialValue: interview.duration)
        _resumeAttached = State(initialValue: interview.resumeName != nil)
    }

    private var draftInterview: Interview {
        Interview(
            role: role,
            company: company,
            experienceLevel: experienceLevel,
            interviewType: interviewType,
            date: appState.interviewDate,
            duration: duration,
            resumeName: resumeAttached ? "Alex_Resume.pdf" : nil
        )
    }

    private var title: String {
        mode == .custom ? "Set up a rehearsal" : "Set up your rehearsal"
    }

    private var subtitle: String {
        mode == .custom
            ? "Choose the details for the interview you want to practise."
            : "Make this feel like the interview you’re preparing for."
    }

    var body: some View {
        AppScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(title)
                            .font(.largeTitle.weight(.bold))
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    GroupedSurface(style: .standard) {
                        VStack(spacing: 0) {
                            SetupPickerRow(title: "Role", selection: $role, options: ["Software Engineer", "iOS Engineer", "Backend Engineer", "Product Engineer"])
                            Divider().overlay(AppTheme.subtleBorder).padding(.leading, 18)
                            SetupPickerRow(title: "Company", selection: $company, options: ["Apple", "Google", "Microsoft", "Atlassian"])
                            Divider().overlay(AppTheme.subtleBorder).padding(.leading, 18)
                            SetupPickerRow(title: "Experience Level", selection: $experienceLevel, options: ["3rd Year Student", "4th Year Student", "New Graduate"])
                            Divider().overlay(AppTheme.subtleBorder).padding(.leading, 18)
                            SetupPickerRow(title: "Interview Type", selection: $interviewType, options: ["Technical Interview", "Behavioral Interview", "System Design"])
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Duration")
                        Picker("Duration", selection: $duration) {
                            Text("15 min").tag(15)
                            Text("20 min").tag(20)
                            Text("30 min").tag(30)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: duration) { _, _ in
                            AppTheme.Haptics.selection()
                        }
                        .accessibilityLabel("Rehearsal duration")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Resume")
                        Button {
                            AppTheme.Haptics.light()
                            resumeAttached.toggle()
                        } label: {
                            HStack(spacing: 13) {
                                Image(systemName: resumeAttached ? "doc.fill" : "plus.circle")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(resumeAttached ? AppTheme.brand : AppTheme.secondaryText)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(resumeAttached ? "Alex_Resume.pdf" : "Attach your resume")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.text)
                                    Text(resumeAttached ? "Attached for this rehearsal" : "Optional — use a mock attachment")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                Spacer()
                                Image(systemName: resumeAttached ? "checkmark.circle.fill" : "plus.circle")
                                    .foregroundStyle(resumeAttached ? AppTheme.success : AppTheme.secondaryText)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous)
                                    .stroke(AppTheme.border, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Toggles a simulated resume attachment")
                    }

                    PrimaryButton(title: "Continue", icon: "arrow.right") {
                        showReady = true
                    }
                    .padding(.top, 4)
                }
                .padding(20)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Setup")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showReady) {
            ReadyToRehearseView(interview: draftInterview)
        }
    }
}

private struct SetupPickerRow: View {
    let title: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        Menu {
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
        } label: {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                Text(selection)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 17)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("\(title), \(selection)")
    }
}

struct ReadyToRehearseView: View {
    let interview: Interview
    @State private var cameraEnabled = false
    @State private var showInterview = false

    var body: some View {
        AppScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ready to rehearse?")
                            .font(.largeTitle.weight(.bold))
                        Text("Treat this like the real interview.")
                            .font(.title3)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    GroupedSurface(style: .standard) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(interview.role)
                                .font(.title2.weight(.bold))
                            Text("\(interview.company) · \(interview.interviewType)")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                                .padding(.top, 3)
                            Divider().overlay(AppTheme.subtleBorder).padding(.vertical, 16)
                            HStack(spacing: 12) {
                                Label("\(interview.duration) minutes", systemImage: "clock")
                                if let resume = interview.resumeName {
                                    Text("·").foregroundStyle(AppTheme.tertiaryText)
                                    Label(resume, systemImage: "doc.fill")
                                }
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.secondaryText)
                        }
                        .padding(20)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: "Before you begin")
                        GroupedSurface(style: .standard) {
                            VStack(spacing: 14) {
                                PermissionRow(symbol: "mic.fill", title: "Microphone", detail: "Used to simulate your answer", status: "Ready")
                                Divider().overlay(AppTheme.subtleBorder)
                                Toggle(isOn: $cameraEnabled) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "camera.fill")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppTheme.secondaryText)
                                            .frame(width: 20)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Use camera")
                                                .font(.subheadline.weight(.semibold))
                                            Text("Optional communication coaching")
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.secondaryText)
                                        }
                                    }
                                }
                                .tint(AppTheme.brand)
                                .accessibilityHint("Camera is optional and can be left off")
                                Divider().overlay(AppTheme.subtleBorder)
                                PermissionRow(symbol: "ear.fill", title: "Quiet environment", detail: "Find a place to answer aloud", status: "Recommended", tint: AppTheme.secondaryText)
                            }
                            .padding(16)
                        }
                    }

                    PrimaryButton(title: "Begin Rehearsal", icon: "mic.fill") {
                        showInterview = true
                    }
                }
                .padding(20)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showInterview) {
            LiveInterviewView(interview: interview, cameraEnabled: cameraEnabled)
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview("Rehearse") {
    RehearseView()
        .environment(AppState.preview)
}

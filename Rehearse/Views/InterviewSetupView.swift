import SwiftUI

/// The last stop before a rehearsal. For the upcoming interview the context is
/// already known, so it is shown rather than asked for again; a custom mock
/// asks for the role and company, typed in, and the interview type. Both offer the length, which sets how many
/// topics are asked.
struct InterviewSetupView: View {
    let mode: SetupMode

    @Environment(AppState.self) private var appState
    @State private var role = ""
    @State private var company = ""
    @State private var type: InterviewType = .technical
    @State private var durationMinutes = 20

    var body: some View {
        List {
            switch mode {
            case .upcoming(let id): upcomingContext(id)
            case .custom: customContext
            }
            lengthSection
        }
        .contentMargins(.top, AppTheme.Spacing.sm, for: .scrollContent)
        .warmBackground()
        .navigationTitle(mode == .custom ? "Mock Interview" : "Rehearse Interview")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaBar(edge: .bottom) {
            BottomActions {
                PrimaryButton(title: "Start Interview", systemImage: "mic") {
                    if let interview {
                        appState.startInterview(interview, useResume: usesResume)
                    }
                }
                .disabled(interview == nil)
            }
        }
        .onAppear {
            if case .upcoming(let id) = mode, let upcoming = appState.upcomingInterview(id: id) {
                durationMinutes = upcoming.durationMinutes
            }
        }
    }

    /// The interview that will be rehearsed. For the upcoming interview its
    /// identity is kept, so the rehearsal counts towards it on Home.
    private var interview: Interview? {
        switch mode {
        case .upcoming(let id):
            guard var upcoming = appState.upcomingInterview(id: id) else { return nil }
            upcoming.durationMinutes = durationMinutes
            return upcoming
        case .custom:
            let role = role.trimmingCharacters(in: .whitespaces)
            let company = company.trimmingCharacters(in: .whitespaces)
            guard !role.isEmpty else { return nil }
            return Interview(
                role: role,
                company: company.isEmpty ? nil : company,
                experienceLevel: MockData.candidateExperienceLevel,
                type: type,
                durationMinutes: durationMinutes
            )
        }
    }

    /// A resume that's been read is always used; there's no per-interview choice.
    private var usesResume: Bool {
        appState.resume.context != nil
    }

    // MARK: - Context

    @ViewBuilder
    private func upcomingContext(_ id: Interview.ID) -> some View {
        if let upcoming = appState.upcomingInterview(id: id) {
            Section {
                HStack(spacing: AppTheme.Spacing.sm) {
                    DateTile(date: upcoming.date, isHighlighted: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(upcoming.title)
                            .font(.app(.headline))
                        Text([upcoming.type.rawValue + " interview", upcoming.countdownText?.lowercased()].compactMap { $0 }.joined(separator: " "))
                            .font(.app(.subheadline))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, AppTheme.Spacing.xxs)
                .accessibilityElement(children: .combine)
            } header: {
                Group {
                    HStack {
                        Text("Rehearsing for")
                        Spacer()
                        Button("Edit") { appState.interviewEditor = InterviewEditorRequest(interview: upcoming) }
                            .font(.app(.footnote, weight: .semibold))
                            .textCase(nil)
                    }
                }
                .font(.app(.footnote, weight: .semibold))
            } footer: {
                Group {
                    if let focus = appState.currentFocus {
                        Text("Questions are picked for this role and type. Last time it was your \(focus.title.lowercased()), so keep an eye on that.")
                    } else {
                        Text("Questions are picked for this role and type.")
                    }
                }
                .font(.app(.footnote))
            }
        }
    }

    @ViewBuilder
    private var customContext: some View {
        Section {
            LabeledTextField(title: "Role", text: $role, prompt: "iOS Engineer", contentType: .jobTitle)
            LabeledTextField(title: "Company", text: $company, prompt: "Optional", contentType: .organizationName)
        } footer: {
            Group {
                Text("Leave the company blank for a general interview.")
            }
            .font(.app(.footnote))
        }

        Section {
            HStack(spacing: AppTheme.Spacing.sm) {
                ForEach(InterviewType.allCases) { option in
                    typeTile(option)
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        } header: {
            Group {
                Text("Interview type")
            }
            .font(.app(.footnote, weight: .semibold))
        }
    }

    /// One choice of interview type: ink-dark when chosen, as in the reference.
    private func typeTile(_ option: InterviewType) -> some View {
        let isSelected = option == type
        return Button {
            withAnimation(.easeOut(duration: 0.15)) { type = option }
        } label: {
            VStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: option.symbol)
                    .font(.system(size: 18, weight: .regular))
                    .frame(width: 40, height: 40)
                    .background(isSelected ? Color.white.opacity(0.14) : AppTheme.chip, in: Circle())
                Text(option.rawValue)
                    .font(.app(.footnote, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(isSelected ? AppTheme.onInk : Color.primary)
            .frame(maxWidth: .infinity, minHeight: 104)
            .padding(.horizontal, AppTheme.Spacing.xs)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.card - 4)
                        .fill(LinearGradient(colors: [AppTheme.inkHighlight, AppTheme.ink], startPoint: .top, endPoint: .bottom))
                } else {
                    Color.clear.cardBackground(cornerRadius: AppTheme.Radius.card - 4)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.rawValue)
        .accessibilityValue(option.summary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Options

    private var lengthSection: some View {
        Section {
            PillPicker(options: Interview.durations, selection: $durationMinutes) { "\($0) min" }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
        } header: {
            Group {
                Text("Length")
            }
            .font(.app(.footnote, weight: .semibold))
        } footer: {
            Group {
                Text("About \(MockInterviewService.topicCapacity(forMinutes: durationMinutes)) topics. You can stop early.")
            }
            .font(.app(.footnote))
        }
    }
}

private extension InterviewType {
    var symbol: String {
        switch self {
        case .technical: "chevron.left.forwardslash.chevron.right"
        case .behavioral: "person.2"
        case .systemDesign: "square.stack.3d.up"
        }
    }
}

#Preview("Upcoming") {
    NavigationStack { InterviewSetupView(mode: .upcoming(MockData.upcomingInterview.id)) }
        .environment(AppState())
}

#Preview("Custom") {
    NavigationStack { InterviewSetupView(mode: .custom) }
        .environment(AppState(scenario: .newUser))
}

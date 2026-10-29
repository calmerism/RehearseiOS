import SwiftUI

/// Rewrites the Profile resume for one job. The candidate says which job
/// (one of their upcoming interviews, or any role) and can paste the posting;
/// three versions come back, each leading with a different story, with what
/// changed and what the job asks for that the resume doesn't show. Tailoring
/// is mocked.
struct TailorResumeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// The upcoming interview it's for, or `nil` for another role.
    @State private var interviewID: Interview.ID?
    @State private var company = ""
    @State private var role = ""
    @State private var posting = ""
    @State private var phase = Phase.input
    @State private var selection = 0

    private enum Phase {
        case input
        case tailoring
        case results([ResumeVersion])
    }

    init(for interviewID: Interview.ID? = nil) {
        _interviewID = State(initialValue: interviewID)
    }

    var body: some View {
        NavigationStack {
            Form {
                switch phase {
                case .input: input
                case .tailoring: tailoring
                case .results(let versions): results(versions)
                }
            }
            .appListStyle()
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if case .input = phase {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Tailor") { tailor() }
                            .disabled(target == nil)
                    }
                }
            }
            .safeAreaBar(edge: .bottom) {
                if case .results(let versions) = phase {
                    BottomActions {
                        PrimaryButton(title: "Save Version") { save(versions[selection]) }
                    }
                }
            }
        }
        .onAppear {
            if interviewID == nil { interviewID = appState.nextInterview?.id }
            #if DEBUG
            // `-tailorResults` runs the mocked tailoring, for screenshots.
            if ProcessInfo.processInfo.arguments.contains("-tailorResults") { tailor() }
            #endif
        }
    }

    private var navigationTitle: String {
        switch phase {
        case .input, .tailoring: "Tailor Resume"
        case .results: "Choose a Version"
        }
    }

    /// The company and role being tailored for, once there's a role.
    private var target: (company: String?, role: String)? {
        if let interviewID, let interview = appState.upcomingInterview(id: interviewID) {
            return (interview.company, interview.role)
        }
        let role = role.trimmingCharacters(in: .whitespaces)
        let company = company.trimmingCharacters(in: .whitespaces)
        guard !role.isEmpty else { return nil }
        return (company.isEmpty ? nil : company, role)
    }

    // MARK: - Input

    @ViewBuilder
    private var input: some View {
        if !appState.upcomingInterviews.isEmpty {
            Section {
                ForEach(appState.upcomingInterviews) { interview in
                    checkRow(isSelected: interviewID == interview.id) {
                        interviewID = interview.id
                    } label: {
                        Text(interview.company ?? interview.role)
                            .foregroundStyle(Color.primary)
                        Text(interview.role)
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                    }
                }
                checkRow(isSelected: interviewID == nil) {
                    interviewID = nil
                } label: {
                    Text("Another Role")
                        .foregroundStyle(Color.primary)
                }
            } header: {
                Text("Tailor For")
                .listHeadingInset()
            }
        }

        if interviewID == nil {
            Section {
                LabeledTextField(title: "Company Name", text: $company, prompt: "Optional", contentType: .organizationName)
                LabeledTextField(title: "Job Role", text: $role, prompt: "Required", contentType: .jobTitle)
            } header: {
                if appState.upcomingInterviews.isEmpty {
                    Text("Tailor For")
                    .listHeadingInset()
                }
            }
        }

        Section {
            TextField("Job Posting", text: $posting, prompt: .prompt("Paste it here"), axis: .vertical)
                .lineLimit(5...10)
        } header: {
            // Optional in the heading itself, where it's read first, as the
            // other fields say it in their placeholders.
            HStack(alignment: .firstTextBaseline) {
                Text("Job Posting")
                Spacer()
                Text("Optional")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .listHeadingInset()
        }
    }

    /// One choice, checked when chosen, as in Settings.
    private func checkRow<Label: View>(isSelected: Bool, action: @escaping () -> Void, @ViewBuilder label: () -> Label) -> some View {
        Button {
            withAnimation { action() }
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) { label() }
                Spacer(minLength: AppTheme.Spacing.xs)
                SelectionMark(isSelected: isSelected)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Tailoring

    private var tailoring: some View {
        Section {
            HStack(spacing: AppTheme.Spacing.sm) {
                ProgressView()
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text("Tailoring for \(target?.company ?? target?.role ?? "this role")…")
                    Text("Trying three ways to lead your resume.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, AppTheme.Spacing.xs)
        }
    }

    private func tailor() {
        guard let target else { return }
        withAnimation { phase = .tailoring }
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            guard case .tailoring = phase else { return }
            selection = 0
            withAnimation { phase = .results(MockData.tailoredVersions(company: target.company, role: target.role)) }
        }
    }

    // MARK: - Results

    /// The three versions as tabs, the chosen one's page right beneath at a
    /// readable size, so choosing and seeing are one step; then, in a line
    /// each, what it changed.
    @ViewBuilder
    private func results(_ versions: [ResumeVersion]) -> some View {
        Section {
            Picker("Version", selection: $selection.animation(.snappy(duration: 0.25))) {
                ForEach(versions.indices, id: \.self) { index in
                    Text(versions[index].lead).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }

        Section {
            FittedResumePage(context: versions[selection].context)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }

        ResumeVersionDetails(version: versions[selection], linksQuestions: false, isCompact: true)
    }

    private func save(_ version: ResumeVersion) {
        var version = version
        version.interviewID = interviewID
        appState.saveTailoredResume(version)
        dismiss()
    }
}

/// What a tailored version changed from the original, and what the job asks
/// for that it still doesn't show. Shared by the tailoring results and the
/// saved version.
struct ResumeVersionDetails: View {
    let version: ResumeVersion
    /// On the Profile stack, gaps open their practice question.
    var linksQuestions = true
    /// A line per change and gap titles only, with the page shown above.
    var isCompact = false

    @Environment(AppState.self) private var appState

    var body: some View {
        Section {
            ForEach(version.changes) { change in
                if isCompact {
                    compactChange(change)
                } else {
                // What kind of change, by its symbol: moved up, rewritten
                // or cut; then what it was about and the change itself.
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                    Image(systemName: change.kind.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                        .accessibilityLabel(change.kind.rawValue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(change.title)
                            .font(.headline)
                        Text(change.detail)
                            .font(.subheadline)
                            .foregroundStyle(change.kind == .rewritten ? Color.primary : Color.secondary)
                    }
                }
                .padding(.vertical, AppTheme.Spacing.xxs)
                .accessibilityElement(children: .combine)
                }
            }
        } header: {
            Text("What Changed")
            .listHeadingInset()
        }

        Section {
            ForEach(version.gaps) { gap in
                let question = gap.questionID.flatMap { id in appState.library.first { $0.id == id } }
                if linksQuestions, let question {
                    NavigationLink(value: Route.question(question)) {
                        if isCompact { Text(gap.title) } else { gapLabel(gap) }
                    }
                } else if isCompact {
                    Text(gap.title)
                } else {
                    gapLabel(gap)
                }
            }
        } header: {
            Text("Not on Your Resume")
            .listHeadingInset()
        } footer: {
            if !isCompact {
                Text("Rehearse these before the day.")
            }
        }
    }

    /// The kind of change by its symbol, what it was about, and the kind
    /// in a word on the right.
    private func compactChange(_ change: ResumeChange) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: change.kind.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(change.title)
                .lineLimit(1)
            Spacer(minLength: AppTheme.Spacing.xs)
            Text(change.kind.shortLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func gapLabel(_ gap: ResumeGap) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(gap.title)
                .font(.headline)
            Text(gap.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, AppTheme.Spacing.xxs)
        .accessibilityElement(children: .combine)
    }
}

private extension ResumeChange.Kind {
    var shortLabel: String {
        switch self {
        case .movedUp: "Moved up"
        case .rewritten: "Rewritten"
        case .cut: "Left out"
        }
    }
}

#Preview {
    TailorResumeView()
        .environment(AppState())
}

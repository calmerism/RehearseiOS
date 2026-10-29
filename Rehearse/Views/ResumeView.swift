import SwiftUI

/// Adds the resume that personalizes questions, and shows what was understood
/// from it so the candidate can trust (or fix) what they'll be asked about.
/// A resume comes from Files, a scan of a printed copy, or the builder; the
/// reading is shown step by step. From here it can be tailored for a job.
/// Reading and tailoring are mocked.
struct ResumeView: View {
    @Environment(AppState.self) private var appState
    @State private var source: ResumeSource?
    @State private var isConfirmingRemoval = false
    @State private var isTailoring = false

    var body: some View {
        List {
            TabHeaderSection()
            // Gone once all three steps are done.
            if steps.contains(where: { !$0.isDone }) { progressSection }
            switch appState.resume {
            case .none:
                emptyState
            case .parsing(let fileName):
                Section {
                    ProgressSteps(steps: ["Reading the text", "Finding your projects", "Choosing your questions"])
                } header: {
                    Text("Reading \(fileName)")
                        .listHeadingInset()
                }
            case .ready(let context):
                understood(context)
            case .failed(let fileName, let reason):
                Section {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Label("Couldn’t read \(fileName)", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                        Text(reason)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, AppTheme.Spacing.xxs)
                }
                Section {
                    ResumeSourceRows { source = $0 }
                }
            }
        }
        .appListStyle()
        .screenTitle("Resume")
        .resumeSources($source) { upload($0) }
        .confirmationDialog("Remove your resume?", isPresented: $isConfirmingRemoval, titleVisibility: .visible) {
            Button("Remove Resume", role: .destructive) { appState.removeResume() }
        } message: {
            Text(appState.tailoredResumes.isEmpty ? "Without it, you’ll get general questions." : "Your tailored versions will be removed too. Without a resume, you’ll get general questions.")
        }
        .sheet(isPresented: $isTailoring) {
            TailorResumeView()
        }
        #if DEBUG
        .onAppear {
            // `-tailor`, `-builder` and `-scan` open those, for screenshots.
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-tailor") { isTailoring = true }
            if arguments.contains("-builder") { source = .build }
            if arguments.contains("-scan") { source = .scan }
        }
        #endif
    }

    // MARK: - Progress

    /// Where the candidate is with their resume, from what the app knows:
    /// added, tailored for a role, then rehearsed with that version. Each
    /// step says done or not in words and with its mark, and the next one
    /// is named, so nothing relies on color.
    private var steps: [(title: String, isDone: Bool)] {
        let hasResume = appState.resume.context != nil
        let isTailored = !appState.tailoredResumes.isEmpty
        let rehearsedTailored = appState.tailoredResumes.contains { version in
            guard let interview = version.interviewID.flatMap(appState.upcomingInterview(id:)) else { return false }
            return appState.rehearsalCount(for: interview) > 0
        }
        return [
            ("Add your resume", hasResume),
            ("Tailor it for a role", hasResume && isTailored),
            ("Rehearse with the tailored version", hasResume && isTailored && rehearsedTailored),
        ]
    }

    private var progressSection: some View {
        let steps = steps
        let done = steps.filter(\.isDone).count
        let next = steps.first { !$0.isDone }
        return Section {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Next: \(next?.title ?? "")")
                        .font(.headline)
                    Text("\(done) of \(steps.count) steps done")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(spacing: AppTheme.Spacing.sm) {
                            Image(systemName: step.isDone ? "checkmark.circle.fill" : "\(index + 1).circle")
                                .font(.title3)
                                .foregroundStyle(step.isDone ? AppTheme.practiced : Color(.secondaryLabel))
                            // The green tick says it's done; no label too.
                            Text(step.title)
                                .foregroundStyle(step.isDone ? Color.secondary : Color.primary)
                            Spacer(minLength: 0)
                        }
                        .font(.subheadline)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(step.title), \(step.isDone ? "done" : "not done")")
                    }
                }
            }
            .padding(.vertical, AppTheme.Spacing.xxs)
        } header: {
            Text("Your Progress")
                .listHeadingInset()
        }
    }

    /// The built resume in use, when it came from the builder's notes.
    private var isBuiltResume: Bool {
        guard let draft = appState.resumeDraft, let context = appState.resume.context else { return false }
        return context.fileName == draft.written().fileName
    }

    // MARK: - Empty

    /// Nothing yet: what a resume does, then Build Resume first, with
    /// uploading or scanning one as the other ways in.
    @ViewBuilder
    private var emptyState: some View {
        Section {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text("No Resume Yet")
                        .font(.title3.bold())
                    Text("Add one and you’ll be asked about your own projects.")
                        .foregroundStyle(.secondary)
                }
                PrimaryButton(title: "Build Resume", systemImage: "square.and.pencil") { source = .build }
            }
            .padding(.vertical, AppTheme.Spacing.xs)
        }
        Section {
            ResumeSourceRows(sources: [.file, .scan]) { source = $0 }
        } header: {
            Text("Or Add Your Own")
                .listHeadingInset()
        }
    }

    @ViewBuilder
    private func understood(_ context: ResumeContext) -> some View {
        // The file, as a page, and what was found in it.
        Section {
            HStack(spacing: AppTheme.Spacing.md) {
                ResumePage(context: context, width: 54)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.fileName)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(context.highlights.isEmpty
                         ? "\(context.skills.count) skills found"
                         : "\(context.highlights.count) projects and \(context.skills.count) skills")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, AppTheme.Spacing.xs)
            .accessibilityElement(children: .combine)
            Button(isBuiltResume ? "Edit Resume" : "Build Resume", systemImage: "square.and.pencil") { source = .build }
                .fontWeight(.semibold)
        }

        // A read file's skills, while its projects can't be picked out yet.
        if context.highlights.isEmpty, !context.skills.isEmpty {
            Section {
                Text(context.skills.joined(separator: ", "))
            } header: {
                Text("Skills Found")
                    .listHeadingInset()
            } footer: {
                Text("Your interviewer will ask about these.")
            }
        }

        Section {
            ForEach(appState.tailoredResumes) { version in
                NavigationLink(value: Route.resumeVersion(version.id)) {
                    LabeledContent {
                        if let interview = version.interviewID.flatMap(appState.upcomingInterview(id:)) {
                            Text(interview.date?.formatted(.dateTime.day().month(.abbreviated)) ?? "")
                        }
                    } label: {
                        Text(version.target)
                        Text(version.angle)
                    }
                }
            }
            Button("Tailor for a Role", systemImage: "plus") { isTailoring = true }
        } header: {
            Text("Tailored Versions")
                .listHeadingInset()
        }

        Section {
            Menu("Replace Resume") {
                ResumeSourceMenuItems { source = $0 }
            }
            Button("Remove Resume", role: .destructive) { isConfirmingRemoval = true }
        } footer: {
            if !appState.tailoredResumes.isEmpty {
                Text("Replacing it removes your tailored versions.")
            }
        }
    }

    private func upload(_ fileName: String) {
        Task { await appState.uploadResume(named: fileName) }
    }
}

#Preview {
    NavigationStack { ResumeView() }
        .environment(AppState())
}

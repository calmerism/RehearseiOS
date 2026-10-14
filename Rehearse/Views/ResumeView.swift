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
        .scrollingTitle("Resume")
        .navigationBarTitleDisplayMode(.inline)
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

    /// Nothing yet: what a resume does, then the three ways to add one, so
    /// how it gets in is plain before anything is tapped.
    @ViewBuilder
    private var emptyState: some View {
        Section {
            VStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "doc.text")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(.secondary)
                Text("No Resume")
                    .font(.title2.bold())
                Text("Add one and you’ll be asked about your own projects.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.md)
            .listRowBackground(Color.clear)
        }
        Section {
            ResumeSourceRows { source = $0 }
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
                    Text("\(context.highlights.count) projects and \(context.skills.count) skills")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, AppTheme.Spacing.xs)
            .accessibilityElement(children: .combine)
        }

        Section {
            ForEach(context.highlights) { highlight in
                VStack(alignment: .leading, spacing: 2) {
                    Text(highlight.title)
                        .font(.headline)
                    Text(highlight.source)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, AppTheme.Spacing.xxs)
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("You’ll Be Asked About")
                .listHeadingInset()
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

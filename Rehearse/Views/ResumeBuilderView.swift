import SwiftUI

/// Writes a resume for a candidate who doesn't have one, or wants a better
/// one. They give the basics and describe each project the way they'd say
/// it, in any language; a language model turns the notes into resume lines
/// in English, and the page is shown before it's used. Writing is mocked.
struct ResumeBuilderView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var draft = MockData.resumeDraft(role: "Software Engineer")
    @State private var phase = Phase.form
    @State private var path: [Int] = []

    private enum Phase: Equatable {
        case form
        case writing
        case result(ResumeContext)
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch phase {
                case .form: form
                case .writing: writing
                case .result(let context): result(context)
                }
            }
            .appListStyle()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if case .result = phase {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") { withAnimation { phase = .form } }
                    }
                }
            }
            .safeAreaBar(edge: .bottom) {
                switch phase {
                case .form:
                    BottomActions {
                        PrimaryButton(title: "Write My Resume") { write() }
                            .disabled(!canWrite)
                    }
                case .writing:
                    EmptyView()
                case .result(let context):
                    BottomActions {
                        PrimaryButton(title: "Use This Resume") {
                            appState.useBuiltResume(context)
                            dismiss()
                        }
                    }
                }
            }
            .navigationDestination(for: Int.self) { index in
                if draft.projects.indices.contains(index) {
                    ProjectNoteEditor(project: $draft.projects[index])
                }
            }
        }
        .onAppear {
            draft.role = appState.targetRole
            #if DEBUG
            // `-builderResult` shows the written resume, for screenshots.
            if ProcessInfo.processInfo.arguments.contains("-builderResult") { phase = .result(draft.written()) }
            #endif
        }
    }

    private var title: String {
        switch phase {
        case .form: "Build Resume"
        case .writing: "Writing"
        case .result: "Your Resume"
        }
    }

    private var canWrite: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
            && draft.projects.contains { !$0.notes.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    // MARK: - Form

    private var form: some View {
        Form {
            Section {
                LabeledTextField(title: "Name", text: $draft.name, prompt: "Required", contentType: .name)
                LabeledTextField(title: "Email", text: $draft.email, prompt: "Optional", contentType: .emailAddress)
                LabeledTextField(title: "Applying For", text: $draft.role, prompt: "Job Role", contentType: .jobTitle)
            } header: {
                Text("About You")
                    .listHeadingInset()
            }

            Section {
                LabeledTextField(title: "College", text: $draft.college, prompt: "Required")
                LabeledTextField(title: "Degree", text: $draft.degree, prompt: "Required")
                Picker("Graduating", selection: $draft.graduationYear) {
                    ForEach(2024...2030, id: \.self) { Text(String($0)).tag($0) }
                }
            } header: {
                Text("Education")
                    .listHeadingInset()
            }

            Section {
                ForEach(Array(draft.projects.enumerated()), id: \.element.id) { index, project in
                    NavigationLink(value: index) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.title.isEmpty ? "New Project" : project.title)
                            Text(project.notes.isEmpty ? "Add what you did" : project.notes)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onDelete { draft.projects.remove(atOffsets: $0) }
                Button("Add Project", systemImage: "plus") {
                    draft.projects.append(ProjectNote(title: "", place: "", notes: ""))
                    path.append(draft.projects.count - 1)
                }
            } header: {
                Text("Projects and Work")
                    .listHeadingInset()
            } footer: {
                Text("Describe each one the way you’d say it, in any language. The resume is written in English.")
            }

            Section {
                TextField("Go, Swift, Python", text: $draft.skills, axis: .vertical)
                    .lineLimit(1...4)
            } header: {
                Text("Skills")
                    .listHeadingInset()
            }
        }
    }

    // MARK: - Writing

    private var writing: some View {
        Form {
            Section {
                ProgressSteps(steps: ["Reading your notes", "Writing a line for each project", "Fitting it on one page"], pace: 0.8)
            } header: {
                Text("Writing Your Resume")
                    .listHeadingInset()
            }
        }
    }

    private func write() {
        withAnimation { phase = .writing }
        Task {
            try? await Task.sleep(for: .seconds(2.6))
            guard phase == .writing else { return }
            withAnimation(.smooth(duration: 0.4)) { phase = .result(draft.written()) }
        }
    }

    // MARK: - Result

    /// The page itself, then each line it wrote, to check before using it.
    private func result(_ context: ResumeContext) -> some View {
        List {
            Section {
                ResumePage(context: context, width: 216)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.xs)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                ForEach(context.highlights) { highlight in
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        Text(highlight.title)
                            .font(.headline)
                        Text(highlight.detail)
                            .font(.subheadline)
                    }
                    .padding(.vertical, AppTheme.Spacing.xxs)
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("Written From Your Notes")
                    .listHeadingInset()
            } footer: {
                Text("Check each line is true. Edit your notes to change it.")
            }
        }
    }
}

/// One project, described in the candidate's own words.
private struct ProjectNoteEditor: View {
    @Binding var project: ProjectNote

    var body: some View {
        Form {
            Section {
                LabeledTextField(title: "Name", text: $project.title, prompt: "Campus Eats")
                LabeledTextField(title: "Where", text: $project.place, prompt: "Personal project")
            }
            Section {
                TextField("Say it the way you’d tell a friend", text: $project.notes, axis: .vertical)
                    .lineLimit(4...10)
            } header: {
                Text("What You Did")
                    .listHeadingInset()
            } footer: {
                Text("Any language is fine. Numbers help, like how many people used it.")
            }
        }
        .appListStyle()
        .navigationTitle(project.title.isEmpty ? "New Project" : project.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ResumeBuilderView()
        .environment(AppState())
}

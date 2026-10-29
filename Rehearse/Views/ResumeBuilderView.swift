import SwiftUI

/// Writes a resume for a candidate who doesn't have one, or wants a better
/// one. They give the basics and describe each project the way they'd say
/// it, in any language; a language model turns the notes into resume lines
/// in English, and the page is shown before it's used. Writing is mocked.
struct ResumeBuilderView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ResumeDraft.blank
    @State private var phase = Phase.form
    @State private var path: [Int] = []
    /// The bottom button steps aside while typing, so it never sits on
    /// the keyboard over the next field.
    @State private var isKeyboardShown = false
    /// The part of the page being edited in a sheet.
    @State private var editing: PagePart?

    private enum Phase: Equatable {
        case form
        case writing
        /// The resume, always written from the notes as they are now, so
        /// editing a project from here updates it straight away.
        case result
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                switch phase {
                case .form: form
                case .writing: writing
                case .result: result(draft.written())
                }
            }
            .appListStyle()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaBar(edge: .bottom) {
                switch phase {
                case .form:
                    if !isKeyboardShown {
                        BottomActions {
                            if let missingNote {
                                Text(missingNote)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                            }
                            PrimaryButton(title: "Write My Resume") { write() }
                                .disabled(!canWrite)
                        }
                    }
                case .writing:
                    EmptyView()
                case .result:
                    BottomActions {
                        if let missingNote {
                            Text(missingNote)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        PrimaryButton(title: "Use This Resume") {
                            appState.useBuiltResume(draft.written())
                            dismiss()
                        }
                        .disabled(!canWrite)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in isKeyboardShown = true }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in isKeyboardShown = false }
            .navigationDestination(for: Int.self) { index in
                if draft.projects.indices.contains(index) {
                    ProjectNoteEditor(project: $draft.projects[index])
                }
            }
        }
        .sheet(item: $editing) { part in
            PagePartEditor(part: part, draft: $draft)
        }
        // Kept as it's typed, so leaving and coming back loses nothing.
        .onChange(of: draft) { appState.resumeDraft = draft }
        .onAppear {
            if let saved = appState.resumeDraft {
                draft = saved
                // The resume in use came from these notes: open on it.
                if appState.builderOpensOnPage || (canWrite && appState.resume.context?.fileName == draft.written().fileName) { phase = .result }
            }
            // What the account already knows; the rest is the candidate's.
            if draft.name.isEmpty { draft.name = appState.account?.fullName ?? appState.candidateName }
            if draft.email.isEmpty { draft.email = appState.account?.email ?? "" }
            if draft.role.isEmpty { draft.role = appState.targetRole }
            appState.builderOpensOnPage = false
            #if DEBUG
            // `-builderSample` fills in the sample notes and `-builderResult`
            // shows the written resume, for screenshots.
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-builderSample") || arguments.contains("-builderResult") { draft = MockData.resumeDraft(role: appState.targetRole) }
            if arguments.contains("-builderResult") { phase = .result }
            // `-builderProject` opens a new project's form.
            if arguments.contains("-builderProject") {
                draft.projects.append(ProjectNote(title: "", notes: ""))
                path = [draft.projects.count - 1]
            }
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

    /// Everything marked Required, at least one complete project, and no
    /// project half filled in.
    private var canWrite: Bool {
        !draft.name.trimmingCharacters(in: .whitespaces).isEmpty
            && !draft.college.trimmingCharacters(in: .whitespaces).isEmpty
            && !draft.degree.trimmingCharacters(in: .whitespaces).isEmpty
            && draft.projects.contains(where: \.isComplete)
            && draft.projects.allSatisfy { $0.isComplete || $0.isBlank }
    }

    /// Why Write My Resume can't be pressed yet, in one line.
    private var missingNote: String? {
        guard !canWrite else { return nil }
        if draft.name.trimmingCharacters(in: .whitespaces).isEmpty { return "Add your name to write your resume." }
        let noCollege = draft.college.trimmingCharacters(in: .whitespaces).isEmpty
        let noDegree = draft.degree.trimmingCharacters(in: .whitespaces).isEmpty
        if noCollege || noDegree {
            return noCollege && noDegree ? "Add your college and degree." : noCollege ? "Add your college." : "Add your degree."
        }
        if let half = draft.projects.first(where: { !$0.isComplete && !$0.isBlank }) {
            return half.title.isEmpty ? "Finish your project: add its name and description." : "Finish “\(half.title)”: add a description."
        }
        return "Add a project to write your resume."
    }

    // MARK: - Form

    private var form: some View {
        Form {
            // One card, its title inside, as Build One for Me shows the
            // same steps in onboarding.
            Section {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("How It Works")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        ForEach(Array(ResumeBuilderSteps.all.enumerated()), id: \.offset) { index, step in
                            NumberedStep(number: index + 1, text: step)
                        }
                    }
                }
                .padding(.vertical, AppTheme.Spacing.xxs)
            }

            Section {
                LabeledTextField(title: "Name", text: $draft.name, prompt: "Required", contentType: .name)
                LabeledTextField(title: "Email", text: $draft.email, prompt: "Optional", contentType: .emailAddress)
                LabeledTextField(title: "Applying For", text: $draft.role, prompt: "Enter job role", contentType: .jobTitle)
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
                            if project.isComplete {
                                Text(project.kind.rawValue)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                // Half filled in: say what's missing, so
                                // Write My Resume isn't greyed out for no
                                // visible reason.
                                Label(project.title.isEmpty ? "Add a name and description" : "Add a description", systemImage: "exclamationmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(project.isBlank ? Color.secondary : AppTheme.record)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .onDelete { draft.projects.remove(atOffsets: $0) }
                Button("Add Project", systemImage: "plus") {
                    draft.projects.append(ProjectNote(title: "", notes: ""))
                    path.append(draft.projects.count - 1)
                }
            } header: {
                Text("Projects and Work")
                    .listHeadingInset()
            } footer: {
                Text("Describe each one the way you’d say it, in any language. The resume is written in English. Swipe to remove one.")
            }

            Section {
                TextField("Skills", text: $draft.skills, prompt: .prompt("e.g. Swift, Python, SQL"), axis: .vertical)
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
            withAnimation(.smooth(duration: 0.4)) { phase = .result }
        }
    }

    // MARK: - Result

    /// The resume as a page to read and edit in place: every part of it
    /// is tappable, and changes show on the page as soon as they're made.
    private func result(_ context: ResumeContext) -> some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                Label("Tap any part of the page to edit it.", systemImage: "hand.tap")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppTheme.Spacing.xs)
                editablePage(context)
                Text("Written from your notes. Check each line is true before you use it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(AppTheme.Spacing.md)
        }
        .groupedBackground()
    }

    private func editablePage(_ context: ResumeContext) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            PageBlock(label: "Edit your details") { editing = .details } content: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.name ?? "Your Name")
                        .font(.title2.weight(.bold))
                    if !context.skills.isEmpty {
                        Text(context.skills.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if !draft.email.isEmpty {
                        Text(draft.email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Rectangle()
                .fill(AppTheme.brand)
                .frame(height: 2)
                .padding(.horizontal, AppTheme.Spacing.sm)

            PageBlock(label: "Edit education") { editing = .education } content: {
                VStack(alignment: .leading, spacing: 6) {
                    PageHeading("Education")
                    Text(context.education ?? "Add your college and degree")
                        .font(.subheadline)
                }
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                PageHeading("Projects")
                    .padding(.horizontal, AppTheme.Spacing.sm)
                ForEach(Array(draft.projects.enumerated()), id: \.element.id) { index, project in
                    if project.isComplete {
                        PageBlock(label: "Edit \(project.title)") { path.append(index) } content: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.title)
                                    .font(.headline)
                                Text(project.kind.rawValue)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text(project.writtenLine)
                                    .font(.subheadline)
                                    .padding(.top, 2)
                            }
                        }
                        .contextMenu {
                            Button("Edit", systemImage: "pencil") { path.append(index) }
                            Button("Delete Project", systemImage: "trash", role: .destructive) {
                                withAnimation { _ = draft.projects.remove(at: index) }
                            }
                        }
                    }
                }
                Button {
                    draft.projects.append(ProjectNote(title: "", notes: ""))
                    path.append(draft.projects.count - 1)
                } label: {
                    Label("Add Project", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.brand)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppTheme.Spacing.sm)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.black)
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
        // Paper stays white in dark mode, as documents do.
        .environment(\.colorScheme, .light)
        .animation(.smooth(duration: 0.25), value: draft)
    }
}

/// A part of the resume page that can be edited: it tints when pressed and
/// carries a small pencil, so the page reads as a document, not a form.
private struct PageBlock<Content: View>: View {
    let label: String
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: AppTheme.Spacing.xs) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "pencil")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.brand)
                    .padding(.top, 3)
                    .accessibilityHidden(true)
            }
            .multilineTextAlignment(.leading)
            .padding(AppTheme.Spacing.sm)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(PageBlockStyle())
        .accessibilityHint(label)
    }
}

private struct PageBlockStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(AppTheme.graphic.opacity(configuration.isPressed ? 0.12 : 0), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// A section label on the page: small capitals, spaced out.
private struct PageHeading: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(1)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The page's details or education, in a short sheet over the page.
private struct PagePartEditor: View {
    let part: PagePart
    @Binding var draft: ResumeDraft
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                switch part {
                case .details:
                    Section {
                        LabeledTextField(title: "Name", text: $draft.name, prompt: "Required", contentType: .name)
                        LabeledTextField(title: "Email", text: $draft.email, prompt: "Optional", contentType: .emailAddress)
                        LabeledTextField(title: "Applying For", text: $draft.role, prompt: "Enter job role", contentType: .jobTitle)
                    }
                    Section {
                        TextField("Skills", text: $draft.skills, prompt: .prompt("e.g. Swift, Python, SQL"), axis: .vertical)
                            .lineLimit(1...4)
                    } header: {
                        Text("Skills")
                            .listHeadingInset()
                    } footer: {
                        Text("Separate them with commas.")
                    }
                case .education:
                    Section {
                        LabeledTextField(title: "College", text: $draft.college, prompt: "Required")
                        LabeledTextField(title: "Degree", text: $draft.degree, prompt: "Required")
                        Picker("Graduating", selection: $draft.graduationYear) {
                            ForEach(2024...2030, id: \.self) { Text(String($0)).tag($0) }
                        }
                    }
                }
            }
            .appListStyle()
            .navigationTitle(part == .details ? "Your Details" : "Education")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

/// The parts of the page edited in a sheet; projects push their own form.
private enum PagePart: Identifiable {
    case details, education
    var id: Self { self }
}

/// One project, field by field: what it is first, then what the candidate
/// did and what came of it, each in its own words. Everything is bound to
/// the builder's draft, so going back and in again keeps what was typed.
private struct ProjectNoteEditor: View {
    @Binding var project: ProjectNote
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Field?
    /// Required fields show as missing once they've been visited.
    @State private var visited: Set<Field> = []

    private enum Field: Hashable { case name, role, description, features, outcomes }

    var body: some View {
        Form {
            // Plain rows, as Contacts edits a card: the name, then its type.
            Section {
                LabeledContent("Name") {
                    TextField("Name", text: $project.title, prompt: .prompt("Required"))
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.words)
                        .focused($focused, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focused = project.kind != .personal && project.teamSize > 1 ? .role : .description }
                }
                Picker("Type", selection: $project.kind.animation(.smooth(duration: 0.2))) {
                    ForEach(ProjectKind.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
            } footer: {
                if missing(.name) {
                    Text("Add a project name.")
                        .foregroundStyle(AppTheme.record)
                }
            }

            // Who worked on it. A personal project is the candidate's own, so
            // it has no team to ask about. A role only means something in a
            // team, so it's asked once there's more than one person.
            if project.kind != .personal {
                Section {
                    Stepper(value: $project.teamSize.animation(.smooth(duration: 0.2)), in: 1...50) {
                        LabeledContent("Team Size", value: project.teamSize == 1 ? "Just me" : "\(project.teamSize) people")
                    }
                    if project.teamSize > 1 {
                        LabeledContent("Your Role") {
                            TextField("Your Role", text: $project.role, prompt: .prompt("e.g. Built the backend"))
                                .multilineTextAlignment(.trailing)
                                .focused($focused, equals: .role)
                                .submitLabel(.next)
                                .onSubmit { focused = .description }
                        }
                    }
                } header: {
                    Text("Team")
                        .listHeadingInset()
                }

            }

            Section {
                // Three different questions, each with an example, so none
                // reads like another: what it is, what it does, what came of it.
                longField(.description, "What It Is", prompt: "e.g. A food-ordering app for students (required)", text: $project.notes)
                longField(.features, "Features", prompt: "e.g. Ordering, payments, live tracking", text: $project.features)
                longField(.outcomes, "Results", prompt: "e.g. 2,000 students use it", text: $project.outcomes)
            } footer: {
                if missing(.description) {
                    Text("Say what it is. The resume line is written from it.")
                        .foregroundStyle(AppTheme.record)
                }
            }
        }
        .appListStyle()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(project.title.isEmpty ? "New Project" : project.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // One Done, as Notes has: while typing it puts the keyboard
            // away (the long fields take Return as a new line), and after
            // that it goes back to the builder.
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    if focused != nil { focused = nil } else { dismiss() }
                }
                .fontWeight(.semibold)
            }
        }
        .onChange(of: project.kind) { _, kind in
            if kind == .personal {
                project.teamSize = 1
                project.role = ""
            }
        }
        .onChange(of: focused) { old, _ in
            if let old { visited.insert(old) }
        }
        .onAppear {
            if project.isBlank { focused = .name }
        }
    }

    private func missing(_ field: Field) -> Bool {
        guard [.name, .description].contains(field), visited.contains(field), focused != field else { return false }
        let text = field == .name ? project.title : project.notes
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// A form row for a longer answer: its label small above, and a field
    /// beneath that grows as it's typed in, as Contacts edits notes.
    private func longField(_ field: Field, _ title: String, prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(missing(field) ? AppTheme.record : Color.secondary)
            TextField(title, text: text, prompt: .prompt(prompt), axis: .vertical)
                .lineLimit(2...6)
                .focused($focused, equals: field)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    ResumeBuilderView()
        .environment(AppState())
}

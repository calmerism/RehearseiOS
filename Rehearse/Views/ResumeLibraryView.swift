import SwiftUI

/// Every resume the candidate has had, as the Library keeps questions: the
/// ones in use now above the ones from before, each narrowed by kind or a
/// search. Choosing one attaches it to the mock and goes back.
struct ResumeLibraryView: View {
    @Binding var selection: ResumeChoice?

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var kind: Kind?

    enum Kind: String, CaseIterable {
        case uploaded = "Uploaded"
        case tailored = "Tailored"
    }

    /// One resume in the library, however it came to be.
    private struct Entry: Identifiable {
        let id: String
        let choice: ResumeChoice
        let kind: Kind
        let title: String
        let subtitle: String
        let date: Date?
    }

    var body: some View {
        List {
            Section {
                SearchField(prompt: "Search resumes", text: $searchText)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                Picker("Kind", selection: $kind) {
                    Text("All").tag(Kind?.none)
                    ForEach(Kind.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            if current.isEmpty && previous.isEmpty {
                ContentUnavailableView {
                    Label("No Resumes", systemImage: "magnifyingglass")
                } description: {
                    Text("Nothing matches. Try a different filter.")
                } actions: {
                    Button("Show All Resumes") {
                        searchText = ""
                        kind = nil
                    }
                }
                .listRowBackground(Color.clear)
            }

            if !current.isEmpty {
                Section {
                    ForEach(current) { row($0) }
                } header: {
                    Text("Current")
                        .listHeadingInset()
                } footer: {
                    Text("Your Profile resume and the versions tailored for your upcoming interviews.")
                }
            }

            if !previous.isEmpty {
                Section {
                    ForEach(previous) { row($0) }
                } header: {
                    Text("Previous")
                        .listHeadingInset()
                } footer: {
                    Text("Earlier uploads and versions tailored for interviews you’ve done.")
                }
            }
        }
        .appListStyle()
        .navigationTitle("Resume Library")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: - Entries

    private var upcomingCompanies: Set<String> {
        Set(appState.upcomingInterviews.compactMap(\.company))
    }

    private var current: [Entry] {
        var entries: [Entry] = []
        if let original = appState.resume.context {
            entries.append(Entry(id: "original", choice: .original, kind: .uploaded, title: original.fileName, subtitle: "On your Profile", date: nil))
        }
        // A file added just for this mock sits with the current ones.
        if case .uploaded(let context) = selection, !appState.pastResumes.contains(where: { $0.context == context }) {
            entries.append(Entry(id: "this-interview", choice: .uploaded(context), kind: .uploaded, title: context.fileName, subtitle: "For this interview only", date: nil))
        }
        entries += tailored.filter { isCurrent($0) }.map(entry)
        return filtered(entries)
    }

    private var previous: [Entry] {
        let uploads = appState.pastResumes.map { past in
            Entry(id: past.id.uuidString, choice: .uploaded(past.context), kind: .uploaded, title: past.context.fileName, subtitle: "Uploaded \(dateText(past.uploadedOn))", date: past.uploadedOn)
        }
        let versions = tailored.filter { !isCurrent($0) }.map(entry)
        return filtered((uploads + versions).sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) })
    }

    private var tailored: [ResumeVersion] { appState.tailoredResumes }

    private func isCurrent(_ version: ResumeVersion) -> Bool {
        version.interviewID != nil || version.company.map(upcomingCompanies.contains) ?? true
    }

    private func entry(_ version: ResumeVersion) -> Entry {
        Entry(
            id: version.id.uuidString,
            choice: .tailored(version.id),
            kind: .tailored,
            title: "Tailored for \(version.target)",
            subtitle: "\(version.angle), made \(dateText(version.createdOn))",
            date: version.createdOn
        )
    }

    private func filtered(_ entries: [Entry]) -> [Entry] {
        entries.filter { entry in
            (kind == nil || entry.kind == kind)
                && (searchText.isEmpty
                    || entry.title.localizedCaseInsensitiveContains(searchText)
                    || entry.subtitle.localizedCaseInsensitiveContains(searchText))
        }
    }

    private func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    // MARK: - Row

    private func row(_ entry: Entry) -> some View {
        let isSelected = entry.choice == selection
        return Button {
            withAnimation { selection = entry.choice }
            dismiss()
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: entry.kind == .tailored ? "wand.and.sparkles" : "doc.text")
                    .font(.title3)
                    .foregroundStyle(Color.secondary)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Text(entry.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                }
                Spacer(minLength: AppTheme.Spacing.xs)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.brand)
                }
            }
            .padding(.vertical, AppTheme.Spacing.xxs)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NavigationStack { ResumeLibraryView(selection: .constant(.original)) }
        .environment(AppState())
}

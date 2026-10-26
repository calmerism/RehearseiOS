import SwiftUI

/// Every practice question, under the candidate's collections: Saved
/// and their own playlists, as Music's library puts playlists above
/// songs. Narrowed to one skill when the candidate arrives from feedback
/// looking for questions that build it; the collections step aside then.
struct QuestionLibraryView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var category: QuestionCategory?
    @State private var focus: Skill?
    @State private var difficulty: Difficulty?
    /// One subject, such as System Design, or every subject.
    @State private var area: String?
    @State private var naming: PlaylistNameRequest?
    /// How many matching questions the list shows. Thousands of rows at once
    /// make scrolling and filtering heavy, so it grows a page at a time.
    @State private var shownCount = Self.pageSize

    private static let pageSize = 50

    init(initialFocus: Skill?) {
        _focus = State(initialValue: initialFocus)
    }

    var body: some View {
        let visibleQuestions = appState.questions(category: category, difficulty: difficulty, skill: focus, area: area, matching: searchText)
        List {
            TabHeaderSection()

            Section {
                SearchField(prompt: "Search questions", text: $searchText)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            if searchText.isEmpty && focus == nil {
                collections
            }

            Section {
                Picker("Category", selection: $category) {
                    Text("All").tag(QuestionCategory?.none)
                    // Only groups the bank has questions in; the real bank
                    // has no Common ones.
                    ForEach(appState.libraryCategories, id: \.self) { category in
                        Text(category.rawValue).tag(Optional(category))
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } header: {
                if focus == nil {
                    Text("All Questions")
                        .listHeadingInset()
                }
            }

            if visibleQuestions.isEmpty {
                ContentUnavailableView {
                    Label("No Questions", systemImage: "magnifyingglass")
                } description: {
                    Text("Nothing matches. Try a different filter.")
                } actions: {
                    Button("Show All Questions") {
                        searchText = ""
                        category = nil
                        difficulty = nil
                        area = nil
                        focus = nil
                    }
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(visibleQuestions.prefix(shownCount)) { question in
                        NavigationLink(value: Route.question(question)) {
                            QuestionRow(question: question, isPracticed: !appState.practiceHistory(for: question).isEmpty, font: .headline, endsWithPeriod: true, practicedOnTrailing: true)
                        }
                        .questionActions(question, naming: $naming)
                    }
                    if visibleQuestions.count > shownCount {
                        Button("Show More") {
                            shownCount += Self.pageSize * 2
                        }
                        .frame(maxWidth: .infinity)
                    }
                } header: {
                    if let focus {
                        HStack {
                            Text("Builds \(focus.title)")
                            Spacer()
                            // Worded and drawn like every other "See All ›".
                            Button { self.focus = nil } label: {
                                HStack(spacing: 3) {
                                    Text("See All")
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                }
                                .tapTarget()
                            }
                            .textCase(nil)
                        }
                        .listHeadingInset()
                    }
                }
            }
        }
        .appListStyle()
        .screenTitle("Library") {
            Menu {
                Picker("Difficulty", selection: $difficulty) {
                    Text("Any Difficulty").tag(Difficulty?.none)
                    ForEach(Difficulty.allCases, id: \.self) { Text($0.rawValue).tag(Optional($0)) }
                }
                if !appState.libraryAreas.isEmpty {
                    // A submenu, as Mail's filters nest a long list.
                    Picker(selection: $area) {
                        Text("All Subjects").tag(String?.none)
                        ForEach(appState.libraryAreas, id: \.self) { area in
                            Text(Question.title(forArea: area)).tag(Optional(area))
                        }
                    } label: {
                        Label(area.map(Question.title(forArea:)) ?? "Subject", systemImage: "square.grid.2x2")
                    }
                    .pickerStyle(.menu)
                }
            } label: {
                Image(systemName: difficulty == nil && area == nil
                    ? "line.3.horizontal.decrease"
                    : "line.3.horizontal.decrease.circle.fill")
            }
            .accessibilityLabel("Filter questions")
        }
        .scrollDismissesKeyboard(.immediately)
        // A new filter starts from the top again.
        .onChange(of: searchText) { shownCount = Self.pageSize }
        .onChange(of: category) { shownCount = Self.pageSize }
        .onChange(of: difficulty) { shownCount = Self.pageSize }
        .onChange(of: area) { shownCount = Self.pageSize }
        .onChange(of: focus) { shownCount = Self.pageSize }
        .playlistNaming($naming)
    }

    /// Saved, then the candidate's playlists and a way to
    /// start one, as Music lists playlists.
    private var collections: some View {
        Section {
            NavigationLink(value: Route.collection(.saved)) {
                CollectionRow(collection: .saved)
            }
            ForEach(appState.playlists) { playlist in
                NavigationLink(value: Route.collection(.playlist(playlist.id))) {
                    CollectionRow(collection: .playlist(playlist.id))
                }
                .swipeActions {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        withAnimation { appState.deletePlaylist(id: playlist.id) }
                    }
                }
                .contextMenu {
                    Button("Rename", systemImage: "pencil") {
                        naming = PlaylistNameRequest(playlistID: playlist.id, name: playlist.name)
                    }
                    Button("Delete Playlist", systemImage: "trash", role: .destructive) {
                        withAnimation { appState.deletePlaylist(id: playlist.id) }
                    }
                }
            }
            Button {
                naming = PlaylistNameRequest()
            } label: {
                HStack(spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(AppTheme.brand)
                        .frame(width: 48, height: 48)
                        .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: 48 * 0.2, style: .continuous))
                    Text("New Playlist")
                        .foregroundStyle(AppTheme.brand)
                }
            }
        } header: {
            Text("Collections")
                .listHeadingInset()
        }
    }
}

/// One question before practicing it: why it gets asked, a structure for
/// the answer, what it builds, and similar questions.
struct QuestionDetailView: View {
    let question: Question
    @Environment(AppState.self) private var appState
    @State private var naming: PlaylistNameRequest?

    var body: some View {
        List {
            TabHeaderSection()
            // One block, as a card: what kind of question it is, the
            // question, what it builds, then the one action. No separators
            // between them, so it reads as a single thing.
            Section {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text(question.metaText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        // Title 3 semibold, exactly the style of this screen's
                        // section headings, so they read as one family.
                        Text(question.text)
                            .font(.title3.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        // The current focus when it's one of the skills it
                        // builds, otherwise every skill it exercises.
                        if let line = buildsLine {
                            Text(line)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)

                    PrimaryButton(title: "Practice This Question") {
                        appState.activePractice = question
                    }
                }
                .padding(.vertical, AppTheme.Spacing.xs)
            }

            Section {
                Text(question.category.whyAsked)
            } header: {
                Text("Why Interviewers Ask This")
                .listHeadingInset()
            }

            Section {
                ForEach(Array(question.category.answerStructure.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.sm) {
                        Text("\(index + 1)")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(AppTheme.brand)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.headline)
                            Text(step.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text(question.category == .behavioral ? "Suggested Structure (STAR)" : "Suggested Structure")
                .listHeadingInset()
            }

            let history = appState.practiceHistory(for: question)
            if let latest = history.first {
                Section {
                    PracticedLabel(text: "Practiced \(latest.date.formatted(.relative(presentation: .named)))")
                }
            }

            let similar = appState.library.filter { $0.category == question.category && $0.id != question.id }.prefix(3)
            if !similar.isEmpty {
                Section {
                    ForEach(Array(similar)) { other in
                        NavigationLink(value: Route.question(other)) {
                            // Semibold, the weight of this screen's headings.
                            QuestionRow(question: other, isPracticed: !appState.practiceHistory(for: other).isEmpty, font: .headline, endsWithPeriod: true, practicedOnTrailing: true)
                        }
                    }
                } header: {
                    Text("More Like This")
                    .listHeadingInset()
                }
            }
        }
        .appListStyle()
        .scrollingTitle("Question")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                let isSaved = appState.isSaved(question)
                Button(isSaved ? "Unsave" : "Save", systemImage: isSaved ? "bookmark.fill" : "bookmark") {
                    appState.toggleSaved(question)
                }
                .sensoryFeedback(.selection, trigger: isSaved)
                Menu {
                    AddToPlaylistMenu(question: question, naming: $naming)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("More")
            }
        }
        .playlistNaming($naming)
    }
}

extension QuestionDetailView {
    /// "Good for working on your answer structure." when it builds the
    /// current focus, else "Builds answer structure and concrete results."
    var buildsLine: String? {
        if let focus = appState.currentFocus, question.skills.contains(focus) {
            return "Good for working on your \(focus.title.lowercased())."
        }
        let names = question.skills.map { $0.title.lowercased() }
        guard !names.isEmpty else { return nil }
        // Joined by hand: the system list style adds an Oxford comma.
        let list = names.count > 1 ? names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1] : names[0]
        return "Builds \(list)."
    }
}

struct AnswerStep {
    let title: String
    let detail: String
}

extension QuestionCategory {
    /// What the interviewer is listening for with this kind of question.
    var whyAsked: String {
        switch self {
        case .common: "They want to hear how you introduce yourself and your work: what you pick, how clearly you explain it and whether you get to the point."
        case .behavioral: "They want a real example with your own actions and a clear result."
        case .roleBased: "They're checking that you understand the work and can explain your technical decisions and their trade-offs out loud."
        }
    }

    var answerStructure: [AnswerStep] {
        switch self {
        case .behavioral:
            [
                AnswerStep(title: "Situation", detail: "Set the scene in a sentence or two."),
                AnswerStep(title: "Task", detail: "What you were responsible for."),
                AnswerStep(title: "Action", detail: "What you did, in your words, not the team’s."),
                AnswerStep(title: "Result", detail: "What changed, with a number if you have one."),
            ]
        case .common, .roleBased:
            [
                AnswerStep(title: "Answer", detail: "Open with a one-sentence answer."),
                AnswerStep(title: "Approach", detail: "How you went about it, and why."),
                AnswerStep(title: "Details", detail: "The specifics that back it up."),
            ]
        }
    }
}

#Preview("Library") {
    NavigationStack { QuestionLibraryView(initialFocus: nil) }
        .environment(AppState())
}

#Preview("Focused") {
    NavigationStack { QuestionLibraryView(initialFocus: .tradeoffs) }
        .environment(AppState())
}

#Preview("Detail") {
    NavigationStack { QuestionDetailView(question: MockData.questions[1]) }
        .environment(AppState())
}

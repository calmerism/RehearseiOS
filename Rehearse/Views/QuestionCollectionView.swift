import SwiftUI

/// One collection of questions, laid out like a playlist in Music: its
/// artwork and name, buttons to start practicing, then the questions.
struct QuestionCollectionView: View {
    let collection: QuestionCollection
    @Environment(AppState.self) private var appState
    @State private var naming: PlaylistNameRequest?
    @State private var isConfirmingDelete = false
    @State private var searchText = ""

    private var questions: [Question] { appState.questions(in: collection) }

    /// The collection's questions that match the search, or all of them.
    private var matchingQuestions: [Question] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return questions }
        return questions.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        let shown = matchingQuestions
        List {
            Section {
                header
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            if questions.isEmpty {
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: collection.symbol)
                } description: {
                    Text(emptyMessage)
                }
                .listRowBackground(Color.clear)
            } else {
                // Searches this collection only, under its buttons.
                Section {
                    SearchField(prompt: "Search \(title)", text: $searchText)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                } footer: {
                    if !searchText.isEmpty, !shown.isEmpty {
                        Text(shown.count == 1 ? "1 question" : "\(shown.count) questions")
                            .padding(.horizontal, AppTheme.Spacing.headingMargin - AppTheme.Spacing.md * 2)
                    }
                }
            }

            if !questions.isEmpty, shown.isEmpty {
                // The system's own no-results view, naming what was searched.
                ContentUnavailableView.search(text: searchText)
                    .listRowBackground(Color.clear)
            } else if !questions.isEmpty {
                Section {
                    ForEach(shown) { question in
                        NavigationLink(value: Route.question(question)) {
                            QuestionRow(question: question, isPracticed: !appState.practiceHistory(for: question).isEmpty, font: .headline, endsWithPeriod: true, practicedOnTrailing: true)
                        }
                        .questionActions(question, in: collection, naming: $naming)
                    }
                }
            }
        }
        .appListStyle()
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle(title)
        .toolbar {
            // The header under the artwork already names the playlist, so
            // the bar shows no title of its own, as in Apple Music.
            ToolbarItem(placement: .principal) { Text("").accessibilityHidden(true) }
            if case .playlist(let id) = collection {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Rename", systemImage: "pencil") {
                            naming = PlaylistNameRequest(playlistID: id, name: title)
                        }
                        Button("Delete Collection", systemImage: "trash", role: .destructive) {
                            isConfirmingDelete = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("Collection options")
                }
            }
        }
        .playlistNaming($naming)
        .confirmationDialog("Delete \(title)?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Collection", role: .destructive) {
                if case .playlist(let id) = collection { appState.deletePlaylist(id: id) }
            }
        } message: {
            Text("The questions stay in the library.")
        }
    }

    private var header: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            CollectionArtwork(collection: collection, size: 88)
            VStack(spacing: AppTheme.Spacing.xxs) {
                Text(title)
                    .font(.cardTitle)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)

            // Play and Shuffle, as at the top of an album in Music: the same
            // size and shape, each with its symbol. Practice is filled, the
            // screen's one solid button; Shuffle is a soft tint of it.
            HStack(spacing: AppTheme.Spacing.sm) {
                Button {
                    appState.activePractice = questions.first
                } label: {
                    Label("Practice", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                Button {
                    appState.activePractice = questions.randomElement()
                } label: {
                    Label("Shuffle", systemImage: "shuffle")
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 50)
                        .foregroundStyle(AppTheme.brand)
                        .background(AppTheme.brand.opacity(0.12), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(CardButtonStyle())
            }
            .font(.body.weight(.semibold))
            .disabled(questions.isEmpty)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, AppTheme.Spacing.xs)
    }

    private var title: String {
        switch collection {
        case .playlist(let id): appState.playlist(id: id)?.name ?? "Collection"
        default: collection.fixedTitle
        }
    }

    private var subtitle: String {
        let count = questions.count == 1 ? "1 question" : "\(questions.count) questions"
        switch collection {
        case .saved: return "Your saved questions and the ones most interviews include. \(count)."
        default: return count.prefix(1).uppercased() + count.dropFirst()
        }
    }

    private var emptyTitle: String {
        if case .saved = collection { return "No Saved Questions" }
        return "No Questions Yet"
    }

    private var emptyMessage: String {
        if case .saved = collection { return "Swipe right on any question to save it here." }
        return "Touch and hold a question in the library, then choose Add to Collection."
    }
}

/// A collection in the library: its artwork, name and how many questions.
struct CollectionRow: View {
    let collection: QuestionCollection
    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            CollectionArtwork(collection: collection, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.rowTitle)
                    .foregroundStyle(Color.primary)
                let count = appState.questions(in: collection).count
                Text(count == 1 ? "1 question" : "\(count) questions")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        if case .playlist(let id) = collection { return appState.playlist(id: id)?.name ?? "Collection" }
        return collection.fixedTitle
    }
}

/// Square artwork for a collection, as Music draws playlists: Saved in
/// color, the candidate's own playlists in quiet gray.
struct CollectionArtwork: View {
    let collection: QuestionCollection
    var size: CGFloat = 48

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
            .fill(fill)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: collection.symbol)
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(isPlaylist ? AnyShapeStyle(.secondary) : AnyShapeStyle(.white))
            }
            .accessibilityHidden(true)
    }

    private var isPlaylist: Bool {
        if case .playlist = collection { return true }
        return false
    }

    private var fill: AnyShapeStyle {
        switch collection {
        case .saved: AnyShapeStyle(AppTheme.graphic)
        case .playlist: AnyShapeStyle(AppTheme.fill)
        }
    }
}

extension QuestionCollection {
    var symbol: String {
        switch self {
        case .saved: "bookmark.fill"
        case .playlist: "list.bullet"
        }
    }

    /// The name of a built-in collection; playlists are named by the candidate.
    var fixedTitle: String {
        switch self {
        case .saved: "Saved"
        case .playlist: "Collection"
        }
    }
}

// MARK: - Question actions

/// Asks for a playlist's name: a new one, optionally starting with a
/// question, or a new name for an existing one.
struct PlaylistNameRequest: Identifiable {
    let id = UUID()
    /// Set when renaming.
    var playlistID: QuestionPlaylist.ID?
    var question: Question?
    var name = ""
}

private struct PlaylistNaming: ViewModifier {
    @Binding var request: PlaylistNameRequest?
    @Environment(AppState.self) private var appState
    @State private var name = ""

    func body(content: Content) -> some View {
        content
            .alert(
                request?.playlistID == nil ? "New Collection" : "Rename Collection",
                isPresented: Binding { request != nil } set: { if !$0 { request = nil } },
                presenting: request
            ) { request in
                TextField("Name", text: $name)
                Button("Cancel", role: .cancel) {}
                Button(request.playlistID == nil ? "Create" : "Save") { save(request) }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: { request in
                if let question = request.question {
                    Text("Starting with “\(question.text)”")
                }
            }
            .onChange(of: request?.id) { name = request?.name ?? "" }
    }

    private func save(_ request: PlaylistNameRequest) {
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if let id = request.playlistID {
            appState.renamePlaylist(id: id, to: name)
        } else {
            appState.createPlaylist(named: name, with: request.question)
        }
    }
}

extension View {
    func playlistNaming(_ request: Binding<PlaylistNameRequest?>) -> some View {
        modifier(PlaylistNaming(request: request))
    }

    /// Save with a swipe right, remove from the collection with a swipe left,
    /// and touch and hold for the rest, as songs work in Music.
    func questionActions(_ question: Question, in collection: QuestionCollection? = nil, naming: Binding<PlaylistNameRequest?>) -> some View {
        modifier(QuestionActions(question: question, collection: collection, naming: naming))
    }
}

private struct QuestionActions: ViewModifier {
    let question: Question
    let collection: QuestionCollection?
    @Binding var naming: PlaylistNameRequest?
    @Environment(AppState.self) private var appState

    func body(content: Content) -> some View {
        let isSaved = appState.isSaved(question)
        content
            .swipeActions(edge: .leading) {
                Button(isSaved ? "Unsave" : "Save", systemImage: isSaved ? "bookmark.slash" : "bookmark") {
                    appState.toggleSaved(question)
                }
                .tint(AppTheme.brand)
            }
            .swipeActions(edge: .trailing) {
                if let collection {
                    Button("Remove", systemImage: "minus.circle", role: .destructive) {
                        withAnimation { appState.remove(question, from: collection) }
                    }
                }
            }
            .contextMenu {
                Button {
                    appState.activePractice = question
                } label: {
                    Label("Practice", systemImage: "mic.fill")
                }
                Button(isSaved ? "Unsave" : "Save", systemImage: isSaved ? "bookmark.slash" : "bookmark") {
                    appState.toggleSaved(question)
                }
                AddToPlaylistMenu(question: question, naming: $naming)
            }
    }
}

/// The candidate's playlists, then a way to start a new one with this question.
struct AddToPlaylistMenu: View {
    let question: Question
    @Binding var naming: PlaylistNameRequest?
    @Environment(AppState.self) private var appState

    var body: some View {
        Menu {
            Button("New Collection", systemImage: "plus") {
                naming = PlaylistNameRequest(question: question)
            }
            if !appState.playlists.isEmpty {
                Divider()
                ForEach(appState.playlists) { playlist in
                    let isIn = playlist.questionIDs.contains(question.id)
                    Button(playlist.name, systemImage: isIn ? "checkmark" : "list.bullet") {
                        appState.add(question, toPlaylist: playlist.id)
                    }
                    .disabled(isIn)
                }
            }
        } label: {
            Label("Add to Collection", systemImage: "text.badge.plus")
        }
    }
}

#Preview("Collection") {
    let state = AppState()
    NavigationStack { QuestionCollectionView(collection: .playlist(state.playlists[0].id)) }
        .environment(state)
}

#Preview("Saved") {
    NavigationStack { QuestionCollectionView(collection: .saved) }
        .environment(AppState())
}

import SwiftUI

/// Every practice question. Opened plainly from Home, or narrowed to one skill
/// when the candidate arrives from feedback looking for questions that build it.
struct QuestionLibraryView: View {
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var category: QuestionCategory?
    @State private var focus: Skill?

    init(initialFocus: Skill?) {
        _focus = State(initialValue: initialFocus)
    }

    private var visibleQuestions: [Question] {
        appState.library.filter { question in
            (category == nil || question.category == category)
                && (focus.map { question.skills.contains($0) } ?? true)
                && (searchText.isEmpty || question.text.localizedCaseInsensitiveContains(searchText))
        }
    }

    var body: some View {
        List {
            Section {
                PillPicker(
                    options: [nil] + QuestionCategory.allCases.map(Optional.some),
                    selection: $category
                ) { $0?.rawValue ?? "All" }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
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
                        focus = nil
                    }
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(visibleQuestions) { question in
                        NavigationLink(value: Route.question(question)) {
                            QuestionRow(question: question, isPracticed: !appState.practiceHistory(for: question).isEmpty)
                        }
                    }
                } header: {
                    Group {
                        if let focus {
                            HStack {
                                Text("Builds \(focus.title)")
                                Spacer()
                                Button("Show all") { self.focus = nil }
                                    .font(.app(.footnote, weight: .semibold))
                                    .textCase(nil)
                            }
                        }
                    }
                    .font(.app(.footnote, weight: .semibold))
                }
            }
        }
        .warmBackground()
        .navigationTitle("Question Library")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search questions")
    }
}

/// One question before practicing it: what it builds, whether it helps the
/// current focus, and whether it's been practiced before.
struct QuestionDetailView: View {
    let question: Question
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text(question.text)
                        .font(AppTheme.question(.title2))
                        .lineSpacing(2)
                    Text(question.metaText)
                        .font(.app(.subheadline))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, AppTheme.Spacing.xxs)
                .accessibilityElement(children: .combine)

                if let focus = appState.currentFocus, question.skills.contains(focus) {
                    Label("Good for working on your \(focus.title.lowercased()).", systemImage: "bolt")
                        .font(.app(.subheadline))
                        .foregroundStyle(AppTheme.focus)
                }
            }

            if !question.skills.isEmpty {
                Section {
                    ForEach(question.skills) { skill in
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                            Text(skill.title)
                            Text(skill.advice)
                                .font(.app(.footnote))
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    Group {
                        Text("What it builds")
                            .font(.app(.footnote, weight: .semibold))
                    }
                    .font(.app(.footnote, weight: .semibold))
                }
            }

            let history = appState.practiceHistory(for: question)
            if let latest = history.first {
                Section {
                    Label("Practiced \(history.count == 1 ? "once" : "\(history.count) times"), last \(latest.date.formatted(.relative(presentation: .named)))", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentMargins(.top, AppTheme.Spacing.sm, for: .scrollContent)
        .warmBackground()
        .navigationTitle("Question")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaBar(edge: .bottom) {
            BottomActions {
                PrimaryButton(title: "Practice Answering", systemImage: "mic") {
                    appState.activePractice = question
                }
            }
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

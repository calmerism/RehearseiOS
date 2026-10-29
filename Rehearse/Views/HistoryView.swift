import SwiftUI

/// Everything the candidate has rehearsed, newest first, with a summary on
/// top. Interviews open their feedback; practice answers can be tried again.
struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @State private var filter: Filter = .all

    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case interviews = "Mock Interviews"
        case practice = "Practice"

        var id: Self { self }
    }

    private var visible: [Rehearsal] {
        switch filter {
        case .all: appState.rehearsals
        case .interviews: appState.interviews
        case .practice: appState.practiceSessions
        }
    }

    var body: some View {
        List {
            TabHeaderSection()
            if !appState.rehearsals.isEmpty {
                Section {
                    summary
                }
                Section {
                    Picker("Show", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                Section {
                    ForEach(visible) { rehearsal in
                        row(rehearsal)
                    }
                }
            }
        }
        .overlay {
            if appState.rehearsals.isEmpty {
                ContentUnavailableView(
                    "No Rehearsals Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Your mock interviews and practice will show up here.")
                )
            }
        }
        .appListStyle()
        .screenTitle("History")
    }

    // MARK: - Summary

    private var summary: some View {
        StatGroup(items: [
            .init(label: "Sessions", value: "\(appState.rehearsals.count)"),
            .init(label: "Average Score", value: appState.averageScore.map { "\($0)" } ?? "None"),
            .init(label: "Best Score", value: appState.interviews.compactMap(\.score).max().map(String.init) ?? "None"),
        ])
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    // MARK: - Rows

    @ViewBuilder
    private func row(_ rehearsal: Rehearsal) -> some View {
        if rehearsal.kind == .interview {
            NavigationLink(value: Route.rehearsal(rehearsal.id)) {
                RehearsalRow(rehearsal: rehearsal)
            }
        } else {
            Button {
                if let question = rehearsal.practiceQuestion { appState.activePractice = question }
            } label: {
                RehearsalRow(rehearsal: rehearsal)
                    .foregroundStyle(Color.primary)
            }
            .accessibilityHint("Practice this question again")
        }
    }
}

#Preview {
    NavigationStack { HistoryView() }
        .environment(AppState())
}

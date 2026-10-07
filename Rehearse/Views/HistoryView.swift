import SwiftUI

/// Everything the candidate has rehearsed, newest first. Interviews open their
/// feedback; practice entries are a record of effort and have no report.
struct HistoryView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            ForEach(appState.rehearsals) { rehearsal in
                if rehearsal.kind == .interview {
                    NavigationLink(value: Route.rehearsal(rehearsal.id)) {
                        RehearsalRow(rehearsal: rehearsal)
                    }
                } else {
                    RehearsalRow(rehearsal: rehearsal)
                }
            }
        }
        .overlay {
            if appState.rehearsals.isEmpty {
                ContentUnavailableView(
                    "No Rehearsals Yet",
                    systemImage: "clock",
                    description: Text("Your interviews and practice will show up here.")
                )
            }
        }
        .contentMargins(.top, AppTheme.Spacing.sm, for: .scrollContent)
        .warmBackground()
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { HistoryView() }
        .environment(AppState())
}

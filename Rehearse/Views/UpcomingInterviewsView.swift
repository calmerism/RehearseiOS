import SwiftUI

/// The candidate's real interviews, from Home's Upcoming Interviews
/// heading: the upcoming ones soonest first, which open to reschedule or
/// remove, then the completed ones most recent first, which open the last
/// mock interview done for them.
struct UpcomingInterviewsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            TabHeaderSection()
            if !upcoming.isEmpty {
                Section("Upcoming") {
                    ForEach(upcoming) { interview in
                        Button {
                            appState.interviewEditor = InterviewEditorRequest(interview: interview)
                        } label: {
                            row(interview)
                        }
                        .swipeActions {
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                withAnimation { appState.removeUpcomingInterview(id: interview.id) }
                            }
                        }
                    }
                }
            }
            if !appState.pastInterviews.isEmpty {
                Section("Previously Scheduled") {
                    ForEach(appState.pastInterviews) { interview in
                        completedRow(interview)
                    }
                }
            }
        }
        .overlay {
            if upcoming.isEmpty && appState.pastInterviews.isEmpty {
                ContentUnavailableView(
                    "No Interviews Yet",
                    systemImage: "calendar",
                    description: Text("Add a real interview to practice for its role, company and date.")
                )
            }
        }
        .appListStyle()
        .scrollingTitle("Interviews")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Interview", systemImage: "plus") {
                    appState.interviewEditor = InterviewEditorRequest()
                }
            }
        }
    }

    private var upcoming: [Interview] {
        appState.upcomingInterviews.filter { ($0.date ?? .distantFuture) >= .now }
    }

    /// A finished interview: how it went in practice, and the last mock
    /// interview done for it, if there was one.
    @ViewBuilder
    private func completedRow(_ interview: Interview) -> some View {
        if let rehearsal = appState.lastRehearsal(for: interview) {
            NavigationLink(value: Route.rehearsal(rehearsal.id)) {
                completedLabel(interview, score: rehearsal.score)
            }
        } else {
            completedLabel(interview, score: nil)
        }
    }

    private func completedLabel(_ interview: Interview, score: Int?) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            DateTile(date: interview.date)
                .opacity(0.7)
            VStack(alignment: .leading, spacing: 2) {
                Text(interview.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(interview.date.map { "Done \($0.formatted(.relative(presentation: .named)))" } ?? "Done")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(score == nil ? "Not practiced" : "Last mock interview scored \(score ?? 0)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: AppTheme.Spacing.xs)
        }
        .padding(.vertical, AppTheme.Spacing.xxs)
        .accessibilityElement(children: .combine)
    }

    /// The day as a tile, the company and role, then when and what kind.
    private func row(_ interview: Interview) -> some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            DateTile(date: interview.date)
            VStack(alignment: .leading, spacing: 2) {
                Text(interview.title)
                    .font(.headline)
                    .lineLimit(1)
                if let date = interview.date {
                    Text("\(interview.countdownText ?? date.formatted(date: .abbreviated, time: .omitted)) at \(date.formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(interview.type.interviewName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: AppTheme.Spacing.xs)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .foregroundStyle(Color.primary)
        .padding(.vertical, AppTheme.Spacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Reschedule or remove")
    }
}

#Preview {
    NavigationStack { UpcomingInterviewsView() }
        .environment(AppState())
}

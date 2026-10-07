import SwiftUI

struct ProgressDashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedFeedback: Feedback?

    private var trendRehearsals: [Rehearsal] {
        Array(appState.rehearsals.prefix(4).reversed())
    }

    var body: some View {
        NavigationStack {
            AppScreen {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 30) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Your Progress")
                                .font(.largeTitle.weight(.bold))
                            Text("Small, repeatable improvements before the real interview.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        ReadinessTrendCard(rehearsals: trendRehearsals)

                        VStack(alignment: .leading, spacing: 14) {
                            SectionHeader(title: "Focus Areas")
                            GroupedSurface(style: .standard) {
                                ImprovementProgressRow(title: "Answer Structure", from: 58, to: 72)
                                Divider().overlay(AppTheme.border).padding(.leading, 18)
                                ImprovementProgressRow(title: "Communication Pace", from: 62, to: 70)
                            }
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .firstTextBaseline) {
                                SectionHeader(title: "Interview History")
                                Spacer()
                                Text("\(appState.rehearsals.count) total")
                                    .font(.caption.weight(.medium).monospacedDigit())
                                    .foregroundStyle(AppTheme.secondaryText)
                            }

                            GroupedSurface(style: .standard) {
                                ForEach(Array(appState.rehearsals.enumerated()), id: \.element.id) { index, rehearsal in
                                    Button {
                                        AppTheme.Haptics.selection()
                                        selectedFeedback = rehearsal.feedback ?? appState.lastFeedback
                                    } label: {
                                        RehearsalHistoryRow(rehearsal: rehearsal)
                                    }
                                    .buttonStyle(.plain)
                                    if index < appState.rehearsals.count - 1 {
                                        Divider().overlay(AppTheme.border).padding(.leading, 18)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 110)
                }
                .scrollIndicators(.hidden)
            }
            .navigationDestination(item: $selectedFeedback) { feedback in
                FeedbackView(feedback: feedback)
            }
        }
    }
}

private struct ReadinessTrendCard: View {
    let rehearsals: [Rehearsal]

    private var currentScore: Int? {
        rehearsals.last?.readiness
    }

    private var scoreChange: Int? {
        guard let first = rehearsals.first?.readiness,
              let last = rehearsals.last?.readiness,
              rehearsals.count > 1 else {
            return nil
        }
        return last - first
    }

    var body: some View {
        GroupedSurface(style: .elevated) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Readiness Trend")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                        Text(rehearsals.isEmpty ? "No rehearsals completed yet" : "Progression across your recent sessions")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer()

                    if let scoreChange {
                        MetricPill(
                            icon: scoreChange >= 0 ? "arrow.up.right" : "arrow.down.right",
                            text: scoreChange > 0 ? "+\(scoreChange) pts" : "\(scoreChange) pts",
                            tint: scoreChange >= 0 ? AppTheme.success : AppTheme.brand
                        )
                    }
                }

                if rehearsals.isEmpty {
                    Text("Complete a rehearsal to start tracking your readiness.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.vertical, 8)
                } else {
                    // Visual milestone stepping track
                    HStack(spacing: 0) {
                        ForEach(Array(rehearsals.enumerated()), id: \.element.id) { index, rehearsal in
                            let isLatest = index == rehearsals.count - 1
                            VStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(isLatest ? AppTheme.brand : AppTheme.mutedFill)
                                        .frame(width: 38, height: 38)
                                        .overlay {
                                            Circle()
                                                .stroke(isLatest ? AppTheme.brand : AppTheme.border, lineWidth: 1.5)
                                        }

                                    Text("\(rehearsal.readiness)%")
                                        .font(.caption2.weight(.bold).monospacedDigit())
                                        .foregroundStyle(isLatest ? .white : AppTheme.text)
                                }

                                Text(isLatest ? "Latest" : "R\(index + 1)")
                                    .font(.caption2.weight(isLatest ? .semibold : .regular))
                                    .foregroundStyle(isLatest ? AppTheme.brand : AppTheme.secondaryText)
                            }
                            .frame(maxWidth: .infinity)

                            if index < rehearsals.count - 1 {
                                Rectangle()
                                    .fill(AppTheme.subtleBorder)
                                    .frame(height: 2)
                                    .offset(y: -11)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(18)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rehearsals.isEmpty ? "No rehearsal progress yet" : "Readiness progression: \(rehearsals.map { "\($0.readiness)%" }.joined(separator: " to "))")
    }
}

private struct ImprovementProgressRow: View {
    let title: String
    let from: Int
    let to: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Spacer()
                Text("+\(to - from) pts")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppTheme.success)
            }

            // Visual segmented progression bar
            GeometryReader { proxy in
                let totalWidth = proxy.size.width
                let fromWidth = max(0, min(totalWidth, totalWidth * CGFloat(from) / 100.0))
                let toWidth = max(0, min(totalWidth, totalWidth * CGFloat(to) / 100.0))

                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(AppTheme.mutedFill)
                        .frame(height: 7)

                    // Target level (gained progress)
                    Capsule()
                        .fill(AppTheme.success)
                        .frame(width: toWidth, height: 7)

                    // Previous level
                    Capsule()
                        .fill(AppTheme.success.opacity(0.4))
                        .frame(width: fromWidth, height: 7)
                }
            }
            .frame(height: 7)

            HStack {
                Text("Baseline: \(from)%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
                Text("Current: \(to)%")
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(AppTheme.success)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) improved from \(from) to \(to) percent")
    }
}

#Preview("Progress") {
    ProgressDashboardView()
        .environment(AppState.preview)
}

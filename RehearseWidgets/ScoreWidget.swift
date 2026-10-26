import SwiftUI
import WidgetKit

/// How the candidate is improving: the latest mock interview score, the
/// change since the one before, and recent scores as a chart.
struct ScoreWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LastScore", provider: SnapshotProvider()) { entry in
            ScoreView(entry: entry)
        }
        .configurationDisplayName("Your Score")
        .description("Your latest mock interview score and how it's changing.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

struct ScoreView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var isHomeScreen: Bool { family == .systemSmall || family == .systemMedium }

    var body: some View {
        Group {
            if let score = entry.snapshot.lastScore {
                content(score)
                    .widgetURL(WidgetLink.lastFeedback)
            } else {
                empty
                    .widgetURL(WidgetLink.mockInterview)
            }
        }
        // The system's own widget background: white in light mode, dark in
        // dark mode, tinted when the Home Screen is.
        .containerBackground(.background, for: .widget)
    }

    @ViewBuilder
    private func content(_ score: WidgetSnapshot.LastScore) -> some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: Double(score.overall), in: 0...100) {
                Text("Score")
            } currentValueLabel: {
                Text("\(score.overall)")
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetAccentable()
        case .systemMedium:
            medium(score)
        default:
            small(score)
        }
    }

    /// Progress at a glance, as Health and Stocks show a number: what it
    /// is, the score large, the change since last time, and the trend.
    private func small(_ score: WidgetSnapshot.LastScore) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Text("\(score.overall)")
                .font(.system(size: 46, weight: .bold, design: .rounded).monospacedDigit())
                .padding(.top, 2)
            ChangeLabel(change: score.change)
            TrendChart(history: score.history ?? [], showsValues: false)
                .frame(maxHeight: .infinity)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// The score and its change on the left; recent interviews as bars on
    /// the right, the latest in the accent. One tap opens the feedback.
    private func medium(_ score: WidgetSnapshot.LastScore) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            HStack(alignment: .bottom, spacing: 24) {
                // The score sits on the bars' base line, and its change on
                // the dates' line, so the two halves read as one chart.
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(score.overall)")
                        .font(.system(size: 60, weight: .bold, design: .rounded).monospacedDigit())
                        .padding(.bottom, -6)
                    ChangeLabel(change: score.change)
                        .frame(height: 13)
                }
                .fixedSize()
                TrendChart(history: score.history ?? [], showsValues: true, showsDates: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// What the number is and how fresh it is: "Interview Score 2 days ago",
    /// or just "Score" where the small widget has no room.
    private var header: some View {
        let last = entry.snapshot.lastScore?.history?.last?.date
        return HStack(spacing: 4) {
            Text(family == .systemSmall ? "Score" : "Interview Score")
                .foregroundStyle(Color.brand)
                .widgetAccentable()
            if let last {
                Text(last, format: .relative(presentation: .named))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    @ViewBuilder
    private var empty: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: 0, in: 0...100) {
                Text("Score")
            } currentValueLabel: {
                Image(systemName: "mic.fill")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        default:
            WidgetEmptyState(symbol: "chart.bar.fill", title: "No Score Yet", message: "Take a mock interview to see how you did.")
        }
    }
}

#Preview(as: .systemSmall) {
    ScoreWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample)
    SnapshotEntry(date: .now, snapshot: WidgetSnapshot())
}

#Preview(as: .systemMedium) {
    ScoreWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample)
}

#Preview(as: .accessoryCircular) {
    ScoreWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample)
}

/// "Up 4 points" in green, "Down 3 points" in orange, "No change", or
/// "First interview" when there's nothing to compare with. Only this label
/// uses arrows, so an arrow always means a change over time.
private struct ChangeLabel: View {
    let change: Int?

    var body: some View {
        Group {
            if let change, change != 0 {
                Label("\(change > 0 ? "Up" : "Down") \(abs(change)) points", systemImage: change > 0 ? "arrow.up.right" : "arrow.down.right")
                    .foregroundStyle(change > 0 ? Color.success : Color.graphic)
            } else if change == 0 {
                Label("No change", systemImage: "equal")
                    .foregroundStyle(.secondary)
            } else {
                Text("First interview")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption.weight(.semibold))
        .labelStyle(TightLabelStyle())
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .widgetAccentable()
        .accessibilityLabel(change.map { $0 == 0 ? "Same as last time" : "\($0 > 0 ? "Up" : "Down") \(abs($0)) since last time" } ?? "First interview")
    }
}

/// Recent scores as rounded bars, oldest on the left; the latest in the
/// accent, the rest quiet. No axes: the heights are the story.
private struct TrendChart: View {
    let history: [WidgetSnapshot.LastScore.Point]
    var showsValues: Bool
    /// The day under each bar, so the chart says when each score was.
    var showsDates = false

    var body: some View {
        GeometryReader { proxy in
            let valueHeight: CGFloat = showsValues ? 15 : 0
            let dateHeight: CGFloat = showsDates ? 16 : 0
            let barArea = proxy.size.height - valueHeight - dateHeight
            let barWidth = min(18, proxy.size.width / CGFloat(max(history.count, 1)) * 0.5)
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(history.indices, id: \.self) { index in
                    let point = history[index]
                    let isLatest = index == history.count - 1
                    VStack(spacing: 3) {
                        if showsValues {
                            Text("\(point.score)")
                                .font(.system(size: 11, weight: isLatest ? .bold : .medium, design: .rounded).monospacedDigit())
                                .foregroundStyle(isLatest ? Color.primary : Color.secondary)
                                .frame(height: 12)
                        }
                        Capsule()
                            .fill(isLatest ? AnyShapeStyle(Color.brand.gradient) : AnyShapeStyle(Color.secondary.opacity(0.22)))
                            .frame(width: barWidth, height: max(barArea * CGFloat(min(max(point.score, 0), 100)) / 100, 6))
                            .widgetAccentable(isLatest)
                        if showsDates {
                            Text(point.date, format: .dateTime.day().month(.abbreviated))
                                .font(.system(size: 10, weight: isLatest ? .semibold : .regular))
                                .foregroundStyle(isLatest ? Color.primary : Color.secondary)
                                .lineLimit(1)
                                .fixedSize()
                                .frame(height: 13)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recent scores: \(history.map { "\($0.score)" }.joined(separator: ", "))")
    }
}

private struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}

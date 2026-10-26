import SwiftUI
import UIKit
import WidgetKit

/// Rehearse on the Home Screen and Lock Screen: the next interview and the
/// last score. Each opens the app where it points.
@main
struct RehearseWidgets: WidgetBundle {
    var body: some Widget {
        NextInterviewWidget()
        ScoreWidget()
    }
}

// MARK: - Timeline

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Reads what the app last saved. Until the app has run, the widgets show
/// the app's demo candidate, which is also what the app opens with.
struct SnapshotProvider: TimelineProvider {
    /// The next interview's "In 3 days" changes at midnight; the score only
    /// changes when the app saves something new, and it reloads it then.
    var refreshesDaily = false

    private var current: WidgetSnapshot { WidgetSnapshot.load() ?? .sample }

    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .sample : current))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<SnapshotEntry>) -> Void) {
        let snapshot = current
        guard refreshesDaily else {
            completion(Timeline(entries: [SnapshotEntry(date: .now, snapshot: snapshot)], policy: .never))
            return
        }
        // Today, then each midnight for a week, so the countdown stays right.
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let midnights = (1...7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        let entries = [SnapshotEntry(date: .now, snapshot: snapshot)]
            + midnights.map { SnapshotEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - The app's look

extension Color {
    /// The app's peach-orange for text and buttons, from the accent color.
    static let brand = Color("AccentColor")
    /// The brighter orange the app uses for bars, which carry no text.
    static let graphic = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xE8 / 255, green: 0x74 / 255, blue: 0x3A / 255, alpha: 1)
            : UIColor(red: 0xD8 / 255, green: 0x64 / 255, blue: 0x2E / 255, alpha: 1)
    })
    /// The app's green for things going well.
    static let success = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x30 / 255, green: 0xD1 / 255, blue: 0x58 / 255, alpha: 1)
            : UIColor(red: 0x1E / 255, green: 0x7B / 255, blue: 0x34 / 255, alpha: 1)
    })
}

extension Color {
    /// Behind Home's "Take a Mock Interview" banner: deep enough for white
    /// text, shading down from the lighter orange of the icon's tie.
    static let bannerTop = Color(red: 0xC8 / 255, green: 0x5C / 255, blue: 0x26 / 255)
    static let bannerBottom = Color(red: 0xB5 / 255, green: 0x50 / 255, blue: 0x1E / 255)
}

/// Whole days from the entry's own date to the interview's, so each day's
/// entry counts right.
func daysUntil(_ date: Date, from now: Date) -> Int {
    let calendar = Calendar.current
    return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
}

/// "Today", "Tomorrow", "In 3 days".
func countdown(to date: Date, from now: Date) -> String {
    let days = daysUntil(date, from: now)
    switch days {
    case ..<0: return "Passed"
    case 0: return "Today"
    case 1: return "Tomorrow"
    default: return "In \(days) days"
    }
}

/// The countdown as a headline: a big number over "days to go", or the
/// word itself on the last two days.
struct CountdownHero: View {
    let date: Date
    let now: Date
    var numberSize: CGFloat = 46

    var body: some View {
        let days = daysUntil(date, from: now)
        if days >= 2 {
            // Large figures carry room for descenders they never use, so
            // "days to go" is pulled up to sit tight under the number.
            VStack(alignment: .leading, spacing: -numberSize * 0.16) {
                Text("\(days)")
                    .font(.system(size: numberSize, weight: .bold).monospacedDigit())
                    .contentTransition(.numericText(value: Double(days)))
                    // Large figures sit in from their edge; this lines the
                    // number up with the text under it.
                    .padding(.leading, -numberSize * 0.05)
                Text("days to go")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .accessibilityElement(children: .combine)
        } else {
            Text(days == 1 ? "Tomorrow" : days == 0 ? "Today" : "Passed")
                .font(.system(size: numberSize * 0.62, weight: .bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }
}

/// The app's score ring: red below 40, orange to 79, yellow to 89, then green.
struct WidgetScoreRing: View {
    let score: Int
    var size: CGFloat
    var caption: String?
    /// A soft glow of the ring's color behind it, on a dark background.
    var glows = false

    private var lineWidth: CGFloat { max(8, size * 0.1) }
    private var progress: CGFloat { CGFloat(min(max(score, 0), 100)) / 100 }

    private var color: Color { Self.color(for: score) }

    static func color(for score: Int) -> Color {
        switch score {
        case ..<40: .red
        case ..<80: .orange
        case ..<90: .yellow
        default: .green
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .inset(by: lineWidth / 2)
                .stroke(Color(.systemFill), lineWidth: lineWidth)
            // One solid color, as the app's own ring draws it.
            Circle()
                .inset(by: lineWidth / 2)
                .trim(from: 0, to: progress)
                .stroke(color.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: glows ? color.opacity(0.35) : .clear, radius: glows ? size * 0.05 : 0)
                .widgetAccentable()
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded).monospacedDigit())
                    // Tucks the caption up under the figures, as in the app.
                    .padding(.bottom, -size * 0.02)
                if let caption {
                    Text(caption)
                        .font(.system(size: max(10, size * 0.1), weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(score) out of 100")
    }
}

/// A widget with nothing to show yet: what will appear, and how to get it.
struct WidgetEmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Color.brand)
                .widgetAccentable()
            Spacer(minLength: 0)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// The white capsule on Home's orange banner, with orange text.
struct WidgetBannerButton: View {
    let title: String
    let symbol: String

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(Color.bannerBottom)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(.white, in: Capsule())
    }
}

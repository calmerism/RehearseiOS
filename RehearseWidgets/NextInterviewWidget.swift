import SwiftUI
import WidgetKit

/// The soonest interview and how long until it, with Quick Prep a tap away.
/// On the Home Screen it's the orange of Home's mock interview banner, so it
/// reads as Rehearse at a glance.
struct NextInterviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextInterview", provider: SnapshotProvider(refreshesDaily: true)) { entry in
            NextInterviewView(entry: entry)
        }
        .configurationDisplayName("Next Interview")
        .description("See how many days until your next interview, and open Quick Prep in one tap.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

struct NextInterviewView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var isHomeScreen: Bool { family == .systemSmall || family == .systemMedium }

    var body: some View {
        Group {
            if let interview = entry.snapshot.nextInterview {
                content(interview)
                    .widgetURL(WidgetLink.quickPrep)
            } else {
                empty
                    .widgetURL(WidgetLink.home)
            }
        }
        .containerBackground(for: .widget) {
            if isHomeScreen {
                LinearGradient(colors: [.bannerTop, .bannerBottom], startPoint: .top, endPoint: .bottom)
            } else {
                Color.clear
            }
        }
    }

    @ViewBuilder
    private func content(_ interview: WidgetSnapshot.NextInterview) -> some View {
        let time = interview.date.formatted(date: .omitted, time: .shortened)
        switch family {
        case .accessoryInline:
            Label("\(interview.title), \(countdown(to: interview.date, from: entry.date).lowercased())", systemImage: "briefcase.fill")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                Text(interview.title)
                    .font(.headline)
                    .widgetAccentable()
                if let subtitle = interview.subtitle {
                    Text(subtitle)
                        .lineLimit(1)
                }
                Text("\(countdown(to: interview.date, from: entry.date)) at \(time)")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemMedium:
            medium(interview, time: time)
        default:
            small(interview, time: time)
        }
    }

    /// What it's for, the countdown large, then who it's with and when.
    private func small(_ interview: WidgetSnapshot.NextInterview, time: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            eyebrow()
            Spacer(minLength: 6)
            CountdownHero(date: interview.date, now: entry.date)
            Spacer(minLength: 12)
            Text(interview.title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("\(interview.date.formatted(.dateTime.month(.abbreviated).day())) at \(time)")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// The countdown on the left; on the right who it's with, when and what,
    /// and Quick Prep in the white capsule from Home's banner.
    private func medium(_ interview: WidgetSnapshot.NextInterview, time: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Its caption sits level with the company, and "days to go"
            // level with the middle of Quick Prep.
            VStack(alignment: .leading, spacing: 0) {
                eyebrow("Up Next")
                    .padding(.top, 4)
                Spacer(minLength: 4)
                CountdownHero(date: interview.date, now: entry.date, numberSize: 52)
                    .padding(.bottom, 7)
            }
            .frame(width: 104, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .topLeading)

            Rectangle()
                .fill(.white.opacity(0.25))
                .frame(width: 1)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 0) {
                Text(interview.title)
                    .font(.title3.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let subtitle = interview.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                VStack(alignment: .leading, spacing: 4) {
                    detail("calendar", "\(interview.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())), \(time)")
                    detail("clock.fill", "\(interview.durationMinutes)-minute \(interview.typeName)")
                }
                Spacer(minLength: 8)
                Link(destination: WidgetLink.quickPrep) {
                    WidgetBannerButton(title: "Quick Prep", symbol: "bolt.fill")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .foregroundStyle(.white)
    }

    /// The small caption over the countdown, as a card's heading. The
    /// medium's narrow column says "Up Next", as Calendar does.
    private func eyebrow(_ title: String = "Next Interview") -> some View {
        Label(title, systemImage: "briefcase.fill")
            .font(.caption.weight(.semibold))
            .labelStyle(EyebrowLabelStyle())
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1)
    }

    private func detail(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption)
                .frame(width: 14)
            Text(text)
                .font(.footnote)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(.white.opacity(0.9))
    }

    @ViewBuilder
    private var empty: some View {
        switch family {
        case .accessoryInline:
            Text("No interviews scheduled")
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text("No Interviews Scheduled")
                    .font(.headline)
                Text("Add one in Rehearse")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 4) {
                eyebrow()
                Spacer(minLength: 0)
                Text("No Interviews Scheduled")
                    .font(.headline)
                Text("Add an interview in Rehearse to count down to it.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

/// A small icon tight beside its caption.
private struct EyebrowLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
            configuration.title
        }
    }
}

#Preview(as: .systemSmall) {
    NextInterviewWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample)
    SnapshotEntry(date: .now, snapshot: WidgetSnapshot())
}

#Preview(as: .systemMedium) {
    NextInterviewWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample)
}

#Preview(as: .accessoryRectangular) {
    NextInterviewWidget()
} timeline: {
    SnapshotEntry(date: .now, snapshot: .sample)
}

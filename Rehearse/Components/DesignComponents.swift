import SwiftUI

// MARK: - Canvas

/// The warm page behind every screen: cream fading to sand, with soft light
/// pooling at the bottom.
struct WarmBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.canvasTop, AppTheme.canvasBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            GeometryReader { proxy in
                let width = proxy.size.width
                Circle()
                    .fill(AppTheme.glowRose)
                    .frame(width: width * 0.95)
                    .blur(radius: 80)
                    .opacity(0.55)
                    .position(x: width * 0.12, y: proxy.size.height * 0.68)
                Circle()
                    .fill(AppTheme.glowPeach)
                    .frame(width: width * 1.1)
                    .blur(radius: 90)
                    .opacity(0.65)
                    .position(x: width * 0.85, y: proxy.size.height * 0.92)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

extension View {
    /// Puts a screen on the warm canvas. Lists and forms drop their own
    /// grouped background so the canvas shows through.
    func warmBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(WarmBackground())
    }

    /// A milky, slightly translucent panel with a fine light edge.
    func cardBackground(cornerRadius: CGFloat = AppTheme.Radius.card) -> some View {
        background {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(AppTheme.cardFill)
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(AppTheme.cardEdge, lineWidth: 1)
                }
                .shadow(color: Color(red: 0.6, green: 0.35, blue: 0.2).opacity(0.06), radius: 16, y: 6)
        }
    }
}

// MARK: - Cards

/// A symbol on a white disc: how every card and row is anchored.
struct IconChip: View {
    let systemImage: String
    var tint: Color = .primary
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.44, weight: .regular))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(AppTheme.chip, in: Circle())
            .accessibilityHidden(true)
    }
}

/// The top line of a card: an icon chip and what the card is about.
struct CardHeader: View {
    let title: String
    let systemImage: String
    var tint: Color = .primary
    var detail: String?
    var showsChevron = false

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            IconChip(systemImage: systemImage, tint: tint)
            Text(title)
                .font(.app(.subheadline, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: AppTheme.Spacing.xs)
            if let detail {
                Text(detail)
                    .font(.app(.footnote, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.app(.footnote, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// A card with a header and content.
struct SummaryCard<Content: View>: View {
    let title: String
    let systemImage: String
    var tint: Color = .primary
    var detail: String?
    var showsChevron = false
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            CardHeader(title: title, systemImage: systemImage, tint: tint, detail: detail, showsChevron: showsChevron)
            content
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cardBackground()
    }
}

/// One number, large and bold, with its unit beside it.
struct BigValue: View {
    let value: String
    var unit: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.xxs) {
            Text(value)
                .font(.app(.title, weight: .bold).monospacedDigit())
            if let unit {
                Text(unit)
                    .font(.app(.footnote, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A change in score, colored by direction.
struct DeltaText: View {
    let delta: Int

    var body: some View {
        Text(delta > 0 ? "+\(delta)" : delta < 0 ? "−\(-delta)" : "No change")
            .font(.app(.footnote, weight: .semibold).monospacedDigit())
            .foregroundStyle(delta > 0 ? AppTheme.success : delta < 0 ? AppTheme.brand : Color.secondary)
            .accessibilityLabel(delta > 0 ? "Up \(delta)" : delta < 0 ? "Down \(-delta)" : "No change")
    }
}

/// A heading between groups of cards, with an optional quiet trailing action.
struct SectionTitle: View {
    let title: String
    var actionTitle: String?
    var actionImage = "chevron.right"
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.app(.headline))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 3) {
                        Text(actionTitle)
                        Image(systemName: actionImage)
                            .font(.app(.caption2, weight: .bold))
                    }
                }
                .font(.app(.footnote))
                .foregroundStyle(.secondary)
            }
        }
        .padding(.top, AppTheme.Spacing.md)
        .padding(.horizontal, AppTheme.Spacing.md)
    }
}

/// An overall score out of 100, drawn as a ring.
struct ScoreRing: View {
    let score: Int?
    var caption: String?
    var size: CGFloat = 84

    var body: some View {
        ZStack {
            // Inset by half the line width so the stroke stays inside the frame.
            Circle()
                .inset(by: 5)
                .stroke(AppTheme.chip, lineWidth: 10)
                .shadow(color: .black.opacity(0.05), radius: 2)
            if let score {
                let fraction = CGFloat(min(max(score, 0), 100)) / 100
                Circle()
                    .inset(by: 5)
                    .trim(from: 0, to: fraction)
                    .stroke(
                        AngularGradient(
                            colors: [AppTheme.peach, AppTheme.brand],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * fraction)
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 0) {
                Text(score.map { "\($0)" } ?? "–")
                    .font(.app(.title3, weight: .bold).monospacedDigit())
                if let caption {
                    Text(caption)
                        .font(.app(.caption2, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .background(AppTheme.chip.opacity(0.7), in: Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(score.map { "Score \($0) out of 100" } ?? "Not scored yet")
    }
}

/// Pressed feedback for a whole card that navigates.
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Pressed feedback for a row inside a card.
struct CardRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background(configuration.isPressed ? AppTheme.track : .clear)
    }
}

/// A row of capsule options, as in the reference's filters: the chosen one
/// ink-dark, the rest milky.
struct PillPicker<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let title: (Value) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.xs) {
                ForEach(options, id: \.self) { option in
                    let isSelected = option == selection
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { selection = option }
                    } label: {
                        Text(title(option))
                            .font(.app(.footnote, weight: .semibold))
                            .foregroundStyle(isSelected ? AppTheme.onInk : Color.primary)
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .frame(minHeight: 34)
                            .background {
                                Capsule()
                                    .fill(isSelected ? AppTheme.ink : AppTheme.chip)
                                    .overlay { Capsule().strokeBorder(isSelected ? .clear : AppTheme.track, lineWidth: 1) }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }
}

// MARK: - Buttons

/// Ink-dark capsule for the main action; a quiet milky capsule otherwise.
struct PillButtonStyle: ButtonStyle {
    var isProminent = true
    var isCompact = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(isCompact ? .app(.footnote, weight: .semibold) : .app(.subheadline, weight: .semibold))
            .foregroundStyle(isProminent ? AppTheme.onInk : Color.primary)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .frame(minHeight: isCompact ? 36 : 50)
            .background {
                if isProminent {
                    Capsule()
                        .fill(LinearGradient(colors: [AppTheme.inkHighlight, AppTheme.ink], startPoint: .top, endPoint: .bottom))
                        .overlay { Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1) }
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                        .opacity(isEnabled ? 1 : 0.3)
                } else {
                    Capsule()
                        .fill(AppTheme.chip)
                        .overlay { Capsule().strokeBorder(AppTheme.track, lineWidth: 1) }
                }
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PillLabel(title: title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PillButtonStyle())
    }
}

/// A navigation link that reads as the screen's primary action.
struct PrimaryLink: View {
    let title: String
    var systemImage: String?
    let route: Route

    var body: some View {
        NavigationLink(value: route) {
            PillLabel(title: title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PillButtonStyle())
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PillButtonStyle(isProminent: false))
    }
}

private struct PillLabel: View {
    let title: String
    let systemImage: String?

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
        }
    }
}

/// Pins primary actions above the tab bar so they never scroll away. Place it
/// with `safeAreaBar` so content scrolling beneath gets the system edge blur.
struct BottomActions<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            content
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
    }
}

// MARK: - Fields

/// A typed-in value with its name beside it, as in Settings, so a filled-in
/// field still says what it is.
struct LabeledTextField: View {
    let title: String
    @Binding var text: String
    var prompt: String
    var contentType: UITextContentType?

    var body: some View {
        LabeledContent(title) {
            TextField(title, text: $text, prompt: Text(prompt))
                .multilineTextAlignment(.trailing)
                .textContentType(contentType)
                .textInputAutocapitalization(.words)
        }
    }
}

// MARK: - Answering

/// The state of a single spoken answer, shared by the interview and practice.
enum AnswerState: Equatable {
    case ready
    case recording(startedAt: Date)
    case processing
    case captured
}

/// One wide control for answering out loud. Its label always says what is
/// happening, so state never relies on color or animation alone. Red while
/// recording — the convention from Voice Memos.
struct RecordingControl: View {
    let state: AnswerState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .font(.app(.subheadline, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(background, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
        .sensoryFeedback(.impact(weight: .medium), trigger: isRecording)
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    @ViewBuilder
    private var label: some View {
        switch state {
        case .ready:
            Label("Start Answering", systemImage: "mic")
        case .recording(let startedAt):
            HStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: "stop.fill")
                Text("Finish")
                Text(startedAt, style: .timer)
                    .monospacedDigit()
                    .opacity(0.8)
            }
        case .processing:
            HStack(spacing: AppTheme.Spacing.xs) {
                ProgressView()
                Text("Analyzing your answer…")
            }
        case .captured:
            Label("Answer captured", systemImage: "checkmark.circle.fill")
        }
    }

    private var foreground: Color {
        switch state {
        case .ready: AppTheme.onInk
        case .recording: .white
        case .processing: .secondary
        case .captured: AppTheme.success
        }
    }

    private var background: Color {
        switch state {
        case .ready: AppTheme.ink
        case .recording: AppTheme.record
        case .processing, .captured: AppTheme.chip
        }
    }

    private var isRecording: Bool {
        if case .recording = state { return true }
        return false
    }

    private var isEnabled: Bool {
        state == .ready || isRecording
    }

    private var accessibilityLabel: String {
        switch state {
        case .ready: "Start answering"
        case .recording: "Finish answer"
        case .processing: "Analyzing your answer"
        case .captured: "Answer captured"
        }
    }
}

// MARK: - Indicators

/// A symbol on a white disc, for list rows.
struct IconTile: View {
    let systemImage: String
    var tint: Color = .primary
    var size: CGFloat = 34

    var body: some View {
        IconChip(systemImage: systemImage, tint: tint, size: size)
    }
}

/// The day of an event at a glance, as on a calendar page. Highlighted, it
/// fills with the accent the way Calendar marks today.
struct DateTile: View {
    let date: Date?
    var isHighlighted = false

    var body: some View {
        // Negative spacing closes the gap the fonts' line heights leave.
        VStack(spacing: -4) {
            Text(date?.formatted(.dateTime.month(.abbreviated)) ?? "TBC")
                .font(.app(.caption2, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(isHighlighted ? Color.white.opacity(0.85) : Color.secondary)
            if let date {
                Text(date.formatted(.dateTime.day()))
                    .font(.app(.title2, weight: .bold).monospacedDigit().leading(.tight))
                    .foregroundStyle(isHighlighted ? Color.white : Color.primary)
            }
        }
        .frame(width: 60, height: 60)
        .background(
            isHighlighted
                ? LinearGradient(colors: [AppTheme.peach, AppTheme.brand], startPoint: .top, endPoint: .bottom)
                : LinearGradient(colors: [AppTheme.chip, AppTheme.blush], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: AppTheme.Radius.control + 2)
        )
        .accessibilityHidden(true)
    }
}

/// A part score with its bar, out of 100.
struct ScoreBar: View {
    let title: String
    let score: Int
    var tint: Color = AppTheme.brand

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                Spacer()
                Text("\(score)")
                    .font(.app(.headline).monospacedDigit())
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(AppTheme.track)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(LinearGradient(colors: [AppTheme.peach, tint], startPoint: .leading, endPoint: .trailing))
                            .frame(width: proxy.size.width * CGFloat(min(max(score, 0), 100)) / 100)
                    }
            }
            .frame(height: 6)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Progress through a fixed number of steps: the current one long and dark,
/// the rest short.
struct SegmentedProgress: View {
    let total: Int
    /// Steps fully done. The step at this index is the current one.
    let completed: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Capsule()
                    .fill(index <= completed ? AppTheme.ink : AppTheme.track)
                    .opacity(index < completed ? 0.35 : 1)
                    .frame(width: index == completed ? 28 : 18, height: 4)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: completed)
    }
}

// MARK: - Rows

struct QuestionRow: View {
    let question: Question
    var isPracticed = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
            // Explicit colors: inside a list Button, hierarchical styles take the tint.
            Text(question.text)
                .foregroundStyle(Color.primary)
            HStack(spacing: AppTheme.Spacing.xs) {
                Text(question.metaText)
                    .font(.app(.footnote))
                    .foregroundStyle(Color.secondary)
                if isPracticed {
                    Label("Practiced", systemImage: "checkmark.circle.fill")
                        .font(.app(.footnote, weight: .medium))
                        .foregroundStyle(AppTheme.success)
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .padding(.vertical, AppTheme.Spacing.xxs)
    }
}

struct RehearsalRow: View {
    let rehearsal: Rehearsal

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            IconTile(systemImage: rehearsal.kind == .interview ? "person.wave.2" : "mic")
            VStack(alignment: .leading, spacing: 2) {
                Text(rehearsal.title)
                    .font(.app(.subheadline, weight: .semibold))
                    .lineLimit(2)
                Text(rehearsal.subtitle)
                    .font(.app(.footnote))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: AppTheme.Spacing.xs)
            if let score = rehearsal.score {
                Text("\(score)")
                    .font(.app(.title3, weight: .bold).monospacedDigit())
                    .accessibilityLabel("Score \(score)")
            }
        }
        .accessibilityElement(children: .combine)
    }
}

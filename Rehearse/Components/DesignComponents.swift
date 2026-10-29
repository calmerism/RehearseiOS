import SwiftUI

// MARK: - Page

extension View {
    /// Puts a scrolling screen of cards on the system grouped background.
    /// Lists and forms already have it.
    func groupedBackground() -> some View {
        background(AppTheme.background)
    }

    /// On a screen wider than a phone (the iPhone Duo open), keeps the page
    /// at phone width in the middle, with its background either side, so
    /// rows and cards don't stretch. A phone screen is narrower than the
    /// limit, so nothing changes there.
    func phoneWidth() -> some View {
        frame(maxWidth: AppTheme.maxPageWidth)
            .frame(maxWidth: .infinity)
            .background(AppTheme.background.ignoresSafeArea())
    }

    /// Every list and form: large section headings (the same style as
    /// `SectionTitle` on card screens) and the same gap between sections.
    func appListStyle() -> some View {
        headerProminence(.increased)
            .listSectionSpacing(AppTheme.Spacing.md)
            // Lists start closer to the title than scroll views do; this
            // puts their first card where Home's is.
            .contentMargins(.top, AppTheme.Spacing.xs, for: .scrollContent)
            .debugScrollAnchor()
    }

    /// Moves a list section's header out to the heading margin, so it lines up
    /// with the page title and the headings on card screens.
    func listHeadingInset() -> some View {
        padding(.horizontal, AppTheme.Spacing.headingMargin - AppTheme.Spacing.md * 2)
    }

    /// A card on the grouped background, shaped like an inset-grouped row.
    func cardBackground(cornerRadius: CGFloat = AppTheme.Radius.card) -> some View {
        background(AppTheme.cardFill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// Grows what a finger can hit to Apple's 44 × 44pt minimum without
    /// moving anything: pad out, take that as the hit area, pad back in.
    /// Use it inside a button's label, on small links and glyphs.
    func tapTarget(_ outset: CGFloat = 12) -> some View {
        padding(outset).contentShape(Rectangle()).padding(-outset)
    }
}

// MARK: - Tab header

private struct TabRootKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True for the first screen of a tab, false once something is pushed.
    var isTabRoot: Bool {
        get { self[TabRootKey.self] }
        set { self[TabRootKey.self] = newValue }
    }
}

/// What a tab's header shows, handed down to the `TabHeader` at the top of
/// the screen's content.
struct TabHeaderContent {
    let title: String
    var isLogo = false
    let trailing: AnyView
}

private struct TabHeaderKey: EnvironmentKey {
    static let defaultValue: TabHeaderContent? = nil
}

/// A pushed page's title and subtitle, drawn by `TabHeader` at the top of
/// its content so they scroll away with the page.
struct PageHeaderContent {
    let title: String
    var subtitle: String?
}

private struct PageHeaderKey: EnvironmentKey {
    static let defaultValue: PageHeaderContent? = nil
}

private struct InListKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var tabHeader: TabHeaderContent? {
        get { self[TabHeaderKey.self] }
        set { self[TabHeaderKey.self] = newValue }
    }

    var pageHeader: PageHeaderContent? {
        get { self[PageHeaderKey.self] }
        set { self[PageHeaderKey.self] = newValue }
    }

    /// Set on a header drawn as a list row.
    var isInList: Bool {
        get { self[InListKey.self] }
        set { self[InListKey.self] = newValue }
    }
}

extension View {
    /// A pushed page's title, in the bar's own small centered style but at
    /// the top of the page's content, so it scrolls away with the page and
    /// only the back button stays. The page puts a `TabHeader` (or
    /// `TabHeaderSection` in a list) first in its content.
    func scrollingTitle(_ title: String, subtitle: String? = nil, inList: Bool = true) -> some View {
        modifier(ScrollingTitle(title: title, subtitle: subtitle, inList: inList))
    }
}

/// See `scrollingTitle`. A list runs up to the top of the screen so its
/// title row can sit level with the back button (lists clip anything moved
/// out of a row); a scroll view keeps its place and lifts the title instead.
private struct ScrollingTitle: ViewModifier {
    let title: String
    let subtitle: String?
    let inList: Bool

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .toolbar {
                // The bar's own title is left empty; the page draws it.
                ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) }
            }
            .environment(\.pageHeader, PageHeaderContent(title: title, subtitle: subtitle))
            .ignoresSafeArea(.container, edges: inList ? .top : [])
    }
}

/// The one header every tab shares: a large bold title with an optional
/// plain icon on the right. On a tab's first screen it's the first thing in
/// the content (`TabHeader`), so it scrolls away with the page like a large
/// title; content under the status bar gets the system edge blur. Pushed from
/// elsewhere, the same screen keeps the standard bar, so it still has a back
/// button.
private struct ScreenTitle<Trailing: View>: ViewModifier {
    let title: String
    var isLogo = false
    var inList = true
    let trailing: Trailing
    @Environment(\.isTabRoot) private var isTabRoot

    func body(content: Content) -> some View {
        if isTabRoot {
            content
                .navigationTitle(title)
                .toolbar(.hidden, for: .navigationBar)
                .environment(\.tabHeader, TabHeaderContent(title: title, isLogo: isLogo, trailing: AnyView(trailing)))
        } else {
            content
                .scrollingTitle(title, inList: inList)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { trailing }
                }
        }
    }
}

/// The header itself, placed first in a tab's scrolling content. Draws
/// nothing on a pushed screen, which uses the navigation bar instead.
struct TabHeader: View {
    @Environment(\.tabHeader) private var header
    @Environment(\.isTabRoot) private var isTabRoot

    @Environment(\.pageHeader) private var page
    @Environment(\.isInList) private var isInList

    /// Where a pushed page's title sits from the top of the screen: level
    /// with the back button, where the bar's own title would be.
    static let pageTitleTop: CGFloat = 68.3

    /// How far a title without a subtitle drops to sit on the back button's
    /// center line.
    private var centering: CGFloat { page?.subtitle == nil ? 7 : 0 }

    var body: some View {
        if !isTabRoot, let page {
            // The bar's own title and subtitle sizes, so it looks as it did
            // pinned in the bar.
            VStack(spacing: 2) {
                Text(page.title)
                    .font(.system(size: 15, weight: .semibold))
                if let subtitle = page.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11.25))
                        .foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 60)
            // In a list the row sits at the top of the screen; in a scroll
            // view it's lifted from below the bar and the room taken back
            // underneath, so the first card starts where it did.
            // A title alone drops by half a subtitle's height, so it's
            // centered on the back button just as a title and subtitle are;
            // the room comes back underneath, so the content doesn't move.
            .padding(.top, (isInList ? Self.pageTitleTop - AppTheme.Spacing.xs : -55.7) + centering)
            // Without a subtitle the first card comes up by the subtitle's
            // room, so the gap under the title matches the list pages'.
            .padding(.bottom, (isInList ? AppTheme.Spacing.xs : page.subtitle == nil ? -14 : 1.7) - centering)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        } else if isTabRoot, let header {
            HStack(alignment: .center) {
                titleText(header)
                    .font(.pageTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityLabel(header.title)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                header.trailing
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.brand)
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            // On the heading margin, the same line as every section heading;
            // content is already inset by 16.
            .padding(.horizontal, AppTheme.Spacing.headingMargin - AppTheme.Spacing.md)
            .padding(.top, AppTheme.Spacing.xs)
        }
    }

    /// The wordmark on Home: tighter letters and an accent full stop, as
    /// the logo is drawn.
    private func titleText(_ header: TabHeaderContent) -> Text {
        guard header.isLogo else { return Text(header.title) }
        return Text("\(Text(header.title).tracking(-1.2))\(Text(".").foregroundStyle(AppTheme.brand))")
    }
}

/// `TabHeader` as the first row of a list, on the page rather than in a card.
struct TabHeaderSection: View {
    @Environment(\.isTabRoot) private var isTabRoot
    @Environment(\.pageHeader) private var page

    var body: some View {
        if isTabRoot || page != nil {
            Section {
                TabHeader()
                    .environment(\.isInList, true)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
    }
}

extension View {
    /// `inList` is false for a page that scrolls in a `ReportScroll`.
    func screenTitle(_ title: String, inList: Bool = true) -> some View {
        modifier(ScreenTitle(title: title, inList: inList, trailing: EmptyView()))
    }

    func screenTitle<Trailing: View>(_ title: String, inList: Bool = true, @ViewBuilder trailing: () -> Trailing) -> some View {
        modifier(ScreenTitle(title: title, inList: inList, trailing: trailing()))
    }

    /// The app's own name, drawn as its wordmark.
    func logoTitle<Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        modifier(ScreenTitle(title: title, isLogo: true, trailing: trailing()))
    }
}

// MARK: - Cards

/// The top line of a card, as in Health's summaries: a title in secondary
/// gray, with an optional detail and chevron on the right. A symbol only
/// where it helps recognize the card; most cards go without. The accent
/// stays for what can be tapped and for progress.
struct CardHeader: View {
    let title: String
    var systemImage: String?
    var tint: Color = .secondary
    var detail: String?
    var showsChevron = false

    var body: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            // The symbol sits on the card's edge, as Health draws it, with a
            // tight gap to the title, so the lines below can start on that
            // same edge.
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .accessibilityHidden(true)
                }
                Text(title)
            }
                .font(.label)
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)
            Spacer(minLength: AppTheme.Spacing.xs)
            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// A card with a header and content.
struct SummaryCard<Content: View>: View {
    let title: String
    var systemImage: String?
    var tint: Color = .secondary
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
                .font(.system(.title, weight: .bold).monospacedDigit())
                .contentTransition(.numericText())
            if let unit {
                Text(unit)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The habit to apply, as one line with a lightbulb. The one way a tip is
/// shown: in Practice, the feedback report and the live interview.
struct TipRow: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "lightbulb")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Tip: \(text)")
    }
}

/// A row of figures, each a label over its value, split by hairlines. The
/// one way summary numbers are shown, on History and Profile.
struct StatGroup: View {
    struct Item: Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    let items: [Item]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider() }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(item.value)
                        .font(.title2.weight(.bold).monospacedDigit())
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, index > 0 ? AppTheme.Spacing.sm : 0)
                .accessibilityElement(children: .combine)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// A change in score, colored by direction.
struct DeltaText: View {
    let delta: Int

    var body: some View {
        Text(delta > 0 ? "+\(delta)" : delta < 0 ? "−\(-delta)" : "No change")
            .font(.footnote.weight(.semibold).monospacedDigit())
            .foregroundStyle(delta > 0 ? AppTheme.success : delta < 0 ? AppTheme.record : Color.secondary)
            .accessibilityLabel(delta > 0 ? "Up \(delta)" : delta < 0 ? "Down \(-delta)" : "No change")
    }
}

/// A heading between groups of cards, as in Health and the App Store, with an
/// optional trailing action in the tint color. A `destination` pushes a page
/// and reads "See All ›"; an `action` with an `actionImage` shows just the symbol.
struct SectionTitle: View {
    let title: String
    var actionTitle: String?
    var actionImage: String?
    var destination: Route?
    var action: (() -> Void)?
    /// A second, symbol-only action before "See All ›", like Add.
    var extraActionTitle: String?
    var extraActionImage: String?
    var extraAction: (() -> Void)?
    /// Makes the whole heading a link to the full list, with its chevron at
    /// the right end of the row, in line with the cards' chevrons below.
    var titleDestination: Route?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.lg) {
            if let titleDestination {
                NavigationLink(value: titleDestination) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(title)
                            .font(.sectionTitle)
                            .foregroundStyle(Color.primary)
                        Spacer(minLength: AppTheme.Spacing.xs)
                        // Just inside the cards' right edge: the heading
                        // sits headingMargin - md in from it, so step most
                        // of the way back out.
                        Image(systemName: "chevron.right")
                            .font(.body.weight(.bold))
                            // A solid gray, not the link's tint faded.
                            .foregroundStyle(Color(.secondaryLabel))
                            .padding(.trailing, AppTheme.Spacing.md - AppTheme.Spacing.headingMargin + 4)
                    }
                    .contentShape(Rectangle())
                    .tapTarget()
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isHeader)
                .accessibilityHint("Shows all of them")
            } else {
                Text(title)
                    .font(.sectionTitle)
                    .accessibilityAddTraits(.isHeader)
            }
            // A linked heading already fills the row to its chevron.
            if titleDestination == nil {
                Spacer(minLength: 0)
            }
            if let extraActionTitle, let extraActionImage, let extraAction {
                Button(action: extraAction) {
                    Image(systemName: extraActionImage)
                        .font(.title3.weight(.semibold))
                        .frame(height: 20)
                        .tapTarget()
                        .accessibilityLabel(extraActionTitle)
                }
            }
            if let actionTitle {
                if let destination {
                    NavigationLink(value: destination) {
                        actionLabel(actionTitle)
                    }
                } else if let action {
                    Button(action: action) {
                        actionLabel(actionTitle)
                    }
                }
            }
        }
        // On the heading margin with the page title (the page already pads
        // 16pt); 32pt from the card above, 13pt to the card below.
        .padding(.horizontal, AppTheme.Spacing.headingMargin - AppTheme.Spacing.md)
        .padding(.top, 14)
        .padding(.bottom, -3)
    }

    @ViewBuilder
    private func actionLabel(_ title: String) -> some View {
        if let actionImage {
            // Icon only, a plain tinted glyph as Reminders adds to a list;
            // the title is read aloud.
            Image(systemName: actionImage)
                .font(.title3.weight(.semibold))
                .frame(height: 20)
                .tapTarget()
                .accessibilityLabel(title)
        } else {
            HStack(spacing: 3) {
                Text(title)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
            }
            .tapTarget()
        }
    }
}

/// How something went, as a symbol alone: a green tick when it went well,
/// an orange exclamation mark when it partly did, a red cross when it
/// didn't. The same three everywhere a score is judged, with no words.
struct VerdictIcon: View {
    let score: Int

    enum Kind { case good, partial, wrong }

    static func kind(for score: Int) -> Kind {
        switch score {
        case 80...: .good
        case 40...: .partial
        default: .wrong
        }
    }

    var body: some View {
        let kind = Self.kind(for: score)
        Image(systemName: Self.symbol(kind))
            .foregroundStyle(Self.color(kind))
            .accessibilityLabel(Self.label(kind))
    }

    static func symbol(_ kind: Kind) -> String {
        switch kind {
        case .good: "checkmark.circle.fill"
        case .partial: "exclamationmark.circle.fill"
        case .wrong: "xmark.circle.fill"
        }
    }

    static func color(_ kind: Kind) -> Color {
        switch kind {
        case .good: AppTheme.practiced
        case .partial: AppTheme.graphic
        case .wrong: AppTheme.record
        }
    }

    static func label(_ kind: Kind) -> String {
        switch kind {
        case .good: "Went well"
        case .partial: "Partly"
        case .wrong: "Went wrong"
        }
    }
}

/// An overall score out of 100, drawn as a ring, as in Fitness. The ring's
/// color says how good the score is: red, orange, yellow, then green.
struct ScoreRing: View {
    let score: Int?
    var caption: String?
    var size: CGFloat = 84
    /// The change since last time, shown small under the caption.
    var delta: Int? = nil
    /// Off where the score is written beside the ring: the ring alone.
    var showsLabel = true
    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var lineWidth: CGFloat { max(8, size * 0.11) }
    private var target: CGFloat { CGFloat(min(max(score ?? 0, 0), 100)) / 100 }

    /// Red below 40, orange to 79, yellow to 89, green from 90.
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
            // Inset by half the line width so the stroke stays inside the frame.
            Circle()
                .inset(by: lineWidth / 2)
                .stroke(AppTheme.track, lineWidth: lineWidth)
            if score != nil {
                Circle()
                    .inset(by: lineWidth / 2)
                    .trim(from: 0, to: progress)
                    .stroke(Self.color(for: score ?? 0), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            // Number, caption and change as one group, centered in the ring.
            if showsLabel {
            VStack(spacing: 0) {
                if let score {
                    Text("\(score)")
                        .font(.system(size: size * 0.26, weight: .bold).monospacedDigit())
                        // Tucks the caption up under the figures.
                        .padding(.bottom, -size * 0.02)
                } else {
                    Text("No score")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                if let caption {
                    Text(caption)
                        .font(.system(size: max(11, size * 0.08), weight: .medium))
                        .foregroundStyle(.secondary)
                }
                if let delta, delta != 0 {
                    HStack(alignment: .center, spacing: 3) {
                        Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: max(9, size * 0.06), weight: .bold))
                        Text("\(abs(delta))")
                            .font(.system(size: max(11, size * 0.075), weight: .semibold).monospacedDigit())
                    }
                    .foregroundStyle(delta > 0 ? AppTheme.success : AppTheme.record)
                    .padding(.top, size * 0.035)
                }
            }
            // Optically centered: the figures have no descenders, so the
            // group reads low unless it's raised a touch.
            .offset(y: delta.map { $0 != 0 } == true ? -size * 0.022 : 0)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            guard progress != target else { return }
            if reduceMotion {
                progress = target
            } else {
                withAnimation(.smooth(duration: 0.9).delay(0.1)) { progress = target }
            }
        }
        .onChange(of: score) { progress = target }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(score.map { score in
            let change = delta.map { $0 > 0 ? ", up \($0) from last time" : $0 < 0 ? ", down \(-$0) from last time" : "" } ?? ""
            return "Score \(score) out of 100\(change)"
        } ?? "Not scored yet")
    }
}

/// Pressed feedback for a whole card that navigates: it dims, like a row.
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Pressed feedback for a row inside a card: the system row highlight.
struct CardRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background(configuration.isPressed ? Color(.systemGray4) : .clear)
    }
}

// MARK: - Buttons

/// True inside `BottomActions`, where buttons float over content and so take
/// Liquid Glass. Inside content they stay solid, per the HIG.
private struct FloatingControlsKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isFloatingControl: Bool {
        get { self[FloatingControlsKey.self] }
        set { self[FloatingControlsKey.self] = newValue }
    }
}

struct PrimaryButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void
    @Environment(\.isFloatingControl) private var isFloating
    @State private var taps = 0

    var body: some View {
        let button = Button {
            taps += 1
            action()
        } label: {
            ButtonTitle(title: title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle(isFloating: isFloating))
        .sensoryFeedback(.impact(weight: .light), trigger: taps)

        button
    }
}

/// The primary action: a solid accent capsule, like the play button. Floating over content it also takes a clear Liquid Glass layer,
/// for the system's light and touch response.
struct PrimaryButtonStyle: ButtonStyle {
    var isFloating = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .font(.body.weight(.semibold))
            // Disabled, it goes system gray, as a prominent button does,
            // rather than a faded orange that still looks tappable.
            .foregroundStyle(isEnabled ? Color.white : Color(.tertiaryLabel))
            .padding(.horizontal, AppTheme.Spacing.lg)
            .frame(minHeight: 50)
            .background(isEnabled ? AppTheme.buttonFill : Color(.systemGray5), in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)

        if isFloating {
            label.glassEffect(.clear.interactive(), in: .capsule)
        } else {
            label
        }
    }
}

/// A navigation link that reads as the screen's primary action.
struct PrimaryLink: View {
    let title: String
    var systemImage: String?
    let route: Route

    var body: some View {
        NavigationLink(value: route) {
            ButtonTitle(title: title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.isFloatingControl) private var isFloating

    var body: some View {
        let button = Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)

        if isFloating {
            button.buttonStyle(.glass)
        } else {
            button.buttonStyle(.bordered)
        }
    }
}

private struct ButtonTitle: View {
    let title: String
    let systemImage: String?

    var body: some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
        } else {
            Text(title)
        }
    }
}

/// Pins primary actions above the tab bar so they never scroll away. Place it
/// with `safeAreaBar` so content scrolling beneath gets the system edge blur.
/// The buttons inside are Liquid Glass, sharing one container so they blend
/// and morph together.
struct BottomActions<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        GlassEffectContainer(spacing: AppTheme.Spacing.sm) {
            VStack(spacing: AppTheme.Spacing.sm) {
                content
            }
        }
        .environment(\.isFloatingControl, true)
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
    }
}

// MARK: - Fields

/// A search field drawn like the system's, for screens whose header is in
/// the page rather than the navigation bar.
struct SearchField: View {
    let prompt: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(prompt, text: $text, prompt: .prompt(prompt))
                .focused($isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .tapTarget(14)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(AppTheme.cardFill, in: Capsule())
        // A hairline, so it reads as part of the page, not a hole in it.
        .overlay(Capsule().strokeBorder(Color(.separator).opacity(0.5), lineWidth: 0.5))
        .contentShape(Capsule())
        .onTapGesture { isFocused = true }
    }
}

/// A typed-in value with its name beside it, as in Settings, so a filled-in
/// field still says what it is.
extension Text {
    /// A text field's placeholder, in the secondary label gray: the
    /// system's own placeholder gray is too faint to read comfortably.
    static func prompt(_ string: String) -> Text {
        Text(string).foregroundStyle(Color(.secondaryLabel))
    }
}

struct LabeledTextField: View {
    let title: String
    @Binding var text: String
    var prompt: String
    var contentType: UITextContentType?

    var body: some View {
        LabeledContent(title) {
            TextField(title, text: $text, prompt: .prompt(prompt))
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

/// One wide Liquid Glass control for answering out loud. Its label always
/// says what is happening, so state never relies on color or animation alone.
/// Red while recording — the convention from Voice Memos.
struct RecordingControl: View {
    let state: AnswerState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .font(.headline)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity, minHeight: 52)
                // Ready, it wears the same fill as every primary button.
                .background {
                    if state == .ready {
                        Capsule().fill(AppTheme.buttonFill)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(glass, in: .capsule)
        .animation(.smooth(duration: 0.25), value: state)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
        .sensoryFeedback(.impact(weight: .medium), trigger: isRecording)
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    @ViewBuilder
    private var label: some View {
        switch state {
        case .ready:
            Text("Speak")
        case .recording(let startedAt):
            HStack(spacing: AppTheme.Spacing.xs) {
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
        case .ready, .recording: .white
        case .processing: .secondary
        case .captured: AppTheme.success
        }
    }

    /// Tinted glass while it can be tapped; clear glass while it waits.
    private var glass: Glass {
        switch state {
        case .ready: .clear.interactive()
        case .recording: .regular.tint(AppTheme.record).interactive()
        case .processing, .captured: .regular
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

/// The day of an event at a glance, as on a calendar page: the month in
/// small capitals over a bold day number, on a quiet gray tile.
struct DateTile: View {
    let date: Date?

    var body: some View {
        // Negative spacing closes the gap the font's line heights leave.
        VStack(spacing: -4) {
            Text(date?.formatted(.dateTime.month(.abbreviated)) ?? "TBC")
                .font(.caption2.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            if let date {
                Text(date.formatted(.dateTime.day()))
                    .font(.title2.weight(.bold).monospacedDigit().leading(.tight))
                    .foregroundStyle(Color.primary)
            }
        }
        .frame(width: 60, height: 60)
        .background(AppTheme.fill, in: RoundedRectangle(cornerRadius: AppTheme.Radius.control + 2, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// How soon an interview is, in the date tile's shape: "3 / DAYS",
/// "1 / DAY", or "TODAY", so the most urgent fact is the biggest thing.
struct CountdownTile: View {
    let date: Date?

    private var days: Int? {
        guard let date else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: calendar.startOfDay(for: date)).day
    }

    /// Within three days the tile warms to the accent, so how soon shows
    /// before the number is read.
    private var isSoon: Bool { days.map { $0 >= 0 && $0 <= 3 } ?? false }

    var body: some View {
        VStack(spacing: 1) {
            if let days, days > 0 {
                Text("\(days)")
                    .font(.title2.weight(.bold).monospacedDigit().leading(.tight))
                    .foregroundStyle(isSoon ? AppTheme.brand : Color.primary)
                Text(days == 1 ? "Day" : "Days")
                    .font(.caption2.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(isSoon ? AppTheme.brand : Color.secondary)
            } else {
                Text(days == 0 ? "Today" : "TBC")
                    .font(.footnote.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(days == 0 ? AppTheme.brand : Color.secondary)
            }
        }
        .frame(width: 60, height: 60)
        .background(isSoon ? AppTheme.graphic.opacity(0.14) : AppTheme.fill, in: RoundedRectangle(cornerRadius: AppTheme.Radius.control + 2, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(days.map { $0 == 0 ? "Today" : $0 == 1 ? "In 1 day" : "In \($0) days" } ?? "No date")
    }
}

/// A part score with its bar, out of 100.
struct ScoreBar: View {
    let title: String
    let score: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                Spacer()
                Text("\(score)")
                    .font(.headline.monospacedDigit())
            }
            ProgressView(value: Double(min(max(score, 0), 100)), total: 100)
                .tint(AppTheme.graphic)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Progress through a fixed number of steps.
struct SegmentedProgress: View {
    let total: Int
    /// Steps fully done.
    let completed: Int

    var body: some View {
        ProgressView(value: Double(min(completed, total)), total: Double(max(total, 1)))
            .tint(AppTheme.brand)
            .animation(.easeInOut(duration: 0.25), value: completed)
    }
}

// MARK: - Rows

struct QuestionRow: View {
    let question: Question
    var isPracticed = false
    /// Bold by default; a screen can match its own heading weight instead.
    var font: Font = .questionRow
    /// Ends the gray line with a full stop, as the Questions page writes it.
    var endsWithPeriod = false
    /// Shows "Practiced" right-aligned on the gray line, as Mail puts a
    /// message's date on the right, instead of straight after the gray text.
    /// The question above keeps the row's full width.
    var practicedOnTrailing = false
    /// Long questions end in an ellipsis, as Mail previews a message; the
    /// question's own page shows all of it.
    var lineLimit = 3

    var body: some View {
        // Trailing, the tick is its own column, centered on the row beside
        // the chevron; otherwise it follows the gray line.
        HStack(alignment: .center, spacing: AppTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                // Explicit colors: inside a list Button, hierarchical styles take the tint.
                Text(question.text)
                    .font(font)
                    .foregroundStyle(Color.primary)
                    .lineLimit(lineLimit)
                    .truncationMode(.tail)
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.xs) {
                    Text(endsWithPeriod ? question.metaText + "." : question.metaText)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                    if isPracticed && !practicedOnTrailing {
                        practicedTick
                    }
                }
            }
            if isPracticed && practicedOnTrailing {
                Spacer(minLength: 0)
                practicedTick
            }
        }
        .padding(.vertical, AppTheme.Spacing.xxs)
    }

    /// A tick alone, as a finished step shows; read aloud as "Practiced".
    private var practicedTick: some View {
        DoneMark()
            .accessibilityLabel("Practiced")
    }
}

struct RehearsalRow: View {
    let rehearsal: Rehearsal

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rehearsal.title)
                    // A practice entry's title is the question itself.
                    .font(rehearsal.kind == .practice ? .questionRow : .rowTitle)
                    .lineLimit(2)
                Text(rehearsal.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.secondary)
            }
            Spacer(minLength: AppTheme.Spacing.xs)
            if let score = rehearsal.score {
                Text("\(score)")
                    .font(.rowScore)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Score \(score)")
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A detail line with its symbol, as Calendar lists an event's time and
/// place: every symbol centered in the same narrow column, in the text's
/// own gray, so the lines of text start on one edge.
struct DetailLabelStyle: LabelStyle {
    /// A color for the symbol alone; nil keeps the text's.
    var iconColor: Color?

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Group {
                if let iconColor {
                    configuration.icon.foregroundStyle(iconColor)
                } else {
                    configuration.icon
                }
            }
                .frame(width: 20)
                .accessibilityHidden(true)
            configuration.title
        }
    }
}

/// The one way the app marks something as practiced: the word alone,
/// bold and green. No icon, so it reads as part of the line rather than a
/// badge. `text` can add when ("Practiced 2 days ago").
struct PracticedLabel: View {
    var text = "Practiced"

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(AppTheme.practiced)
            .lineLimit(1)
    }
}

// MARK: - Marks

/// The app's one mark for a choice: a filled orange tick in a circle when
/// chosen, an empty circle when not. Orange means "yours".
struct SelectionMark: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isSelected ? AppTheme.brand : Color(.tertiaryLabel))
            .contentTransition(.symbolEffect(.replace))
            .accessibilityHidden(true)
    }
}

/// The app's one mark for something done or practiced: the same tick in a
/// circle, filled green. Green means "done".
struct DoneMark: View {
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.title3)
            .foregroundStyle(AppTheme.practiced)
    }
}

// MARK: - Interview type

/// An interview type as a list row: its name, an ⓘ that says who it's for,
/// and a check when chosen.
struct InterviewTypeRow: View {
    let type: InterviewType
    let isSelected: Bool
    let select: () -> Void
    @State private var isShowingInfo = false

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Button(action: select) {
                HStack {
                    Text(type.interviewName)
                        .foregroundStyle(Color.primary)
                    Spacer(minLength: AppTheme.Spacing.xs)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            SelectionMark(isSelected: isSelected)
            Button {
                isShowingInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(AppTheme.brand)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("About \(type.interviewName)")
            .popover(isPresented: $isShowingInfo) {
                Text(type.summary)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 260, alignment: .leading)
                    .padding()
                    .presentationCompactAdaptation(.popover)
            }
        }
    }
}

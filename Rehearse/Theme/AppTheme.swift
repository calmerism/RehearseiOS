import SwiftUI

/// Shared visual tokens for Rehearse. Everything leans on the system: San
/// Francisco at Dynamic Type sizes, semantic grouped backgrounds, and system
/// colors that adapt to dark mode and Increase Contrast on their own. One
/// accent tints actions, progress and the one thing that matters next.
enum AppTheme {
    // MARK: - Color

    /// Peach-orange accent: buttons, links, rings, the next interview.
    /// Every color that draws text clears WCAG AA, 4.5:1, on both the card
    /// and the grouped page behind it, in light and dark mode.
    static let brand = Color.adaptive(light: 0xB5501E, dark: 0xE8743A)
    /// Rings, bars and artwork carry no text, so they keep the brighter
    /// orange (3:1 is the bar for graphics).
    static let graphic = Color.adaptive(light: 0xD8642E, dark: 0xE8743A)
    /// Behind primary buttons and the play disc, deep enough for white text
    /// at 4.5:1 in both modes.
    static let buttonFill = Color(hex: 0xB5501E)
    /// The lighter top of the profile picture's disc, which shades down to
    /// `buttonFill` like the app icon's tie.
    static let avatarTop = Color(hex: 0xE07A3F)
    /// Behind the suit on the dock's mock interview button: the app icon's
    /// own background, white or its dark-mode brown, so the button looks
    /// like the icon and its tie stands out.
    static let iconFill = Color.adaptive(light: 0xFFFFFF, dark: 0x3A2E27)
    /// Recording, and nothing else, the convention from Voice Memos.
    static let record = Color.adaptive(light: 0xCC2419, dark: 0xFF6961)
    static let success = Color.adaptive(light: 0x1E7B34, dark: 0x30D158)
    /// A brighter green for the "Practiced" word, Apple's own system green
    /// for text on white (bold, so it still reads).
    static let practiced = Color.adaptive(light: 0x248A3D, dark: 0x30D158)

    /// The page behind cards, as in Settings and Health.
    static let background = Color(.systemGroupedBackground)
    /// A card on that page.
    static let cardFill = Color(.secondarySystemGroupedBackground)
    /// Quiet fills inside a card: tiles, tracks, inactive states.
    static let fill = Color(.tertiarySystemFill)
    static let track = Color(.systemFill)

    /// Kept for call sites that distinguish categories.
    static let focus = brand
    static let results = Color.blue


    // MARK: - Layout

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        /// Where page titles and section headings start, from the screen edge.
        static let headingMargin: CGFloat = 24
    }

    enum Radius {
        static let tile: CGFloat = 10
        static let control: CGFloat = 14
        /// Matches inset-grouped list rows.
        static let card: CGFloat = 26
    }
}

private extension Color {
    nonisolated init(hex: UInt) {
        self.init(uiColor: UIColor(rgb: hex))
    }

    /// Dynamic UIKit colors are resolved off the main actor by SwiftUI's
    /// renderer, so the provider must be nonisolated.
    nonisolated static func adaptive(light: UInt, dark: UInt) -> Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
            }
        )
    }
}

private extension UIColor {
    nonisolated convenience init(rgb: UInt) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}


/// The app's type scale. Every screen uses these names, so the same kind of
/// text is always the same size and weight. All San Francisco, all Dynamic Type.
extension Font {
    /// "Rehearse.", "Practice", "History".
    static let pageTitle = Font.largeTitle.weight(.bold)
    /// "Upcoming Interviews", "Recent Interviews".
    static let sectionTitle = Font.title3.weight(.bold)
    /// The one name a card is about: "Apple", "Answer Structure".
    static let cardTitle = Font.title2.weight(.bold)
    // Questions are semibold at every size, the weight of the section
    // headings, so the question is always the first thing you read.
    /// A question on the screen that is about it: live, practice, detail.
    /// Title 2, tightly led: at Title size iOS 26 spaces lines so far apart
    /// that a two-line question read as two headlines. Semibold, the weight
    /// of the section headings.
    static let questionLarge = Font.title2.weight(.semibold).leading(.tight)
    /// A question inside a card among others.
    static let questionInCard = Font.title3.weight(.semibold)
    /// A question as the first line of a row.
    static let questionRow = Font.body.weight(.semibold)
    /// A label above content, in secondary gray: "Score Breakdown".
    static let label = Font.subheadline.weight(.semibold)
    /// The first line of a row: "Software Engineer at Apple".
    static let rowTitle = Font.headline
    /// A score at the end of a row.
    static let rowScore = Font.headline.monospacedDigit()
}

extension View {
    /// A card title, at the system's own line spacing.
    func cardTitleStyle() -> some View {
        font(.cardTitle)
    }
}

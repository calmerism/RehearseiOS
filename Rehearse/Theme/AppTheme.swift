import CoreText
import SwiftUI
import UIKit

/// Shared visual tokens for Rehearse: a warm, calm canvas with milky cards,
/// ink-dark actions and a peach-orange accent reserved for progress and the
/// one thing that matters next.
enum AppTheme {
    // MARK: - Color

    /// Peach-orange accent: rings, active bars, the next interview, links.
    static let brand = Color.adaptive(light: 0xD8642E, dark: 0xF39A62)
    /// Recording, and nothing else — the convention from Voice Memos.
    static let record = Color.red
    static let success = Color.adaptive(light: 0x2F8A57, dark: 0x6CCB93)

    /// Pill buttons: near-black on the light canvas, cream on the dark one.
    static let ink = Color.adaptive(light: 0x1F1B18, dark: 0xF4ECE2)
    /// The lit top edge of an ink pill.
    static let inkHighlight = Color.adaptive(light: 0x4A4440, dark: 0xFFFFFF)
    /// The light end of the accent gradient.
    static let peach = Color.adaptive(light: 0xF7B98E, dark: 0xF8C29C)
    /// A blush tint for quiet tiles.
    static let blush = Color.adaptive(light: 0xF8E4DC, lightAlpha: 1, dark: 0xFFFFFF, darkAlpha: 0.06)
    /// The shaded foot of a quiet chart bar.
    static let barShade = Color.adaptive(light: 0xE6DDD3, lightAlpha: 1, dark: 0xFFFFFF, darkAlpha: 0.10)
    static let onInk = Color.adaptive(light: 0xFFFFFF, dark: 0x1F1B18)

    /// The warm canvas behind everything.
    static let canvasTop = Color.adaptive(light: 0xFBF6EF, dark: 0x17130F)
    static let canvasBottom = Color.adaptive(light: 0xF6E7D6, dark: 0x1E1611)
    /// Soft light pooling at the bottom of the canvas.
    static let glowPeach = Color.adaptive(light: 0xF8B98C, dark: 0x7A3E1C)
    static let glowRose = Color.adaptive(light: 0xF5B5B8, dark: 0x5A2730)

    /// Milky card fill and its fine edge.
    static let cardFill = Color.adaptive(light: 0xFFFFFF, lightAlpha: 0.5, dark: 0xFFFFFF, darkAlpha: 0.07)
    static let cardEdge = Color.adaptive(light: 0xFFFFFF, lightAlpha: 0.9, dark: 0xFFFFFF, darkAlpha: 0.10)
    /// White discs behind icons and small controls.
    static let chip = Color.adaptive(light: 0xFFFFFF, lightAlpha: 1, dark: 0xFFFFFF, darkAlpha: 0.12)
    /// Recessed tracks: unfilled bars, inactive steps.
    static let track = Color.adaptive(light: 0x1F1B18, lightAlpha: 0.08, dark: 0xFFFFFF, darkAlpha: 0.12)

    /// Kept for call sites that distinguish categories; in this palette they
    /// read as ink, so only progress and the next step carry color.
    static let focus = Color.primary
    static let results = Color.primary

    // MARK: - Type

    /// The interviewer's words: the app's face at a heavier weight, so the
    /// question leads without a second typeface.
    static func question(_ style: Font.TextStyle = .title2) -> Font {
        .app(style, weight: .semibold)
    }

    // MARK: - Layout

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let tile: CGFloat = 10
        static let control: CGFloat = 14
        static let card: CGFloat = 22
    }
}

// MARK: - Typeface

/// Plus Jakarta Sans, bundled under the SIL Open Font License (see
/// Resources/Fonts/OFL.txt). Sizes follow Dynamic Type through `relativeTo`.
enum AppFont {
    /// Registers the bundled faces for this process, so no Info.plist entry is needed.
    static func register() {
        for url in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [] {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        styleNavigationBars()
    }

    nonisolated static func name(for weight: Font.Weight) -> String {
        switch weight {
        case .black, .heavy: "PlusJakartaSans-ExtraBold"
        case .bold: "PlusJakartaSans-Bold"
        case .semibold: "PlusJakartaSans-SemiBold"
        case .medium: "PlusJakartaSans-Medium"
        default: "PlusJakartaSans-Regular"
        }
    }

    nonisolated static func size(for style: Font.TextStyle) -> CGFloat {
        switch style {
        // A step under the system sizes: Jakarta's large x-height reads bigger.
        case .largeTitle: 28
        case .title: 24
        case .title2: 20
        case .title3: 17
        case .headline, .body: 15
        case .callout: 14
        case .subheadline: 13
        case .footnote: 12
        case .caption: 11
        case .caption2: 10
        default: 17
        }
    }

    /// Navigation titles are drawn by UIKit, so they take the face here.
    private static func styleNavigationBars() {
        let appearance = UINavigationBar.appearance()
        if let title = UIFont(name: name(for: .semibold), size: 15) {
            appearance.titleTextAttributes = [.font: UIFontMetrics(forTextStyle: .headline).scaledFont(for: title)]
        }
        if let large = UIFont(name: name(for: .bold), size: 28) {
            appearance.largeTitleTextAttributes = [.font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: large)]
        }
    }
}

extension Font {
    /// The app's typeface at a Dynamic Type style. Headline defaults to semibold, as the system's does.
    static func app(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> Font {
        let resolved = weight ?? (style == .headline ? .semibold : .regular)
        return .custom(AppFont.name(for: resolved), size: AppFont.size(for: style), relativeTo: style)
    }
}

private extension Color {
    /// Dynamic UIKit colors are resolved off the main actor by SwiftUI's
    /// renderer, so the provider must be nonisolated.
    nonisolated static func adaptive(light: UInt, dark: UInt) -> Color {
        adaptive(light: light, lightAlpha: 1, dark: dark, darkAlpha: 1)
    }

    nonisolated static func adaptive(light: UInt, lightAlpha: CGFloat, dark: UInt, darkAlpha: CGFloat) -> Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(rgb: dark, alpha: darkAlpha)
                    : UIColor(rgb: light, alpha: lightAlpha)
            }
        )
    }
}

private extension UIColor {
    nonisolated convenience init(rgb: UInt, alpha: CGFloat) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: alpha
        )
    }
}

import SwiftUI

/// The launch animation. It picks up from the system launch screen (the
/// suit on the icon's own background, light or dark, same size and place),
/// gives a small breath in, then the suit grows past the screen as a window:
/// the app shows through its shape, a little dim, and brightens as it opens.
struct LaunchReveal: View {
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false
    /// The suit stops being drawn and becomes the window.
    @State private var open = false
    @State private var grow = false
    @State private var brighten = false
    /// With Reduce Motion, the whole screen just fades.
    @State private var fade = false

    /// The logo's size on the launch screen: the 240 px image at 3x.
    static let logoSize: CGFloat = 80

    var body: some View {
        ZStack {
            // The app, seen through the window, starts dim.
            Color.black.opacity(brighten ? 0 : 0.3)
            Color("LaunchBackground")
                .mask {
                    Rectangle()
                        .overlay { logo.blendMode(.destinationOut) }
                        .compositingGroup()
                }
            logo.opacity(open ? 0 : 1)
        }
        .opacity(fade ? 0 : 1)
        .ignoresSafeArea()
        .allowsHitTesting(!grow && !fade)
        .accessibilityHidden(true)
        .task { await play() }
    }

    private var logo: some View {
        Image("SuitLogo")
            .resizable()
            .scaledToFit()
            .frame(width: Self.logoSize, height: Self.logoSize)
            .scaleEffect(grow ? 32 : breathe ? 0.85 : 1)
    }

    private func play() async {
        guard !reduceMotion else {
            try? await Task.sleep(for: .seconds(0.3))
            withAnimation(.easeOut(duration: 0.3)) { fade = true }
            finish(after: 0.3)
            return
        }
        try? await Task.sleep(for: .seconds(0.3))
        withAnimation(.easeInOut(duration: 0.3)) { breathe = true }
        try? await Task.sleep(for: .seconds(0.3))
        withAnimation(.timingCurve(0.6, 0, 0.9, 0.6, duration: 0.55)) { grow = true }
        withAnimation(.easeIn(duration: 0.15)) { open = true }
        try? await Task.sleep(for: .seconds(0.25))
        withAnimation(.easeOut(duration: 0.45)) { brighten = true }
        finish(after: 0.45)
    }

    private func finish(after seconds: Double) {
        Task {
            try? await Task.sleep(for: .seconds(seconds))
            onFinished()
        }
    }
}

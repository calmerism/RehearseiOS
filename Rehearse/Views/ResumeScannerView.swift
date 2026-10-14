import SwiftUI

/// Scanning a printed resume, laid out as the system document camera is:
/// Cancel at the top, the page found and outlined in the view, a shutter
/// at the bottom, the scan's thumbnail on the left and Save on the right.
/// On a phone this is VisionKit's own scanner; the prototype draws it,
/// since the simulator has no camera.
struct ResumeScannerView: View {
    /// Called with the scan once it's saved.
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var hasScan = false
    @State private var flash = false
    @State private var found = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            viewfinder
                .padding(.horizontal, AppTheme.Spacing.xs)
            Color.white
                .opacity(flash ? 0.85 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .preferredColorScheme(.dark)
        .task {
            // The page is found a moment after the camera opens.
            try? await Task.sleep(for: .seconds(0.8))
            withAnimation(.spring(duration: 0.4, bounce: 0.2)) { found = true }
        }
    }

    /// A page on a desk, slightly turned, as a camera sees it, outlined once
    /// it's found.
    private var viewfinder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.3), Color(white: 0.16)], startPoint: .top, endPoint: .bottom))
            ResumePage(context: MockData.resume, width: 236)
                .overlay {
                    // The edges VisionKit found, tinted until the scan is taken.
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(found && !hasScan ? 0.18 : 0))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.blue.opacity(found && !hasScan ? 0.9 : 0), lineWidth: 2.5)
                        }
                        .padding(-5)
                }
                .rotation3DEffect(.degrees(14), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .rotationEffect(.degrees(-4))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(found ? "Page found" : "Looking for a page")
    }

    private var topBar: some View {
        ZStack {
            Text(hasScan ? "Ready for the next page" : found ? "Hold steady" : "Position the page in view")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, 6)
                .background(.black.opacity(0.55), in: Capsule())
                .contentTransition(.opacity)
            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(.white)
                    .frame(minHeight: 44)
                Spacer()
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.xs)
        .animation(.smooth(duration: 0.25), value: found)
        .animation(.smooth(duration: 0.25), value: hasScan)
    }

    private var bottomBar: some View {
        HStack {
            // The scan so far, as a small page.
            ZStack {
                if hasScan {
                    ResumePage(context: MockData.resume, width: 40)
                        .transition(.scale(scale: 0.4, anchor: .center).combined(with: .opacity))
                }
            }
            .frame(width: 64, alignment: .leading)

            Spacer()

            Button(action: capture) {
                ZStack {
                    Circle().stroke(.white, lineWidth: 4).frame(width: 72, height: 72)
                    Circle().fill(.white).frame(width: 58, height: 58)
                }
            }
            .buttonStyle(ShutterStyle())
            .disabled(hasScan)
            .opacity(hasScan ? 0.4 : 1)
            .accessibilityLabel("Take scan")

            Spacer()

            Button(hasScan ? "Save (1)" : "Save") {
                onSave()
                dismiss()
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(hasScan ? .white : .white.opacity(0.35))
            .disabled(!hasScan)
            .frame(width: 64, alignment: .trailing)
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.md)
    }

    private func capture() {
        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        Task {
            try? await Task.sleep(for: .seconds(0.12))
            withAnimation(.easeIn(duration: 0.3)) { flash = false }
            withAnimation(.spring(duration: 0.45, bounce: 0.25)) { hasScan = true }
        }
    }
}

/// The shutter sinks a little while held.
private struct ShutterStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.3), value: configuration.isPressed)
    }
}

#Preview {
    ResumeScannerView {}
}

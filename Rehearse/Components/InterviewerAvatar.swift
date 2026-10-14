import SwiftUI

/// What the AI interviewer is doing, which sets how it moves.
enum InterviewerMood: Equatable {
    /// Saying the question.
    case asking
    /// Waiting for the candidate to start.
    case waiting
    /// The candidate is answering.
    case listening
    /// Reading the answer.
    case thinking
    /// Answer received.
    case done

    var status: String {
        switch self {
        case .asking: "Asking"
        case .waiting: "Your turn"
        case .listening: "Listening"
        case .thinking: "Thinking"
        case .done: "Got it"
        }
    }
}

// MARK: - Video tile

/// The AI interviewer as a video call, until the real video avatar arrives:
/// an illustrated interviewer in a softly lit room who talks while asking,
/// blinks and breathes, and nods along while the candidate answers.
struct InterviewerVideo: View {
    let mood: InterviewerMood
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            // Takes whatever height it's given; the figure scales with it.
            GeometryReader { proxy in
                let height = proxy.size.height
                ZStack {
                    room(t)
                    // Head and shoulders, framed as a video call is.
                    InterviewerFigure(mood: mood, t: t)
                        .frame(width: height, height: height)
                        .offset(y: height * 0.04)
                }
                .frame(width: proxy.size.width, height: height)
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Interviewer, \(mood.status.lowercased())")
    }

    /// A warm, out-of-focus office: a gradient wall, a window glow and
    /// drifting bokeh lights.
    private func room(_ t: Double) -> some View {
        ZStack {
            LinearGradient(colors: [Color(rgb: 0x3B3F4A), Color(rgb: 0x23262D)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(rgb: 0xF2B27E).opacity(0.45), .clear], center: UnitPoint(x: 0.82, y: 0.2), startRadius: 0, endRadius: 220)
            Canvas { context, size in
                let lights: [(x: Double, y: Double, r: Double, speed: Double)] = [
                    (0.12, 0.25, 22, 0.20), (0.28, 0.12, 12, 0.35), (0.72, 0.35, 16, 0.25),
                    (0.9, 0.62, 26, 0.15), (0.06, 0.7, 14, 0.3), (0.55, 0.08, 10, 0.4),
                ]
                for light in lights {
                    let x = size.width * light.x + sin(t * light.speed + light.y * 10) * 6
                    let y = size.height * light.y + cos(t * light.speed * 0.8 + light.x * 10) * 4
                    let rect = CGRect(x: x - light.r, y: y - light.r, width: light.r * 2, height: light.r * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(Color(rgb: 0xFFD9B0).opacity(0.12)))
                }
            }
            .blur(radius: 6)
        }
    }
}

// MARK: - Self view

/// The candidate's own camera, as FaceTime shows it: a small tile in the
/// corner of the call, so they can see how they come across while they
/// answer (eye contact counts towards Confidence). In the prototype the
/// camera is drawn; it talks while the candidate is answering. With the
/// camera off, the tile goes dark with a slashed camera.
struct SelfViewTile: View {
    /// While the candidate is answering.
    let isTalking: Bool
    let isCameraOn: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let size = CGSize(width: 92, height: 124)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !isCameraOn)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                if isCameraOn {
                    // A plain wall at home, lit from a window on the left.
                    LinearGradient(colors: [Color(rgb: 0xDCD3C6), Color(rgb: 0xBDB2A3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    // Head and shoulders, framed close, as a front camera does.
                    InterviewerFigure(mood: isTalking ? .asking : .waiting, t: t + 7, look: .candidate)
                        .frame(width: 140, height: 140)
                        .offset(y: 6)
                } else {
                    Color(rgb: 0x2C2C2E)
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .frame(width: Self.size.width, height: Self.size.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.3), radius: 8, y: 3)
        .animation(.smooth(duration: 0.25), value: isCameraOn)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isCameraOn ? "Your camera" : "Your camera is off")
    }
}

/// The recording of one answer, played back from Your Score: the
/// candidate's camera as it was while they answered, with a play button, a
/// scrubber and the time, as a video in Photos plays inline. It's how they
/// see their eye contact and how sure they looked. Drawn in the prototype.
struct AnswerVideo: View {
    /// How long the answer took.
    let seconds: Int
    @State private var isPlaying = false
    @State private var played: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            isPlaying.toggle()
        } label: {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !isPlaying)) { timeline in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                GeometryReader { proxy in
                    ZStack {
                        LinearGradient(colors: [Color(rgb: 0xDCD3C6), Color(rgb: 0xBDB2A3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        InterviewerFigure(mood: isPlaying ? .asking : .waiting, t: isPlaying ? t : 0, look: .candidate)
                            .frame(width: proxy.size.height * 1.15, height: proxy.size.height * 1.15)
                            .offset(y: proxy.size.height * 0.1)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .aspectRatio(16 / 10, contentMode: .fit)
            .overlay(alignment: .bottom) {
                #if DEBUG
                // `-videoPoster` leaves the controls off, for the Figma image.
                if !ProcessInfo.processInfo.arguments.contains("-videoPoster") { scrubber }
                #else
                scrubber
                #endif
            }
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.smooth(duration: 0.2), value: isPlaying)
        .task(id: isPlaying) {
            // Plays through in a few seconds in the prototype.
            guard isPlaying else { return }
            if played >= 1 { played = 0 }
            while isPlaying, played < 1 {
                try? await Task.sleep(for: .seconds(0.1))
                played = min(played + 0.1 / 8, 1)
            }
            if played >= 1 { isPlaying = false }
        }
        .accessibilityLabel(isPlaying ? "Pause your answer" : "Play your answer")
        .accessibilityValue(time(Int(Double(seconds) * played)))
    }

    /// Play or pause, a thin track along the bottom, and the time played
    /// and left, kept off the face.
    private var scrubber: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 20)
                .contentTransition(.symbolEffect(.replace))
            Text(time(Int(Double(seconds) * played)))
            GeometryReader { proxy in
                Capsule()
                    .fill(.white.opacity(0.35))
                    .overlay(alignment: .leading) {
                        Capsule().fill(.white).frame(width: proxy.size.width * played)
                    }
            }
            .frame(height: 4)
            Text("-" + time(seconds - Int(Double(seconds) * played)))
        }
        .font(.caption.monospacedDigit().weight(.medium))
        .foregroundStyle(.white)
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.top, AppTheme.Spacing.lg)
        .padding(.bottom, AppTheme.Spacing.sm)
        .background(LinearGradient(colors: [.black.opacity(0), .black.opacity(0.45)], startPoint: .top, endPoint: .bottom))
    }

    private func time(_ seconds: Int) -> String {
        String(format: "%d:%02d", max(seconds, 0) / 60, max(seconds, 0) % 60)
    }
}

/// How a drawn person looks: the interviewer in a blazer, or the candidate
/// in a plain tee with glasses.
struct FigureLook {
    var skin: Color
    var skinShade: Color
    var hair: Color
    /// The blazer, or the tee.
    var top: Color
    var hasBlazer: Bool
    var hasGlasses: Bool

    static let interviewer = FigureLook(
        skin: Color(rgb: 0xE9B48F), skinShade: Color(rgb: 0xD69E79), hair: Color(rgb: 0x2B201C),
        top: Color(rgb: 0x2D4263), hasBlazer: true, hasGlasses: false
    )
    static let candidate = FigureLook(
        skin: Color(rgb: 0xC98E6B), skinShade: Color(rgb: 0xB07554), hair: Color(rgb: 0x1C1714),
        top: Color(rgb: 0x56664F), hasBlazer: false, hasGlasses: true
    )
}

/// The interviewer, drawn flat: shoulders in a blazer, a face that talks,
/// blinks and nods. The candidate's self view draws the same way in their
/// own look.
private struct InterviewerFigure: View {
    let mood: InterviewerMood
    let t: Double
    var look: FigureLook = .interviewer

    private var skin: Color { look.skin }
    private var skinShade: Color { look.skinShade }
    private var hair: Color { look.hair }
    private var blazer: Color { look.top }

    /// 0 closed, 1 wide: a talking rhythm while asking, a still smile otherwise.
    private var mouthOpen: Double {
        guard mood == .asking else { return 0 }
        return max(0, sin(t * 13) * 0.5 + sin(t * 5.3) * 0.5)
    }

    private var isBlinking: Bool { t.truncatingRemainder(dividingBy: 4.3) < 0.13 }

    var body: some View {
        // Drawn on a 200-point square and scaled to fit.
        GeometryReader { proxy in
            let scale = min(proxy.size.width, proxy.size.height) / 200
            ZStack {
                shoulders
                head
            }
            .frame(width: 200, height: 200)
            .scaleEffect(scale, anchor: .topLeading)
        }
    }

    private var shoulders: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 20, y: 200))
                path.addCurve(to: CGPoint(x: 100, y: 146), control1: CGPoint(x: 22, y: 160), control2: CGPoint(x: 55, y: 146))
                path.addCurve(to: CGPoint(x: 180, y: 200), control1: CGPoint(x: 145, y: 146), control2: CGPoint(x: 178, y: 160))
                path.closeSubpath()
            }
            .fill(blazer)
            if look.hasBlazer {
                // Shirt
                Path { path in
                    path.move(to: CGPoint(x: 84, y: 148))
                    path.addLine(to: CGPoint(x: 100, y: 184))
                    path.addLine(to: CGPoint(x: 116, y: 148))
                    path.closeSubpath()
                }
                .fill(Color(rgb: 0xF4F1EC))
            }
            // Neck
            RoundedRectangle(cornerRadius: 6)
                .fill(skinShade)
                .frame(width: 26, height: 30)
                .position(x: 100, y: 140)
            if !look.hasBlazer {
                // A crew neckline over the neck.
                Path { path in
                    path.move(to: CGPoint(x: 80, y: 147))
                    path.addQuadCurve(to: CGPoint(x: 120, y: 147), control: CGPoint(x: 100, y: 166))
                    path.addLine(to: CGPoint(x: 126, y: 150))
                    path.addLine(to: CGPoint(x: 74, y: 150))
                    path.closeSubpath()
                }
                .fill(blazer)
                Path { path in
                    path.move(to: CGPoint(x: 82, y: 148))
                    path.addQuadCurve(to: CGPoint(x: 118, y: 148), control: CGPoint(x: 100, y: 164))
                }
                .stroke(Color.black.opacity(0.18), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            // Collar points over the blazer.
            ForEach(look.hasBlazer ? [-1.0, 1.0] : [], id: \.self) { side in
                Path { path in
                    path.move(to: CGPoint(x: 100 + side * 13, y: 146))
                    path.addLine(to: CGPoint(x: 100 + side * 2, y: 160))
                    path.addLine(to: CGPoint(x: 100 + side * 20, y: 158))
                    path.closeSubpath()
                }
                .fill(Color(rgb: 0xFFFFFF))
            }
            // Lapels.
            ForEach(look.hasBlazer ? [-1.0, 1.0] : [], id: \.self) { side in
                Path { path in
                    path.move(to: CGPoint(x: 100 + side * 18, y: 150))
                    path.addLine(to: CGPoint(x: 100 + side * 3, y: 184))
                    path.addLine(to: CGPoint(x: 100 + side * 26, y: 166))
                    path.closeSubpath()
                }
                .fill(Color(rgb: 0x243652))
            }
        }
        // Breathing.
        .offset(y: sin(t * 1.4) * 1)
    }

    private var head: some View {
        let nod = mood == .listening ? sin(t * 2.4) * 2.5 : 0
        let bob = sin(t * 1.1) * 1.2
        let lips = Color(rgb: 0xB5604F)
        return ZStack {
            // Ears, with a little depth inside.
            ForEach([69.0, 131.0], id: \.self) { x in
                Ellipse().fill(skinShade).frame(width: 12, height: 18).position(x: x, y: 94)
                Ellipse().fill(skin.opacity(0.6)).frame(width: 6, height: 10).position(x: x + (x < 100 ? 1 : -1), y: 94)
            }
            // Face, lit from the window on the right.
            Ellipse()
                .fill(LinearGradient(colors: [skinShade, skin, skin], startPoint: .leading, endPoint: .trailing))
                .frame(width: 62, height: 74)
                .position(x: 100, y: 92)
            // Shadow under the jaw onto the neck.
            Ellipse().fill(skinShade.opacity(0.35)).frame(width: 26, height: 5).position(x: 100, y: 126)
            // Hair, with a parting and a lighter strand.
            Path { path in
                path.move(to: CGPoint(x: 68, y: 94))
                path.addCurve(to: CGPoint(x: 104, y: 48), control1: CGPoint(x: 62, y: 62), control2: CGPoint(x: 80, y: 46))
                path.addCurve(to: CGPoint(x: 134, y: 94), control1: CGPoint(x: 130, y: 49), control2: CGPoint(x: 140, y: 70))
                path.addCurve(to: CGPoint(x: 112, y: 64), control1: CGPoint(x: 130, y: 78), control2: CGPoint(x: 124, y: 66))
                path.addCurve(to: CGPoint(x: 84, y: 64), control1: CGPoint(x: 102, y: 70), control2: CGPoint(x: 92, y: 62))
                path.addCurve(to: CGPoint(x: 68, y: 94), control1: CGPoint(x: 76, y: 68), control2: CGPoint(x: 70, y: 80))
                path.closeSubpath()
            }
            .fill(hair)
            Path { path in
                path.move(to: CGPoint(x: 90, y: 54))
                path.addQuadCurve(to: CGPoint(x: 120, y: 60), control: CGPoint(x: 106, y: 50))
            }
            .stroke(Color(rgb: 0x4A3A33), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            // Brows, slightly arched.
            ForEach([89.0, 111.0], id: \.self) { x in
                Path { path in
                    path.move(to: CGPoint(x: x - 6, y: 84))
                    path.addQuadCurve(to: CGPoint(x: x + 6, y: 84), control: CGPoint(x: x, y: 80.5))
                }
                .stroke(hair, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            }
            // Eyes: white, iris, pupil and a catch-light; lids close to blink.
            ForEach([89.0, 111.0], id: \.self) { x in
                ZStack {
                    Ellipse().fill(.white).frame(width: 10, height: 7)
                    Circle().fill(Color(rgb: 0x5B3A29)).frame(width: 5.4, height: 5.4)
                    Circle().fill(Color(rgb: 0x1E1512)).frame(width: 2.6, height: 2.6)
                    Circle().fill(.white).frame(width: 1.4, height: 1.4).offset(x: 1, y: -1)
                }
                .scaleEffect(x: 1, y: isBlinking ? 0.12 : 1)
                .position(x: x, y: 93)
            }
            if look.hasGlasses {
                // Thin round frames and a bridge.
                ForEach([89.0, 111.0], id: \.self) { x in
                    Circle()
                        .stroke(Color(rgb: 0x2A2420), lineWidth: 1.6)
                        .frame(width: 17, height: 15)
                        .position(x: x, y: 93)
                }
                Path { path in
                    path.move(to: CGPoint(x: 97.5, y: 92))
                    path.addQuadCurve(to: CGPoint(x: 102.5, y: 92), control: CGPoint(x: 100, y: 90))
                }
                .stroke(Color(rgb: 0x2A2420), lineWidth: 1.4)
            }
            // Cheeks, a touch warm.
            ForEach([84.0, 116.0], id: \.self) { x in
                Ellipse().fill(Color(rgb: 0xE58F7A).opacity(0.25)).frame(width: 10, height: 6).position(x: x, y: 106)
            }
            // Nose, by its shadow.
            Path { path in
                path.move(to: CGPoint(x: 101, y: 95))
                path.addQuadCurve(to: CGPoint(x: 98, y: 106), control: CGPoint(x: 103, y: 103))
                path.addQuadCurve(to: CGPoint(x: 103, y: 106), control: CGPoint(x: 100, y: 108))
            }
            .stroke(skinShade, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            // Mouth: lips at rest, opening as it talks.
            if mouthOpen > 0.05 {
                ZStack {
                    Capsule().fill(lips).frame(width: 16 - mouthOpen * 1.5, height: 3.5 + mouthOpen * 4)
                    Capsule().fill(Color(rgb: 0x5A2420)).frame(width: 11 - mouthOpen * 1.5, height: 1 + mouthOpen * 3)
                }
                .position(x: 100, y: 115 + mouthOpen * 1.5)
            } else {
                Path { path in
                    path.move(to: CGPoint(x: 92, y: 114))
                    path.addQuadCurve(to: CGPoint(x: 108, y: 114), control: CGPoint(x: 100, y: 119))
                }
                .stroke(lips, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            }
        }
        .rotationEffect(.degrees(sin(t * 0.8) * 1.5), anchor: UnitPoint(x: 0.5, y: 0.7))
        .offset(y: bob + nod)
    }
}

private extension Color {
    init(rgb: UInt) {
        self.init(red: Double((rgb >> 16) & 0xFF) / 255, green: Double((rgb >> 8) & 0xFF) / 255, blue: Double(rgb & 0xFF) / 255)
    }
}

// MARK: - The question, as it's spoken

/// Marks each word so the renderer can treat it on its own.
private struct WordIndex: TextAttribute {
    let index: Int
}

/// Live captions: the whole question shows faintly, and each word lights
/// up and lifts as it's said, settling once the next one starts.
private struct SpokenWordRenderer: TextRenderer, Animatable {
    var progress: Double
    let wordCount: Int

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let spoken = progress * Double(wordCount)
        for line in layout {
            for run in line {
                let index = Double(run[WordIndex.self]?.index ?? 0)
                // 0 not yet said, 1 said; in between while it's being said.
                let local = min(max(spoken - index, 0), 1)
                let isBeingSaid = local > 0 && local < 1
                var copy = context
                copy.opacity = 0.22 + 0.78 * local
                if isBeingSaid {
                    copy.translateBy(x: 0, y: -2 * sin(local * .pi))
                }
                copy.draw(run)
            }
        }
    }
}

/// A question that's said word by word, in step with the interviewer.
/// Calls `onFinished` once it's all been said.
struct RevealingQuestion: View {
    let text: String
    var font: Font = .questionLarge
    /// Seconds per word, near a natural speaking pace.
    var pace: Double = 0.26
    /// Change it to say the question again.
    var replay: Int = 0
    var onFinished: () -> Void = {}

    @State private var progress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var words: [String] { text.split(separator: " ").map(String.init) }

    var body: some View {
        let words = words
        words.enumerated().reduce(Text("")) { result, item in
            result + Text(item.element + (item.offset < words.count - 1 ? " " : "")).customAttribute(WordIndex(index: item.offset))
        }
        .font(font)
        .textRenderer(SpokenWordRenderer(progress: progress, wordCount: words.count))
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel(text)
        .task(id: "\(text)#\(replay)") {
            progress = 0
            guard !reduceMotion else {
                progress = 1
                onFinished()
                return
            }
            try? await Task.sleep(for: .seconds(0.35))
            let duration = Double(words.count) * pace
            withAnimation(.linear(duration: duration)) { progress = 1 }
            try? await Task.sleep(for: .seconds(duration + 0.4))
            onFinished()
        }
    }
}

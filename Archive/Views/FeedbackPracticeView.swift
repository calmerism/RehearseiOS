import SwiftUI

struct FeedbackView: View {
    let feedback: Feedback
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedArea: ImprovementArea?

    var body: some View {
        AppScreen {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 27) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Your Rehearsal")
                            .font(.largeTitle.weight(.bold))
                        Text("A readiness indicator based on this rehearsal — not a hiring prediction.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    readinessReport
                    strengthsSection
                    improvementSection
                    detailedScores

                    SecondaryButton(title: "Done") {
                        appState.selectedTab = .home
                        dismiss()
                    }
                }
                .padding(20)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedArea) { area in
            TargetedPracticeIntroView(area: area)
        }
    }

    private var readinessReport: some View {
        GroupedSurface(style: .elevated) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 18) {
                    ReadinessScoreRing(score: feedback.readiness, size: 74, strokeWidth: 7)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Interview Readiness")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                        MetricPill(
                            icon: feedback.readiness >= 75 ? "checkmark.circle.fill" : "arrow.up.right",
                            text: feedback.readiness >= 75 ? "Target Ready" : "Building Momentum",
                            tint: feedback.readiness >= 75 ? AppTheme.success : AppTheme.brand
                        )
                        Text("Based on this rehearsal session.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer(minLength: 0)
                }

                Divider().overlay(AppTheme.border)

                Text(feedback.summary)
                    .font(.subheadline)
                    .lineSpacing(3)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Interview readiness \(feedback.readiness) percent. \(feedback.summary)")
    }

    private var strengthsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Your Strengths")
            GroupedSurface(style: .standard) {
                ForEach(Array(feedback.strengths.enumerated()), id: \.offset) { index, strength in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.success)
                        Text(strength)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.text)
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    if index < feedback.strengths.count - 1 {
                        Divider().overlay(AppTheme.border).padding(.leading, 48)
                    }
                }
            }
        }
    }

    private var improvementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recommended Focus")
            GroupedSurface(style: .standard) {
                ForEach(Array(feedback.improvements.enumerated()), id: \.element.id) { index, area in
                    FeedbackFocusRow(area: area) {
                        AppTheme.Haptics.selection()
                        selectedArea = area
                    }
                    if index < feedback.improvements.count - 1 {
                        Divider().overlay(AppTheme.border).padding(.leading, 18)
                    }
                }
            }
        }
    }

    private var detailedScores: some View {
        GroupedSurface(style: .subtle) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Competency Breakdown")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)

                HStack(spacing: 0) {
                    FeedbackMetric(value: feedback.communication, title: "Communication", icon: "waveform")
                    Divider().frame(height: 38).overlay(AppTheme.border)
                    FeedbackMetric(value: feedback.answerQuality, title: "Answer Structure", icon: "sparkles")
                }
            }
            .padding(16)
        }
    }
}

private struct FeedbackMetric: View {
    let value: Int
    let title: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.brand)
                Text("\(value)%")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppTheme.text)
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value) percent")
    }
}

private struct FeedbackFocusRow: View {
    let area: ImprovementArea
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(area.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                    Spacer()
                    MetricPill(icon: "target", text: "Goal: \(area.goal)%", tint: AppTheme.brand)
                }

                Text(area.summary)
                    .font(.subheadline)
                    .lineSpacing(2)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(area.advice)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)

                HStack(spacing: 4) {
                    Text("Rehearse this focus area")
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.brand)
                .padding(.top, 4)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Starts focused practice for \(area.title)")
    }
}

struct TargetedPracticeIntroView: View {
    let area: ImprovementArea
    @State private var showPractice = false

    var body: some View {
        AppScreen {
            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 16)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Targeted Practice")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.brand)
                    Text("Focus: \(area.title)")
                        .font(.largeTitle.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("A targeted rehearsal sequence to build confidence in this key area.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                GroupedSurface(style: .elevated) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center, spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Baseline")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppTheme.secondaryText)
                                Text("\(area.score)%")
                                    .font(.title.weight(.bold).monospacedDigit())
                                    .foregroundStyle(AppTheme.text)
                            }
                            Image(systemName: "arrow.right")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.success)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Session Goal")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppTheme.secondaryText)
                                Text("\(area.goal)%")
                                    .font(.title.weight(.bold).monospacedDigit())
                                    .foregroundStyle(AppTheme.success)
                            }
                            Spacer()
                            MetricPill(
                                icon: "arrow.up.right",
                                text: "+\(area.goal - area.score) pts",
                                tint: AppTheme.success
                            )
                        }

                        Divider().overlay(AppTheme.border)

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Strategy")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.secondaryText)
                            Text(area.advice)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(18)
                }

                Spacer()

                PrimaryButton(title: "Start Targeted Rehearsal", icon: "mic.fill") {
                    showPractice = true
                }
            }
            .padding(20)
            .padding(.bottom, 12)
        }
        .navigationDestination(isPresented: $showPractice) {
            TargetedRehearsalView(area: area)
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct TargetedRehearsalView: View {
    let area: ImprovementArea
    @State private var micState: MicrophoneButton.State = .idle
    @State private var showResult = false

    var body: some View {
        AppScreen {
            VStack(spacing: 0) {
                HStack {
                    Text("Targeted Practice")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.brand)
                    Spacer()
                    MetricPill(text: area.title, tint: AppTheme.secondaryText)
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)

                Spacer()

                VStack(alignment: .leading, spacing: 16) {
                    GroupedSurface(style: .elevated) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "waveform")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.brand)
                                Text("Prompt")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }

                            Text("Walk me through how you would design a URL shortener.")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AppTheme.text)
                                .fixedSize(horizontal: false, vertical: true)

                            Divider().overlay(AppTheme.border)

                            Text("Start with your high-level approach, then explain the technical details.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(20)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                VStack(spacing: 20) {
                    if micState == .listening {
                        WaveformView(isAnimating: true)
                            .frame(height: 38)
                            .padding(.horizontal, 40)
                            .transition(.opacity)
                    }

                    Text(micState == .listening ? "Listening... Speak your answer aloud." : micState == .reviewing ? "Analyzing response..." : "Tap microphone to begin speaking.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(micState == .listening ? AppTheme.brand : AppTheme.secondaryText)
                        .animation(AppTheme.Motion.standard, value: micState)

                    MicrophoneButton(state: micState, action: toggleMic)
                }
                .padding(.bottom, 32)
            }
        }
        .navigationDestination(isPresented: $showResult) {
            TargetedPracticeResultView(area: area)
                .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func toggleMic() {
        switch micState {
        case .idle:
            withAnimation(AppTheme.Motion.standard) { micState = .listening }
        case .listening:
            withAnimation(AppTheme.Motion.standard) { micState = .reviewing }
            Task {
                try? await Task.sleep(nanoseconds: 950_000_000)
                guard !Task.isCancelled else { return }
                showResult = true
            }
        case .reviewing:
            break
        }
    }
}

struct TargetedPracticeResultView: View {
    let area: ImprovementArea
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var animateScore = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        AppScreen {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.successTint)
                            .frame(width: 80, height: 80)
                        Image(systemName: "checkmark")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(AppTheme.success)
                    }
                    .accessibilityHidden(true)

                    VStack(spacing: 8) {
                        Text("Nice improvement.")
                            .font(.largeTitle.weight(.bold))
                        Text(area.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    GroupedSurface(style: .elevated) {
                        VStack(spacing: 16) {
                            HStack(alignment: .center, spacing: 18) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Previous")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(AppTheme.secondaryText)
                                    Text("\(area.score)%")
                                        .font(.title2.weight(.bold).monospacedDigit())
                                        .foregroundStyle(AppTheme.secondaryText)
                                }

                                Image(systemName: "arrow.right")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(AppTheme.success)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("New Score")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(AppTheme.secondaryText)
                                    Text("\(animateScore ? area.goal : area.score)%")
                                        .font(.title.weight(.bold).monospacedDigit())
                                        .foregroundStyle(AppTheme.success)
                                        .contentTransition(.numericText())
                                }

                                Spacer()

                                MetricPill(
                                    icon: "arrow.up.right",
                                    text: "+\(area.goal - area.score) pts",
                                    tint: AppTheme.success
                                )
                            }

                            Divider().overlay(AppTheme.border)

                            Text("Your answer was significantly more structured and easier to follow.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(18)
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()

                VStack(spacing: 12) {
                    PrimaryButton(title: "Rehearse Again", icon: "arrow.right") {
                        appState.selectedTab = .rehearse
                        dismiss()
                    }
                    SecondaryButton(title: "Back to Progress") {
                        appState.selectedTab = .progress
                        dismiss()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            if reduceMotion {
                animateScore = true
            } else {
                withAnimation(.spring(duration: 0.65, bounce: 0.18).delay(0.15)) {
                    animateScore = true
                }
            }
            AppTheme.Haptics.success()
        }
        .sensoryFeedback(.success, trigger: animateScore)
    }
}

#Preview("Feedback") {
    NavigationStack { FeedbackView(feedback: MockData.feedback) }
        .environment(AppState.preview)
}

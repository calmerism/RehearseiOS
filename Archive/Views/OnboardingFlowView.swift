import SwiftUI

struct OnboardingFlowView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stage: Stage = .welcome

    private enum Stage: Equatable { case welcome, date }

    var body: some View {
        AppScreen {
            VStack(spacing: 0) {
                Spacer(minLength: 28)

                switch stage {
                case .welcome:
                    WelcomeView {
                        move(to: .date)
                    }
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                case .date:
                    InterviewDateView(
                        initialDate: appState.interviewDate,
                        onContinue: { date in
                            appState.setInterviewDate(date)
                            appState.finishOnboarding()
                        },
                        onBack: {
                            move(to: .welcome)
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 24)
        }
    }

    private func move(to destination: Stage) {
        if reduceMotion {
            stage = destination
        } else {
            withAnimation(.snappy(duration: 0.38)) { stage = destination }
        }
    }
}

private struct WelcomeView: View {
    let onContinue: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var markIsVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.brandTint)
                            .frame(width: 44, height: 44)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(AppTheme.brand.opacity(0.18), lineWidth: 1)
                            }
                        Image(systemName: "waveform")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.brand)
                    }

                    Text("Rehearse")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                }
                .opacity(markIsVisible ? 1 : 0)
                .offset(y: markIsVisible ? 0 : 8)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Ready for your\nnext interview?")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Rehearse the interview before the real one.")
                        .font(.title3)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("Practice realistic prompts aloud. Learn what to improve before it matters.")
                    .font(.subheadline)
                    .lineSpacing(3)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            PrimaryButton(title: "Get Started", icon: "arrow.right") {
                AppTheme.Haptics.medium()
                onContinue()
            }
            .padding(.bottom, 12)
        }
        .accessibilityElement(children: .contain)
        .onAppear {
            if reduceMotion {
                markIsVisible = true
            } else {
                withAnimation(.snappy(duration: 0.5, extraBounce: 0.08)) {
                    markIsVisible = true
                }
            }
        }
    }
}

private struct InterviewDateView: View {
    let initialDate: Date
    let onContinue: (Date) -> Void
    let onBack: () -> Void
    @State private var date: Date

    init(initialDate: Date, onContinue: @escaping (Date) -> Void, onBack: @escaping () -> Void) {
        self.initialDate = initialDate
        self.onContinue = onContinue
        self.onBack = onBack
        _date = State(initialValue: initialDate)
    }

    private var daysToGo: Int {
        max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: date)).day ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Button(action: {
                AppTheme.Haptics.light()
                onBack()
            }) {
                Label("Back", systemImage: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(minHeight: AppTheme.Size.minimumTapTarget)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("When’s your\ninterview?")
                    .font(.largeTitle.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("We’ll tailor your practice timeline and milestones to the time you have.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            GroupedSurface(style: .elevated) {
                VStack(alignment: .leading, spacing: 14) {
                    DatePicker(
                        "Interview date",
                        selection: $date,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(AppTheme.brand)
                    .onChange(of: date) {
                        AppTheme.Haptics.selection()
                    }

                    Divider().overlay(AppTheme.border)

                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppTheme.brand)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(date.formatted(.dateTime.month(.wide).day().year()))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.text)
                            Text(daysToGo == 0 ? "Scheduled for today" : "\(daysToGo) days remaining to prepare")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                        }

                        Spacer()

                        MetricPill(
                            icon: "clock",
                            text: daysToGo == 0 ? "Today" : "\(daysToGo)d",
                            tint: daysToGo <= 3 ? AppTheme.brand : AppTheme.success
                        )
                    }
                }
                .padding(18)
            }

            Spacer()

            PrimaryButton(title: "Continue", icon: "arrow.right") {
                AppTheme.Haptics.medium()
                onContinue(date)
            }
        }
        .padding(.bottom, 12)
    }
}

#Preview("Onboarding") {
    OnboardingFlowView()
        .environment(AppState.preview)
}

import SwiftUI

/// What every score is based on, in one place: what each band means, what
/// the app listens to, how each of the six areas is marked, and what is and
/// isn't kept. Opened from the info button beside the score and its Overall
/// row, so the answer to "how is this scored?" is always one tap away.
struct ScoringInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                VStack(spacing: AppTheme.Spacing.xs) {
                    Text("Six areas, each out of 100")
                        .font(.title3.bold())
                    Text("Your score is their average.")
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.xs)
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(Feedback.Band.allCases, id: \.self) { band in
                    LabeledContent(band.title, value: "\(band.range.lowerBound)–\(band.range.upperBound)")
                }
            } header: {
                Text("What Your Score Means")
                    .listHeadingInset()
            } footer: {
                Text("Ending early takes 3 off for each question skipped.")
            }

            Section {
                source("Your Words", detail: "What you said, from the transcript", systemImage: "text.bubble.fill")
                source("Your Voice", detail: Scoring.flagsFillerWords ? "Pace, pauses and filler words" : "Pace and pauses", systemImage: "waveform")
            } header: {
                Text("What It’s Based On")
                    .listHeadingInset()
            }

            Section {
                ForEach(ScoreArea.allCases) { area in
                    LabeledContent {
                        Text(area.isMeasured ? "Measured" : "Judged")
                    } label: {
                        Label(area.title, systemImage: area.symbol)
                    }
                }
            } header: {
                Text("The Six Areas")
                    .listHeadingInset()
            } footer: {
                Text("Measured areas follow set rules from how you spoke, so the same answer always gets the same score. Judged areas are estimated from what you said.")
            }

            Section {
                source("On Your iPhone", detail: "Your speech is turned into text on your iPhone where it’s supported", systemImage: "iphone")
                source("What’s Kept", detail: "The text of your answers and your scores", systemImage: "tray.full.fill")
            } header: {
                Text("Your Privacy")
                    .listHeadingInset()
            } footer: {
                Text("No audio or video is recorded. The camera isn’t used.")
            }
        }
        .appListStyle()
        .navigationTitle("How Scoring Works")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func source(_ title: String, detail: String, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack { ScoringInfoView() }
}

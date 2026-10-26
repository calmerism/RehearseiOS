import SwiftUI

/// What every score is based on, in one place: what the app listens to, how
/// each of the six areas is marked, and what runs on the phone and what in
/// the cloud. Opened from Your Score's toolbar and its Overall row, so the
/// answer to "how is this scored?" is always one tap away.
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
                source("Your Words", detail: "What you said, from the transcript", systemImage: "text.bubble.fill")
                source("Your Voice", detail: Scoring.flagsFillerWords ? "Pace, pauses and filler words" : "Pace and pauses", systemImage: "waveform")
                source("Your Camera", detail: "Where you look while you answer", systemImage: "video.fill")
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
                Text("Judged areas are marked by AI against a fixed checklist. Measured areas follow set rules, so the same answer always gets the same score.")
            }

            Section {
                source("On Your iPhone", detail: "Camera, voice and the transcript", systemImage: "iphone")
                source("Rehearse Cloud", detail: "Judging answers and writing resumes", systemImage: "cloud.fill")
            } header: {
                Text("Where It Runs")
                    .listHeadingInset()
            } footer: {
                Text("Your video never leaves your phone. Ending early takes 3 off for each question skipped.")
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

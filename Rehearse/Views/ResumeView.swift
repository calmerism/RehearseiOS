import SwiftUI

/// Adds the resume that personalizes questions, and shows what was understood
/// from it so the candidate can trust (or fix) what they'll be asked about.
/// File picking and parsing are mocked.
struct ResumeView: View {
    @Environment(AppState.self) private var appState
    @State private var isChoosingFile = false
    @State private var isConfirmingRemoval = false

    var body: some View {
        List {
            switch appState.resume {
            case .none:
                emptyState
            case .parsing(let fileName):
                Section {
                    HStack(spacing: AppTheme.Spacing.sm) {
                        ProgressView()
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                            Text("Reading \(fileName)…")
                            Text("Looking for the projects and jobs you might get asked about.")
                                .font(.app(.footnote))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, AppTheme.Spacing.xs)
                }
            case .ready(let context):
                understood(context)
            case .failed(let fileName, let reason):
                Section {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Label("Couldn’t read \(fileName)", systemImage: "exclamationmark.triangle.fill")
                            .font(.app(.headline))
                        Text(reason)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, AppTheme.Spacing.xxs)
                    Button("Choose Another File") { isChoosingFile = true }
                }
            }
        }
        .contentMargins(.top, AppTheme.Spacing.sm, for: .scrollContent)
        .warmBackground()
        .navigationTitle("Resume")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Choose a file", isPresented: $isChoosingFile, titleVisibility: .visible) {
            // Stands in for the system document picker.
            Button(MockData.resumeFileName) { upload(MockData.resumeFileName) }
            Button(MockData.unreadableResumeFileName) { upload(MockData.unreadableResumeFileName) }
        } message: {
            Text("PDF or Word document")
        }
        .confirmationDialog("Remove your resume?", isPresented: $isConfirmingRemoval, titleVisibility: .visible) {
            Button("Remove Resume", role: .destructive) { appState.removeResume() }
        } message: {
            Text("Without it, you’ll get general questions.")
        }
    }

    private var emptyState: some View {
        Section {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                IconTile(systemImage: "doc.text", size: 44)
                Text("Get asked about your own work")
                    .font(.app(.title3, weight: .semibold))
                Text("You’ll get asked about the projects and jobs on your resume, just like a real interview. Your file stays on your phone.")
                    .foregroundStyle(.secondary)
                PrimaryButton(title: "Choose File", systemImage: "doc.badge.plus") {
                    isChoosingFile = true
                }
                .padding(.top, AppTheme.Spacing.xs)
            }
            .padding(.vertical, AppTheme.Spacing.xs)
        }
    }

    @ViewBuilder
    private func understood(_ context: ResumeContext) -> some View {
        Section {
            ForEach(context.highlights) { highlight in
                HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                    IconTile(systemImage: "doc.text")
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                        Text(highlight.title)
                            .font(.app(.headline))
                        Text(highlight.source)
                            .font(.app(.subheadline))
                            .foregroundStyle(.secondary)
                        Text(highlight.detail)
                            .font(.app(.footnote))
                    }
                }
                .padding(.vertical, AppTheme.Spacing.xxs)
                .accessibilityElement(children: .combine)
            }
        } header: {
            Group {
                Text("You’ll Be Asked About")
            }
            .font(.app(.footnote, weight: .semibold))
        } footer: {
            Group {
                Text("Skills: " + context.skills.joined(separator: ", "))
            }
            .font(.app(.footnote))
        }

        Section {
            LabeledContent("File", value: context.fileName)
            Button("Replace File") { isChoosingFile = true }
            Button("Remove Resume", role: .destructive) { isConfirmingRemoval = true }
        }
    }

    private func upload(_ fileName: String) {
        Task { await appState.uploadResume(named: fileName) }
    }
}

#Preview {
    NavigationStack { ResumeView() }
        .environment(AppState())
}

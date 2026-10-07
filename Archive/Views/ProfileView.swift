import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var notificationsEnabled = true
    @State private var showResetConfirmation = false

    var body: some View {
        NavigationStack {
            AppScreen {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Alex")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(AppTheme.text)
                            Text("3rd Year · Computer Science")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .padding(.vertical, 7)
                        .listRowBackground(Color.clear)
                    }

                    Section("Interview Preferences") {
                        LabeledContent("Default interview") {
                            Text("Technical")
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        LabeledContent("Default duration") {
                            Text("20 min")
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }

                    Section {
                        LabeledContent("Appearance") {
                            Text("System")
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    } header: {
                        Text("Appearance")
                    } footer: {
                        Text("Rehearse follows your device’s light or dark appearance.")
                    }

                    Section {
                        Toggle(isOn: $notificationsEnabled) {
                            Label("Notifications", systemImage: "bell")
                        }
                        .tint(AppTheme.brand)

                        Label("Privacy", systemImage: "hand.raised")
                        Label("Help", systemImage: "questionmark.circle")
                    }

                    Section {
                        Button("Reset prototype", role: .destructive) {
                            showResetConfirmation = true
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.brand)
                }
            }
            .confirmationDialog("Reset the prototype?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
                Button("Reset", role: .destructive) {
                    appState.resetPrototype()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This returns onboarding and mock data to their starting state.")
            }
        }
    }
}

#Preview("Profile") {
    ProfileView()
        .environment(AppState.preview)
}


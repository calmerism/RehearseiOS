import SwiftUI

/// Adds one of the candidate's real upcoming interviews, or reschedules one.
/// Only the facts that change the rehearsal are asked for; experience level
/// comes from the candidate, and rehearsal length is chosen at setup. Once
/// added, an interview's company, role, type and time are fixed, since
/// rehearsals already done were for that interview, so only its date can
/// change.
struct UpcomingInterviewEditor: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Interview
    @State private var isConfirmingRemoval = false
    private let isNew: Bool

    init(interview: Interview? = nil) {
        isNew = interview == nil
        _draft = State(initialValue: interview ?? Interview(
            role: "",
            company: nil,
            experienceLevel: MockData.candidateExperienceLevel,
            type: .technical,
            date: Calendar.current.date(byAdding: .day, value: 7, to: .now)
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                if isNew {
                    Section {
                        LabeledTextField(title: "Company", text: company, prompt: "Required", contentType: .organizationName)
                        LabeledTextField(title: "Role", text: $draft.role, prompt: "Required", contentType: .jobTitle)
                    }

                    Section {
                        Picker("Interview Type", selection: $draft.type) {
                            ForEach(InterviewType.allCases) { Text($0.rawValue).tag($0) }
                        }
                    }
                } else {
                    Section {
                        LabeledContent("Company", value: draft.company ?? "")
                        LabeledContent("Role", value: draft.role)
                        LabeledContent("Interview Type", value: draft.type.rawValue)
                    } footer: {
                        Text("To change these, remove the interview and add it again.")
                    }
                }

                Section {
                    DatePicker("Date", selection: day, in: Calendar.current.startOfDay(for: .now)..., displayedComponents: .date)
                    if isNew {
                        DatePicker("Time", selection: date, displayedComponents: .hourAndMinute)
                    } else {
                        // Set when it was added, and locked after that.
                        LabeledContent("Time") {
                            Label(draft.date?.formatted(date: .omitted, time: .shortened) ?? "", systemImage: "lock.fill")
                                .labelStyle(TrailingIconLabelStyle())
                        }
                    }
                }

                if !isNew {
                    Section {
                        Button("Remove Interview", role: .destructive) {
                            isConfirmingRemoval = true
                        }
                    } footer: {
                        Text("Your past rehearsals stay in History.")
                    }
                }
            }
            .appListStyle()
            .navigationTitle(isNew ? "Add Interview" : "Edit Interview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save") {
                        appState.saveUpcomingInterview(draft)
                        dismiss()
                    }
                    .disabled(draft.company == nil || draft.role.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Remove this interview?", isPresented: $isConfirmingRemoval, titleVisibility: .visible) {
                Button("Remove Interview", role: .destructive) {
                    appState.removeUpcomingInterview(id: draft.id)
                    dismiss()
                }
            }
        }
    }

    /// A blank company is stored as `nil`, which keeps Save disabled, as does a blank role.
    private var company: Binding<String> {
        Binding(
            get: { draft.company ?? "" },
            set: {
                let trimmed = $0.trimmingCharacters(in: .whitespaces)
                draft.company = trimmed.isEmpty ? nil : $0
            }
        )
    }

    private var date: Binding<Date> {
        Binding(get: { draft.date ?? .now }, set: { draft.date = $0 })
    }

    /// A new day keeps the interview's time.
    private var day: Binding<Date> {
        Binding(
            get: { draft.date ?? .now },
            set: { newDay in
                let calendar = Calendar.current
                let time = calendar.dateComponents([.hour, .minute], from: draft.date ?? .now)
                draft.date = calendar.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0, second: 0, of: newDay) ?? newDay
            }
        )
    }
}

/// The text, then a small gray symbol after it.
private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.title
            configuration.icon
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview("Add") {
    UpcomingInterviewEditor()
        .environment(AppState(scenario: .newUser))
}

#Preview("Edit") {
    UpcomingInterviewEditor(interview: MockData.upcomingInterview)
        .environment(AppState())
}

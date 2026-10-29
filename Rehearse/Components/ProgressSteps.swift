import SwiftUI

/// Work that takes a moment, shown as the steps it goes through, each ticked
/// off as it's done, so the wait says what's happening: reading a resume,
/// or writing one.
struct ProgressSteps: View {
    let steps: [String]
    /// Seconds each step takes.
    var pace: Double = 0.7
    @State private var done = 0

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            ForEach(steps.indices, id: \.self) { index in
                HStack(spacing: AppTheme.Spacing.sm) {
                    ZStack {
                        if index < done {
                            DoneMark()
                                .transition(.scale.combined(with: .opacity))
                        } else if index == done {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "circle")
                                .font(.title3)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(width: 28, height: 28)
                    Text(steps[index])
                        .foregroundStyle(index <= done ? Color.primary : Color.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue(index < done ? "Done" : index == done ? "In progress" : "Waiting")
            }
        }
        .padding(.vertical, AppTheme.Spacing.xxs)
        .task {
            for step in 1...max(steps.count, 1) {
                try? await Task.sleep(for: .seconds(pace))
                withAnimation(.snappy(duration: 0.3)) { done = step }
            }
        }
    }
}

#Preview {
    List {
        ProgressSteps(steps: ["Reading the text", "Finding your projects", "Choosing your questions"])
    }
}

import SwiftUI

/// One answer, reviewed: the question and its score out of 100, the five
/// areas that score is the average of, the answer itself with the part that went
/// wrong marked, how a stronger answer would open, and a way into a chat
/// with Rehearse about it. Opened from a question in Your Score.
struct AnswerReviewView: View {
    let number: Int
    let entry: TranscriptEntry
    /// The interview's focus, for a follow-up or a strong answer to point at.
    let focus: Skill
    /// This answer scored on the five areas.
    let areas: [AreaScore]

    @Environment(\.dismiss) private var dismiss
    @State private var openArea: AreaScore?
    /// Kept here, so going back to the answer and into the chat again
    /// keeps the conversation.
    @State private var chatMessages: [ChatMessage] = []

    private var score: Int? { areas.isEmpty ? nil : Scoring.overall(areas) }

    private var skill: Skill { entry.weakSkill ?? focus }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                header
                areasCard
                answerCard
                if !entry.hindiLines.isEmpty {
                    englishCard
                }
                if entry.weakSkill != nil {
                    betterCard
                }
                chatLink
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            // Exactly the page's width, so it never drifts sideways.
            .containerRelativeFrame(.horizontal)
        }
        .scrollDismissesKeyboard(.interactively)
        .debugScrollAnchor()
        .groupedBackground()
        .navigationTitle(entry.isFollowUp ? "Follow-up" : "Question \(number)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    // MARK: - Chat

    /// Opens the chat on its own screen, pushed like any other page.
    private var chatLink: some View {
        NavigationLink {
            AnswerChatView(entry: entry, skill: skill, messages: $chatMessages)
        } label: {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.brand)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask Rehearse")
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    Text(chatMessages.isEmpty ? "Questions about this answer" : "\(chatMessages.filter(\.fromUser).count) asked so far")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(AppTheme.Spacing.md)
            .cardBackground()
        }
        .buttonStyle(CardButtonStyle())
        .accessibilityHint("Opens a chat about this answer")
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.md) {
            // The verdict leads the question on its first line, as in the
            // Review Your Answers list.
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Spacing.xs) {
                verdict
                Text(entry.question)
                    .font(.questionInCard)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let score {
                ScoreRing(score: score, caption: "out of 100", size: 84)
            }
        }
        .padding(AppTheme.Spacing.md)
        .cardBackground()
    }

    // MARK: - What the score came from

    /// This answer on the five areas, and their average. Tap an area for
    /// the parts it's worked out from.
    @ViewBuilder
    private var areasCard: some View {
        if !areas.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(areas.enumerated()), id: \.element.id) { index, area in
                    if index > 0 { Divider().padding(.leading, 52) }
                    Button {
                        openArea = area
                    } label: {
                        AreaRow(area: area)
                    }
                    .buttonStyle(CardRowButtonStyle())
                }
                Divider()
                HStack(alignment: .firstTextBaseline) {
                    Text("Average of the six")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(score ?? 0) / 100")
                        .font(.headline.monospacedDigit())
                }
                .padding(AppTheme.Spacing.md)
            }
            .cardBackground()
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous))
            .sheet(item: $openArea) { area in
                NavigationStack {
                    AreaDetailView(area: area)
                }
                .presentationDetents([.large])
                .presentationBackground(AppTheme.background)
            }
        }
    }

    /// The tick, exclamation mark or cross alone, no words.
    @ViewBuilder
    private var verdict: some View {
        if let score {
            VerdictIcon(score: score)
                .font(.body)
        }
    }

    // MARK: - The answer

    /// The answer as it was heard. No recording is kept, only the text. Lines said in Hindi are marked, with their English in
    /// the card below; otherwise the part that went wrong is marked.
    private var answerCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Your Answer")
                .font(.label)
                .foregroundStyle(.secondary)
            Text(entry.hindiLines.isEmpty ? markedAnswer : saidAnswer)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    /// What was said, with each line said in Hindi marked, so it's clear
    /// which part the English below is for.
    private var saidAnswer: AttributedString {
        var text = AttributedString(entry.spokenAnswer ?? entry.answer)
        for line in entry.hindiLines {
            if let range = text.range(of: line.said) {
                text[range].backgroundColor = AppTheme.graphic.opacity(0.18)
                text[range].foregroundColor = AppTheme.brand
            }
        }
        return text
    }

    /// Each Hindi line, and how to say it in English: what was meant, in
    /// the words to use next time.
    private var englishCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Say It in English")
                .font(.label)
                .foregroundStyle(.secondary)
            ForEach(entry.hindiLines, id: \.self) { line in
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xxs) {
                    Text(line.said)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(line.english)
                        .font(.body.weight(.semibold))
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }

    /// The answer, with its opening sentence marked when the answer fell
    /// short: that's where the point should have been.
    private var markedAnswer: AttributedString {
        var text = AttributedString(entry.answer)
        guard entry.weakSkill != nil,
              let end = entry.answer.firstIndex(where: { ".!?".contains($0) }) else { return text }
        let firstSentence = String(entry.answer[...end])
        if let range = text.range(of: firstSentence) {
            text[range].backgroundColor = AppTheme.graphic.opacity(0.18)
            text[range].foregroundColor = AppTheme.brand
        }
        return text
    }

    // MARK: - A stronger answer

    private var betterCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Try It Like This")
                .font(.label)
                .foregroundStyle(.secondary)
            Text(skill.exampleOpening)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}

// MARK: - Chat screen

struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let fromUser: Bool
    let text: String
}

/// A chat with Rehearse about one answer, on its own screen: the
/// conversation scrolls, suggested questions sit under it, and the field to
/// type in is pinned above the keyboard, as Messages does. Every reply is
/// predefined in this prototype.
struct AnswerChatView: View {
    let entry: TranscriptEntry
    let skill: Skill
    @Binding var messages: [ChatMessage]

    @State private var draft = ""
    @State private var isTyping = false
    @FocusState private var isFocused: Bool

    private var suggestions: [String] {
        let asked = Set(messages.filter(\.fromUser).map(\.text))
        let all = entry.weakSkill != nil
            ? ["Why was this marked down?", "Show me a better answer", "How do I practice this?"]
            : ["What made this answer strong?", "How could it be even better?"]
        return all.filter { !asked.contains($0) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    // What the chat is about, so it reads on its own.
                    Text(entry.question)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, AppTheme.Spacing.xs)
                    bubble(ChatMessage(fromUser: false, text: "Ask me anything about this answer."))
                    ForEach(messages) { message in
                        bubble(message)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if isTyping {
                        bubble(ChatMessage(fromUser: false, text: "…"))
                            .transition(.opacity)
                    }
                    if !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button(suggestion) { send(suggestion) }
                                    .font(.subheadline.weight(.medium))
                                    .buttonStyle(.bordered)
                                    .buttonBorderShape(.capsule)
                                    .tint(AppTheme.brand)
                                    .disabled(isTyping)
                            }
                        }
                        .padding(.top, AppTheme.Spacing.xs)
                    }
                    Color.clear.frame(height: 1).id("end")
                }
                .padding(AppTheme.Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages) {
                withAnimation { proxy.scrollTo("end", anchor: .bottom) }
            }
        }
        .groupedBackground()
        .navigationTitle("Ask Rehearse")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaBar(edge: .bottom) {
            HStack(spacing: AppTheme.Spacing.xs) {
                TextField("Ask about this answer", text: $draft, prompt: .prompt("Ask about this answer"))
                    .focused($isFocused)
                    .submitLabel(.send)
                    .onSubmit { send(draft) }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .frame(minHeight: 44)
                    .glassEffect(.regular, in: Capsule())
                Button {
                    send(draft)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(draft.trimmingCharacters(in: .whitespaces).isEmpty ? Color(.tertiaryLabel) : AppTheme.brand)
                }
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || isTyping)
                .accessibilityLabel("Send")
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.xs)
        }
        .animation(.smooth(duration: 0.3), value: messages)
        .animation(.smooth(duration: 0.2), value: isTyping)
        #if DEBUG
        .task {
            // `-chat` asks the first suggestion, for screenshots.
            guard ProcessInfo.processInfo.arguments.contains("-chat"), messages.isEmpty else { return }
            try? await Task.sleep(for: .seconds(1))
            if let first = suggestions.first { send(first) }
        }
        #endif
    }

    private func bubble(_ message: ChatMessage) -> some View {
        HStack(alignment: .bottom, spacing: AppTheme.Spacing.xs) {
            if message.fromUser { Spacer(minLength: 48) }
            if !message.fromUser {
                // Rehearse speaks as its app icon, as a contact's picture.
                AppLogo(size: 28)
            }
            Text(message.text)
                .font(.body)
                .foregroundStyle(message.fromUser ? Color.white : Color.primary)
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(message.fromUser ? AppTheme.buttonFill : AppTheme.cardFill,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .fixedSize(horizontal: false, vertical: true)
            if !message.fromUser { Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity, alignment: message.fromUser ? .trailing : .leading)
    }

    private func send(_ text: String) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isTyping else { return }
        messages.append(ChatMessage(fromUser: true, text: question))
        draft = ""
        isTyping = true
        Task {
            try? await Task.sleep(for: .seconds(0.9))
            isTyping = false
            messages.append(ChatMessage(fromUser: false, text: reply(to: question)))
        }
    }

    private func reply(to question: String) -> String {
        switch question {
        case "Why was this marked down?":
            return entry.moment?.note ?? "The point came late, so the details were hard to place."
        case "Show me a better answer":
            return "Open like this: \(skill.exampleOpening) Then give the details."
        case "How do I practice this?":
            return "\(skill.advice) Try it on a question from \(skill.title) in Practice."
        case "What made this answer strong?":
            return entry.moment?.note ?? "You were specific and easy to follow."
        case "How could it be even better?":
            return "Keep it as it is, and add one number for the result."
        default:
            return "Good question. For this answer, the biggest win is this: \(skill.advice)"
        }
    }
}

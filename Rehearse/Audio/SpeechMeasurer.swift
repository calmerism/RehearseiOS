import Foundation
import Speech

/// Turns a transcript and its word timings into the numbers Communication is
/// scored on. Each is a plain count or rate, so it can be shown and checked.
nonisolated enum SpeechMeasurer {
    /// Sounds and words that fill a pause rather than say something.
    static let fillers: Set<String> = ["um", "umm", "uh", "uhh", "er", "erm", "hmm", "like"]
    /// Words people lean on; the one said most is reported.
    static let crutches = ["basically", "actually", "literally", "so", "right", "just", "really", "honestly"]
    /// Phrases that soften an answer until it says little.
    static let hedges = ["i think", "maybe", "probably", "i guess", "sort of", "kind of", "not sure", "i feel like"]
    /// A pause longer than this mid-answer counts as long.
    static let longPause: TimeInterval = 3

    static func answer(from result: SFSpeechRecognitionResult) -> SpokenAnswer? {
        let transcription = result.bestTranscription
        let text = transcription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let segments = transcription.segments
        return SpokenAnswer(text: text, measurements: measure(
            text: text,
            wordTimes: segments.map { (start: $0.timestamp, end: $0.timestamp + $0.duration) }
        ))
    }

    /// The measurements for an answer, from its text and when each word was
    /// said, in seconds from the start of the recording.
    static func measure(text: String, wordTimes: [(start: TimeInterval, end: TimeInterval)]) -> Measurements {
        let lower = text.lowercased()
        let words = lower
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'")).inverted)
            .filter { !$0.isEmpty }

        var measurements = Measurements()
        if let first = wordTimes.first, let last = wordTimes.last {
            let speaking = last.end - first.start
            if speaking >= 3 {
                measurements.wordsPerMinute = Int((Double(words.count) / speaking * 60).rounded())
            }
            measurements.secondsBeforeAnswering = (first.start * 10).rounded() / 10
            measurements.longPauses = zip(wordTimes, wordTimes.dropFirst())
                .filter { $1.start - $0.end > longPause }
                .count
        }
        // "You know" fills a pause too, as two words.
        let youKnows = zip(words, words.dropFirst()).filter { $0 == "you" && $1 == "know" }.count
        measurements.fillerWords = words.filter { fillers.contains($0) }.count + youKnows
        let crutchCounts = crutches.map { word in (word, words.filter { $0 == word }.count) }
        if let top = crutchCounts.max(by: { $0.1 < $1.1 }), top.1 > 0 {
            measurements.repeatedWord = top.0.prefix(1).uppercased() + top.0.dropFirst()
            measurements.repeats = top.1
        }
        measurements.hedges = hedges.reduce(0) { $0 + lower.components(separatedBy: $1).count - 1 }
        return measurements
    }

    /// One set of measurements for a whole interview: rates averaged, counts
    /// added up, and the most repeated word across all answers.
    static func combine(_ answers: [Measurements]) -> Measurements? {
        guard !answers.isEmpty else { return nil }
        func average(_ values: [Double]) -> Double? {
            values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        }
        func total(_ values: [Int?]) -> Int? {
            let present = values.compactMap { $0 }
            return present.isEmpty ? nil : present.reduce(0, +)
        }
        var combined = Measurements()
        combined.wordsPerMinute = average(answers.compactMap { $0.wordsPerMinute }.map(Double.init)).map { Int($0.rounded()) }
        combined.secondsBeforeAnswering = average(answers.compactMap(\.secondsBeforeAnswering)).map { ($0 * 10).rounded() / 10 }
        combined.fillerWords = total(answers.map(\.fillerWords))
        combined.longPauses = total(answers.map(\.longPauses))
        combined.hedges = total(answers.map(\.hedges))
        var crutchTotals: [String: Int] = [:]
        for answer in answers {
            if let word = answer.repeatedWord, let count = answer.repeats { crutchTotals[word, default: 0] += count }
        }
        if let top = crutchTotals.max(by: { $0.value < $1.value }) {
            combined.repeatedWord = top.key
            combined.repeats = top.value
        }
        return combined
    }
}

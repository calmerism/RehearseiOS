import Foundation

/// How an interview, and each answer in it, is scored. Six areas, each out
/// of 100 and made of a few parts with set weights; an area's score is the
/// weighted average of its parts, and the overall score is the average of
/// the six areas. Communication's and Confidence's parts are measured, each
/// turned into a score by a stated rule; the other parts are judged from the
/// answers. Every number on screen can be traced back through these sums.
enum ScoreArea: String, CaseIterable, Identifiable, Hashable {
    case technical, problemSolving, communication, projectDepth, uncertainty, confidence

    var id: Self { self }

    var title: String {
        switch self {
        case .technical: "Technical Knowledge"
        case .problemSolving: "Problem Solving"
        case .communication: "Communication"
        case .projectDepth: "Project Depth"
        case .uncertainty: "Handling Uncertainty"
        case .confidence: "Confidence"
        }
    }

    /// What it measures, in a few words.
    var measures: String {
        switch self {
        case .technical: "Knowing it, and using it right"
        case .problemSolving: "How you work through a problem"
        case .communication: "How it sounds, measured"
        case .projectDepth: "How well you know your own work"
        case .uncertainty: "What you do when you don’t know"
        case .confidence: "How sure you sound and look, measured"
        }
    }

    /// Where the score comes from: the words of the answers, judged by AI
    /// against a fixed checklist, or the voice and camera, measured.
    var method: String {
        switch self {
        case .communication: "Measured from your voice"
        case .confidence: "Measured from your voice and camera"
        default: "Judged from your words"
        }
    }

    /// Measured areas follow set rules; the rest are judged.
    var isMeasured: Bool { self == .communication || self == .confidence }

    var symbol: String {
        switch self {
        case .technical: "cpu.fill"
        case .problemSolving: "puzzlepiece.fill"
        case .communication: "waveform"
        case .projectDepth: "folder.fill"
        case .uncertainty: "lightbulb.fill"
        case .confidence: "person.fill.checkmark"
        }
    }
}

// MARK: - What the judge and the measurements report

/// A judged part of an answer, named so the answer judge can be asked about
/// each one and its verdict stored. The four judged areas are made of these;
/// Communication and Confidence are measured instead.
enum JudgedPartKey: String, CaseIterable, Hashable, nonisolated Codable {
    // Technical Knowledge
    case concept, completeness, application, terminology
    // Problem Solving
    case understanding, approach, logicalReasoning, tradeoffs
    // Project Depth
    case projectReasoning, relevance, technicalTradeoffs
    // Handling Uncertainty
    case admitsUnknowns, wayForward, reasonsAloud, usesHints

    var area: ScoreArea {
        switch self {
        case .concept, .completeness, .application, .terminology: .technical
        case .understanding, .approach, .logicalReasoning, .tradeoffs: .problemSolving
        case .projectReasoning, .relevance, .technicalTradeoffs: .projectDepth
        case .admitsUnknowns, .wayForward, .reasonsAloud, .usesHints: .uncertainty
        }
    }

    var title: String {
        switch self {
        case .concept: "Concept"
        case .completeness: "Completeness"
        case .application: "Application"
        case .terminology: "Terminology"
        case .understanding: "Understanding the problem"
        case .approach: "Approach"
        case .logicalReasoning: "Logical reasoning"
        case .tradeoffs: "Trade-offs"
        case .projectReasoning: "Reasoning"
        case .relevance: "Answering what was asked"
        case .technicalTradeoffs: "Technical trade-offs"
        case .admitsUnknowns: "Admitting what you don’t know"
        case .wayForward: "How you’d approach it"
        case .reasonsAloud: "Reasoning"
        case .usesHints: "After a hint"
        }
    }
}

/// The judge's answer for one part of one answer: a checklist verdict, never
/// a number. Code turns verdicts into scores, so the same answer always gets
/// the same score and every score can be explained.
struct JudgedPart: Hashable, nonisolated Codable {
    enum Verdict: String, Hashable, nonisolated Codable {
        case met, partly, missed

        /// What a verdict is worth, out of 100.
        var score: Int {
            switch self {
            case .met: 100
            case .partly: 60
            case .missed: 20
            }
        }
    }

    let key: JudgedPartKey
    let verdict: Verdict
    /// What in the answer led to the verdict, briefly: "Named Redis but not
    /// why". Shown under the part; the part's own wording is used if empty.
    var evidence: String?
}

/// What was measured from the voice and camera for an answer, or for a whole
/// interview. Anything not measured is nil and falls back to the estimate.
nonisolated struct Measurements: Hashable, Codable, Sendable {
    var wordsPerMinute: Int?
    var fillerWords: Int?
    var secondsBeforeAnswering: Double?
    /// The word said most often, and how many times beyond normal use.
    var repeatedWord: String?
    var repeats: Int?
    var eyeContactPercent: Int?
    var trailedOffAnswers: Int?
    /// Pauses over three seconds mid-answer.
    var longPauses: Int?
    /// "I think maybe" and similar.
    var hedges: Int?
}

/// One part of an area: its weight in the area, its score out of 100, and
/// what it was based on. Measured parts also give the rule that turned the
/// measurement into the score.
struct ScorePart: Identifiable, Hashable {
    let title: String
    /// Percent of the area, the parts adding up to 100.
    let weight: Int
    let score: Int
    /// What happened, briefly: "7 filler words", "Explained caching correctly".
    let evidence: String
    /// For a measured part, how the measurement becomes the score.
    var rule: String?
    var id: String { title }
}

/// One area's score and the parts it's worked out from.
struct AreaScore: Identifiable, Hashable {
    let area: ScoreArea
    let parts: [ScorePart]
    var id: ScoreArea { area }

    /// The weighted average of the parts.
    var score: Int {
        let total = parts.reduce(0.0) { $0 + Double($1.weight * $1.score) / 100 }
        return Int(total.rounded())
    }

    /// The sum itself: "0.3 × 80 + 0.5 × 64 + 0.1 × 76 + 0.1 × 70 = 70".
    var formula: String {
        let terms = parts.map { part in
            let weight = Double(part.weight) / 100
            let shown = weight == weight.rounded(.down) ? "\(Int(weight))" : String(format: "%g", weight)
            return "\(shown) × \(part.score)"
        }
        return terms.joined(separator: " + ") + " = \(score)"
    }
}

/// Builds the areas from what was heard. In the prototype the judged parts
/// come from the interview's answer quality and communication scores and its
/// focus; the measured ones from mocked measurements.
enum Scoring {
    /// Profile's Flag Filler Words. Off, filler words are left out of
    /// Communication and its other three parts share the weight.
    static var flagsFillerWords = true

    /// How one answer differs from the interview as a whole.
    enum Answer: Hashable {
        case whole
        case strong
        case weak(Skill)
    }

    /// The six areas. Judged parts with verdicts are scored from them (the
    /// average when several answers were judged); parts without fall back to
    /// the estimate from `answerQuality`. Measured parts use `measured` where
    /// it has a value, and an estimate from `communication` otherwise.
    static func areas(answerQuality aq: Int, communication: Int, focus: Skill, for answer: Answer = .whole,
                      verdicts: [JudgedPart] = [], measured: Measurements? = nil) -> [AreaScore] {
        let clamp = { (value: Int) in min(max(value, 0), 100) }
        // A strong answer lifts the judged parts a little; a weak one drops
        // the parts its weakness touches.
        var lift = 0
        var weak: Skill?
        switch answer {
        case .whole: break
        case .strong: lift = 8
        case .weak(let skill): lift = -4; weak = skill
        }
        // The skill the penalties hit: the interview's focus, the answer's own
        // weakness, or none for a strong answer.
        let hitSkill: Skill? = switch answer {
        case .whole: focus
        case .strong: nil
        case .weak(let skill): skill
        }
        let structureHit = hitSkill == .answerStructure ? 14 : 2
        let resultsHit = hitSkill == .concreteResults ? 14 : 2
        let tradeoffHit = hitSkill == .tradeoffs ? 18 : 6
        let judged = { (value: Int) in clamp(value + lift) }
        let judge = { (score: Int, good: String, weakText: String) in (score, score >= 75 ? good : weakText) }

        // Measured: words a minute, filler words, seconds before answering,
        // overused words. Weaker answers have more fillers and repeats.
        let fillerCount = measured?.fillerWords ?? max(0, Int((Double(100 - communication) / 4).rounded()) + (answer == .strong ? -3 : weak != nil ? 2 : 0))
        let wordsPerMinute = measured?.wordsPerMinute ?? (weak != nil ? 166 : 148)
        let latency = measured?.secondsBeforeAnswering ?? (answer == .strong ? 1.6 : 2.6)
        let repeats = measured?.repeats ?? (answer == .strong ? 1 : weak != nil ? 4 : 3)
        let repeatedWord = measured?.repeatedWord ?? "Basically"

        // Measured too: where the eyes were (from the camera, on the phone),
        // answers whose voice trailed off, long pauses mid-answer and hedges
        // like "I think maybe". Calmer interviews have fewer of each.
        let shaky = communication < 50
        let eyeContact = measured?.eyeContactPercent ?? clamp(communication - 14 + (answer == .strong ? 10 : weak != nil ? -4 : 0))
        let trailedOff = measured?.trailedOffAnswers ?? (answer == .strong ? 0 : weak != nil ? 2 : shaky ? 3 : 2)
        let longPauses = measured?.longPauses ?? (answer == .strong ? 1 : weak != nil ? 3 : shaky ? 5 : 3)
        let hedges = measured?.hedges ?? (answer == .strong ? 1 : weak != nil ? 4 : shaky ? 6 : 4)

        let pace = clamp(wordsPerMinute < 130 ? 100 - 2 * (130 - wordsPerMinute) : wordsPerMinute > 160 ? 100 - 2 * (wordsPerMinute - 160) : 100)
        let fillers = clamp(100 - 4 * fillerCount)
        let response = clamp(latency <= 2 ? 100 : 100 - Int(((latency - 2) * 15).rounded()))
        let repeated = clamp(100 - 5 * repeats)
        let looking = clamp(eyeContact >= 70 ? 100 : 100 - 2 * (70 - eyeContact))
        let steady = clamp(100 - 10 * trailedOff)
        let pauses = clamp(100 - 8 * longPauses)
        let hedging = clamp(100 - 5 * hedges)

        /// A judged part: from its verdicts if it has any, else the estimate.
        func part(_ key: JudgedPartKey, _ weight: Int, _ estimate: (Int, String), good: String, weakText: String) -> ScorePart {
            let found = verdicts.filter { $0.key == key }
            guard !found.isEmpty else {
                return ScorePart(title: key.title, weight: weight, score: estimate.0, evidence: estimate.1)
            }
            let score = Int((Double(found.reduce(0) { $0 + $1.verdict.score }) / Double(found.count)).rounded())
            // The weakest answer's own words explain a low score best.
            let worst = found.min { $0.verdict.score < $1.verdict.score }
            let evidence = worst?.evidence.flatMap { $0.isEmpty ? nil : $0 } ?? (score >= 75 ? good : weakText)
            return ScorePart(title: key.title, weight: weight, score: score, evidence: evidence)
        }
        /// A judged part, estimated from `value` when it has no verdicts.
        func estimated(_ key: JudgedPartKey, _ weight: Int, _ value: Int, _ good: String, _ weakText: String) -> ScorePart {
            part(key, weight, judge(judged(value), good, weakText), good: good, weakText: weakText)
        }

        return [
            AreaScore(area: .technical, parts: [
                estimated(.concept, 30, aq + 4, "Explained the ideas correctly", "Some ideas were shaky"),
                estimated(.completeness, 30, aq - structureHit / 2, "Covered every part of the question", "Left part of the question out"),
                estimated(.application, 25, aq, "Applied it to a real case", "Stayed in theory"),
                estimated(.terminology, 15, aq + 8, "Used the right terms", "Mixed up some terms"),
            ]),
            AreaScore(area: .problemSolving, parts: [
                estimated(.understanding, 30, aq + 2, "Restated the problem first", "Started before pinning the problem down"),
                estimated(.approach, 50, aq - structureHit, "A clear plan before the details", "Details came before the plan"),
                estimated(.logicalReasoning, 10, aq - 4, "Each step followed on", "Jumped between steps"),
                estimated(.tradeoffs, 10, aq - tradeoffHit, "Said what you gave up", "Didn’t say what else you considered"),
            ]),
            AreaScore(area: .communication, parts: flagsFillerWords ? [
                ScorePart(title: "Words per minute", weight: 25, score: pace, evidence: "\(wordsPerMinute) words a minute", rule: "Full marks from 130 to 160, less 2 a word outside it"),
                ScorePart(title: "Filler words", weight: 25, score: fillers, evidence: "\(fillerCount) “um”s and “like”s", rule: "100, less 4 for each"),
                ScorePart(title: "Response time", weight: 25, score: response, evidence: String(format: "Started after %.1f seconds", latency), rule: "Full marks within 2 seconds, less 15 a second after"),
                ScorePart(title: "Repeated words", weight: 25, score: repeated, evidence: "“\(repeatedWord)” \(repeats) \(repeats == 1 ? "time" : "times")", rule: "100, less 5 for each repeat"),
            ] : [
                ScorePart(title: "Words per minute", weight: 34, score: pace, evidence: "\(wordsPerMinute) words a minute", rule: "Full marks from 130 to 160, less 2 a word outside it"),
                ScorePart(title: "Response time", weight: 33, score: response, evidence: String(format: "Started after %.1f seconds", latency), rule: "Full marks within 2 seconds, less 15 a second after"),
                ScorePart(title: "Repeated words", weight: 33, score: repeated, evidence: "“\(repeatedWord)” \(repeats) \(repeats == 1 ? "time" : "times")", rule: "100, less 5 for each repeat"),
            ]),
            AreaScore(area: .projectDepth, parts: [
                estimated(.projectReasoning, 35, aq - resultsHit, "Said why you built it that way", "Said what, not why"),
                estimated(.relevance, 30, aq + 6, "Answered the question asked", "Drifted to another project"),
                estimated(.technicalTradeoffs, 35, aq - tradeoffHit + 4, "Named the trade-offs you made", "Trade-offs left out"),
            ]),
            AreaScore(area: .uncertainty, parts: [
                estimated(.admitsUnknowns, 25, communication + 10, "Said plainly when you weren’t sure", "Guessed instead of saying"),
                estimated(.wayForward, 25, aq - 2, "Said how you’d find out", "No way forward given"),
                estimated(.reasonsAloud, 25, aq - 4, "Reasoned it through out loud", "Jumped to an answer"),
                estimated(.usesHints, 25, aq + 2, "Used the hint well", "Didn’t pick up the hint"),
            ]),
            AreaScore(area: .confidence, parts: [
                ScorePart(title: "Eye contact", weight: 25, score: looking, evidence: "Looked at the camera \(eyeContact)% of the time", rule: "Full marks from 70%, less 2 a point under it"),
                ScorePart(title: "Steady voice", weight: 25, score: steady, evidence: trailedOff == 0 ? "Your voice held steady" : "Trailed off in \(trailedOff) \(trailedOff == 1 ? "answer" : "answers")", rule: "100, less 10 for each answer that trailed off"),
                ScorePart(title: "Pauses", weight: 25, score: pauses, evidence: longPauses == 0 ? "No long pauses" : "\(longPauses) \(longPauses == 1 ? "pause" : "pauses") over 3 seconds", rule: "100, less 8 for each pause over 3 seconds"),
                ScorePart(title: "Hedging", weight: 25, score: hedging, evidence: "“I think maybe” \(hedges) \(hedges == 1 ? "time" : "times")", rule: "100, less 5 for each hedge"),
            ]),
        ]
    }

    /// The overall score: the average of the six areas.
    static func overall(_ areas: [AreaScore]) -> Int {
        guard !areas.isEmpty else { return 0 }
        return Int((Double(areas.reduce(0) { $0 + $1.score }) / Double(areas.count)).rounded())
    }
}

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
    /// How one answer differs from the interview as a whole.
    enum Answer: Hashable {
        case whole
        case strong
        case weak(Skill)
    }

    static func areas(answerQuality aq: Int, communication: Int, focus: Skill, for answer: Answer = .whole) -> [AreaScore] {
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
        let fillerCount = max(0, Int((Double(100 - communication) / 4).rounded()) + (answer == .strong ? -3 : weak != nil ? 2 : 0))
        let wordsPerMinute = weak != nil ? 166 : 148
        let latency = answer == .strong ? 1.6 : 2.6
        let repeats = answer == .strong ? 1 : weak != nil ? 4 : 3

        // Measured too: where the eyes were (from the camera, on the phone),
        // answers whose voice trailed off, long pauses mid-answer and hedges
        // like "I think maybe". Calmer interviews have fewer of each.
        let shaky = communication < 50
        let eyeContact = clamp(communication - 14 + (answer == .strong ? 10 : weak != nil ? -4 : 0))
        let trailedOff = answer == .strong ? 0 : weak != nil ? 2 : shaky ? 3 : 2
        let longPauses = answer == .strong ? 1 : weak != nil ? 3 : shaky ? 5 : 3
        let hedges = answer == .strong ? 1 : weak != nil ? 4 : shaky ? 6 : 4

        let pace = clamp(wordsPerMinute < 130 ? 100 - 2 * (130 - wordsPerMinute) : wordsPerMinute > 160 ? 100 - 2 * (wordsPerMinute - 160) : 100)
        let fillers = clamp(100 - 4 * fillerCount)
        let response = clamp(latency <= 2 ? 100 : 100 - Int(((latency - 2) * 15).rounded()))
        let repeated = clamp(100 - 5 * repeats)
        let looking = clamp(eyeContact >= 70 ? 100 : 100 - 2 * (70 - eyeContact))
        let steady = clamp(100 - 10 * trailedOff)
        let pauses = clamp(100 - 8 * longPauses)
        let hedging = clamp(100 - 5 * hedges)

        func part(_ title: String, _ weight: Int, _ judgedPart: (Int, String)) -> ScorePart {
            ScorePart(title: title, weight: weight, score: judgedPart.0, evidence: judgedPart.1)
        }

        return [
            AreaScore(area: .technical, parts: [
                part("Concept", 30, judge(judged(aq + 4), "Explained the ideas correctly", "Some ideas were shaky")),
                part("Completeness", 30, judge(judged(aq - structureHit / 2), "Covered every part of the question", "Left part of the question out")),
                part("Application", 25, judge(judged(aq), "Applied it to a real case", "Stayed in theory")),
                part("Terminology", 15, judge(judged(aq + 8), "Used the right terms", "Mixed up some terms")),
            ]),
            AreaScore(area: .problemSolving, parts: [
                part("Understanding the problem", 30, judge(judged(aq + 2), "Restated the problem first", "Started before pinning the problem down")),
                part("Approach", 50, judge(judged(aq - structureHit), "A clear plan before the details", "Details came before the plan")),
                part("Logical reasoning", 10, judge(judged(aq - 4), "Each step followed on", "Jumped between steps")),
                part("Trade-offs", 10, judge(judged(aq - tradeoffHit), "Said what you gave up", "Didn’t say what else you considered")),
            ]),
            AreaScore(area: .communication, parts: [
                ScorePart(title: "Words per minute", weight: 25, score: pace, evidence: "\(wordsPerMinute) words a minute", rule: "Full marks from 130 to 160, less 2 a word outside it"),
                ScorePart(title: "Filler words", weight: 25, score: fillers, evidence: "\(fillerCount) “um”s and “like”s", rule: "100, less 4 for each"),
                ScorePart(title: "Response time", weight: 25, score: response, evidence: String(format: "Started after %.1f seconds", latency), rule: "Full marks within 2 seconds, less 15 a second after"),
                ScorePart(title: "Repeated words", weight: 25, score: repeated, evidence: "“Basically” \(repeats) times", rule: "100, less 5 for each repeat"),
            ]),
            AreaScore(area: .projectDepth, parts: [
                part("Reasoning", 35, judge(judged(aq - resultsHit), "Said why you built it that way", "Said what, not why")),
                part("Answering what was asked", 30, judge(judged(aq + 6), "Answered the question asked", "Drifted to another project")),
                part("Technical trade-offs", 35, judge(judged(aq - tradeoffHit + 4), "Named the trade-offs you made", "Trade-offs left out")),
            ]),
            AreaScore(area: .uncertainty, parts: [
                part("Admitting what you don’t know", 25, judge(judged(communication + 10), "Said plainly when you weren’t sure", "Guessed instead of saying")),
                part("How you’d approach it", 25, judge(judged(aq - 2), "Said how you’d find out", "No way forward given")),
                part("Reasoning", 25, judge(judged(aq - 4), "Reasoned it through out loud", "Jumped to an answer")),
                part("After a hint", 25, judge(judged(aq + 2), "Used the hint well", "Didn’t pick up the hint")),
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

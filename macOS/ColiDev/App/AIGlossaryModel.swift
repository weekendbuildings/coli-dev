import Foundation

/// One word of the AI path glossary, read from the glossary lesson itself so the lab and the text never disagree.
/// Одно слово словаря пути ИИ; читается из самого урока-словаря, поэтому тренажёр и текст не расходятся.
struct AIGlossaryEntry: Equatable, Identifiable {
    let term: String
    let explanation: String
    let lessonTitle: String
    let step: Int
    let stage: Int
    var id: String { term }
}

enum AIGlossary {
    /// Parses `**Этап N. …**` / `**Stage N. …**` headings and entries of the form
    /// `- **Term.** Text. Подробно: «Lesson», шаг N.` (or `In detail: «Lesson», step N.`).
    static func parse(_ markdown: String, russian: Bool) -> [AIGlossaryEntry] {
        let header = russian ? "## Русский\n" : "## English\n"
        guard let start = markdown.range(of: header) else { return [] }
        var body = markdown[start.upperBound...]
        if let end = body.range(of: "\n## ") { body = body[..<end.lowerBound] }
        let stagePrefix = russian ? "**Этап " : "**Stage "
        let detail = russian ? " Подробно: «" : " In detail: «"
        let stepWord = russian ? "», шаг " : "», step "
        var stage = 0
        var result: [AIGlossaryEntry] = []
        for raw in body.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix(stagePrefix), line.hasSuffix("**") {
                let digits = line.dropFirst(stagePrefix.count).prefix(while: { $0.isNumber })
                stage = Int(digits) ?? stage
                continue
            }
            guard line.hasPrefix("- **"),
                  let termEnd = line.range(of: ".** "),
                  let detailRange = line.range(of: detail, options: .backwards),
                  let stepRange = line.range(of: stepWord, options: .backwards),
                  termEnd.upperBound <= detailRange.lowerBound,
                  detailRange.upperBound <= stepRange.lowerBound else { continue }
            let term = String(line[line.index(line.startIndex, offsetBy: 4)..<termEnd.lowerBound])
            let explanation = String(line[termEnd.upperBound..<detailRange.lowerBound])
            let lesson = String(line[detailRange.upperBound..<stepRange.lowerBound])
            guard let step = Int(line[stepRange.upperBound...].prefix(while: { $0.isNumber })) else { continue }
            result.append(AIGlossaryEntry(term: term, explanation: explanation, lessonTitle: lesson, step: step, stage: stage))
        }
        return result
    }

    /// Case-insensitive search in the word and its explanation, optionally inside one stage.
    static func filter(_ entries: [AIGlossaryEntry], query: String, stage: Int?) -> [AIGlossaryEntry] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return entries.filter { entry in
            (stage == nil || entry.stage == stage)
                && (needle.isEmpty || entry.term.lowercased().contains(needle) || entry.explanation.lowercased().contains(needle))
        }
    }

    static func countByStage(_ entries: [AIGlossaryEntry]) -> [Int: Int] {
        Dictionary(grouping: entries, by: \.stage).mapValues(\.count)
    }

    struct Question: Equatable {
        /// Index of the right entry in the pool passed in.
        let answer: Int
        /// Four pool indices in display order; one of them is `answer`.
        let options: [Int]
    }

    /// A repeatable quiz question: the same seed and number always give the same question.
    /// Distractors come from the same pool (one stage, or all), so they are close in topic.
    static func question(number: Int, poolSize: Int, seed: UInt64) -> Question? {
        guard poolSize >= 4 else { return nil }
        var generator = SplitMix(state: seed &+ UInt64(number) &* 0x9E37_79B9_7F4A_7C15)
        let answer = Int(generator.next() % UInt64(poolSize))
        var options: [Int] = [answer]
        while options.count < 4 {
            let candidate = Int(generator.next() % UInt64(poolSize))
            if !options.contains(candidate) { options.append(candidate) }
        }
        for index in stride(from: options.count - 1, to: 0, by: -1) {
            let swapWith = Int(generator.next() % UInt64(index + 1))
            options.swapAt(index, swapWith)
        }
        return Question(answer: answer, options: options)
    }

    /// SplitMix64: small, fast and the same on every machine.
    struct SplitMix {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            return value ^ (value >> 31)
        }
    }
}

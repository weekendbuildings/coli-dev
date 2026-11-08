import Foundation

// Checks the AI path glossary model against the real glossary lesson.
// Проверяет модель словаря пути ИИ на настоящем уроке-словаре.

@main
struct VerifyAIGlossary {
    static func check(_ condition: Bool, _ message: String) {
        if !condition {
            FileHandle.standardError.write(Data(("FAIL: " + message + "\n").utf8))
            exit(1)
        }
    }

    static func main() {
        let path = "02_Areas/Programming/lessons/ai_path_glossary.md"
        guard let markdown = try? String(contentsOfFile: path, encoding: .utf8) else {
            check(false, "cannot read \(path); run from the repository root")
            return
        }
        let ru = AIGlossary.parse(markdown, russian: true)
        let en = AIGlossary.parse(markdown, russian: false)
        check(ru.count >= 100, "expected at least 100 Russian entries, got \(ru.count)")
        check(ru.count == en.count, "Russian and English counts differ: \(ru.count) vs \(en.count)")
        check(Set(ru.map(\.term)).count == ru.count, "duplicate Russian terms")
        check(Set(en.map(\.term)).count == en.count, "duplicate English terms")
        for (a, b) in zip(ru, en) {
            check(a.stage == b.stage && a.step == b.step, "entry \(a.term) / \(b.term) has different stage or step")
            check((1...5).contains(a.stage), "entry \(a.term) has no stage")
            check((1...26).contains(a.step), "entry \(a.term) has step \(a.step)")
            check(!a.explanation.isEmpty && !a.lessonTitle.isEmpty, "entry \(a.term) is incomplete")
        }
        check(zip(ru, ru.dropFirst()).allSatisfy { $0.stage <= $1.stage }, "entries are not in stage order")
        let counts = AIGlossary.countByStage(ru)
        check((1...5).allSatisfy { (counts[$0] ?? 0) >= 4 }, "each stage needs at least 4 words: \(counts)")

        let gradient = AIGlossary.filter(ru, query: "ГРАД", stage: nil)
        check(gradient.contains { $0.term == "Градиент" }, "case-insensitive search misses «Градиент»")
        check(AIGlossary.filter(ru, query: "", stage: 5).allSatisfy { $0.stage == 5 }, "stage filter leaks")
        check(AIGlossary.filter(ru, query: "zzzz", stage: nil).isEmpty, "nonsense query should find nothing")

        let first = AIGlossary.question(number: 0, poolSize: ru.count, seed: 7)
        check(first == AIGlossary.question(number: 0, poolSize: ru.count, seed: 7), "the quiz is not repeatable")
        var answerPositions = Set<Int>()
        for number in 0..<200 {
            guard let question = AIGlossary.question(number: number, poolSize: 12, seed: 7) else {
                check(false, "no question for a pool of 12"); return
            }
            check(Set(question.options).count == 4, "options repeat in question \(number)")
            check(question.options.contains(question.answer), "the answer is not among the options")
            check(question.options.allSatisfy { (0..<12).contains($0) }, "an option is outside the pool")
            answerPositions.insert(question.options.firstIndex(of: question.answer)!)
        }
        check(answerPositions.count == 4, "the right answer does not move between positions")
        check(AIGlossary.question(number: 0, poolSize: 3, seed: 7) == nil, "a pool of 3 cannot make four options")
        print("AI glossary: \(ru.count) words, stages \(counts.sorted { $0.key < $1.key }.map { "\($0.key):\($0.value)" }.joined(separator: " ")), quiz ok")
    }
}

import Foundation

/// Checks the app's forward pass on the real weights against numbers written by the Python program.
/// Проверяет прямой проход приложения на настоящих весах по числам, которые записала программа на Python.
@main
enum TinyLanguageModelVerification {
    private struct Reference: Decodable {
        let prompt: String
        let top: String
        let probability: Double
        let scores: [Double]
    }

    static func main() throws {
        let folder = URL(fileURLWithPath: "02_Areas/Programming/resources")
        let model = try TinyLanguageModel(data: Data(contentsOf: folder.appendingPathComponent("tiny_language_model.json")))
        precondition(model.size == 32 && model.heads == 2 && model.blocks.count == 2 && model.length == 32, "the sizes of the program")

        // The app computes the same numbers as the program. / Приложение считает те же числа, что и программа.
        let references = try JSONDecoder().decode([Reference].self, from: Data(contentsOf: folder.appendingPathComponent("tiny_language_model_check.json")))
        precondition(!references.isEmpty)
        for reference in references {
            let result = model.run(model.window(of: reference.prompt))
            let last = result.scores.last!
            precondition(last.count == model.alphabet.count)
            for (ours, theirs) in zip(last, reference.scores) {
                precondition(abs(ours - theirs) < 1e-6, "the scores match the program for \(reference.prompt)")
            }
            let probabilities = TinyLanguageModel.softmax(last, temperature: 1)
            let top = probabilities.indices.max { probabilities[$0] < probabilities[$1] }!
            precondition(model.alphabet[top] == reference.top && abs(probabilities[top] - reference.probability) < 1e-6, "the top letter")
        }

        // The opening of the lab does not solve its task, and the task can be solved.
        // Начальное состояние не решает задание, а само задание решаемо.
        let opening = model.next(after: "Нейронная сеть", temperature: 1)!.probabilities.max()!
        precondition(opening < 0.9, "the opening does not solve the task")
        precondition(references.contains { $0.probability >= 0.9 }, "a text exists that solves the task")

        // The mask: a later character changes nothing about earlier places. / Маска: поздний символ не меняет ранних мест.
        let text = "Обучение идёт"
        let base = model.run(model.encode(text))
        let longer = model.run(model.encode(text + "!"))
        for t in base.scores.indices {
            for (a, b) in zip(base.scores[t], longer.scores[t]) { precondition(a == b, "the mask holds") }
        }
        // Attention rows are true probabilities, one row per place read. / Строки внимания это настоящие вероятности.
        for block in base.attention {
            for head in block {
                precondition(head.count == text.unicodeScalars.count)
                for (t, row) in head.enumerated() {
                    precondition(row.count == t + 1 && abs(row.reduce(0, +) - 1) < 1e-9)
                }
            }
        }

        // Temperature: colder is sharper. / Чем ниже температура, тем резче распределение.
        let scores = base.scores.last!
        let cold = TinyLanguageModel.softmax(scores, temperature: 0.1).max()!
        let warm = TinyLanguageModel.softmax(scores, temperature: 1).max()!
        let hot = TinyLanguageModel.softmax(scores, temperature: 1.8).max()!
        precondition(cold >= warm && warm >= hot, "temperature")

        // Drawing follows the segments, and unknown characters read as the last sign, □.
        precondition(TinyLanguageModel.draw([0.6, 0.3, 0.1], uniform: 0.75) == 1)
        precondition(TinyLanguageModel.draw([0.6, 0.3, 0.1], uniform: 0.999999) == 2)
        precondition(model.encode("\u{1F980}") == [model.alphabet.count - 1] && model.alphabet.last == "□", "unknown characters")

        // A long text is cut to the window, and a wrong file gives an error, not a crash.
        precondition(model.window(of: String(repeating: "а", count: 100)).count == model.length)
        for bad in ["{}", "[]", "{\"alphabet\":[\"a\",\"b\"],\"size\":4,\"heads\":3,\"blocks\":1,\"length\":2,\"weights\":[]}"] {
            precondition((try? TinyLanguageModel(data: Data(bad.utf8))) == nil, "a wrong file is refused")
        }

        print("Tiny language model verification passed.")
    }
}

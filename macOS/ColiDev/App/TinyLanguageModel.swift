import Foundation

/// The final project's language model, read from the file the training program saves, and run exactly as in that program.
/// Языковая модель финального проекта: читается из файла, который сохраняет программа обучения, и считается как в ней.
struct TinyLanguageModel {
    enum LoadError: Error {
        case notAModel
    }

    struct Block {
        let query: [[[Double]]]
        let key: [[[Double]]]
        let value: [[[Double]]]
        let mix: [[Double]]
        let wide: [[Double]]
        let narrow: [[Double]]
    }

    private struct File: Decodable {
        let alphabet: [String]
        let size: Int
        let heads: Int
        let blocks: Int
        let length: Int
        let weights: [[[Double]]]
    }

    let alphabet: [String]
    let size: Int
    let heads: Int
    let length: Int
    let letters: [[Double]]
    let places: [[Double]]
    let output: [[Double]]
    let blocks: [Block]
    private let code: [Unicode.Scalar: Int]
    private let unknown: Int

    /// Checks every shape, so that a wrong file gives an error and not a crash. / Проверяет все размеры: чужой файл даёт ошибку, а не сбой.
    init(data: Data) throws {
        let file = try JSONDecoder().decode(File.self, from: data)
        let part = file.heads > 0 ? file.size / file.heads : 0
        let expected = 3 + file.blocks * (3 * file.heads + 3)
        guard file.size > 0, file.heads > 0, part * file.heads == file.size, file.blocks > 0, file.length > 0,
              file.alphabet.count > 1, file.alphabet.allSatisfy({ $0.unicodeScalars.count == 1 }),
              file.weights.count == expected else { throw LoadError.notAModel }
        func shaped(_ matrix: [[Double]], _ rows: Int, _ columns: Int) -> Bool {
            matrix.count == rows && matrix.allSatisfy { $0.count == columns && $0.allSatisfy(\.isFinite) }
        }
        let vocabulary = file.alphabet.count
        guard shaped(file.weights[0], vocabulary, file.size), shaped(file.weights[1], file.length, file.size),
              shaped(file.weights[2], file.size, vocabulary) else { throw LoadError.notAModel }
        var cursor = 3
        var built: [Block] = []
        for _ in 0..<file.blocks {
            func take(_ count: Int) -> [[[Double]]] {
                defer { cursor += count }
                return Array(file.weights[cursor..<(cursor + count)])
            }
            let query = take(file.heads), key = take(file.heads), value = take(file.heads)
            let mix = take(1)[0], wide = take(1)[0], narrow = take(1)[0]
            guard (query + key + value).allSatisfy({ shaped($0, file.size, part) }), shaped(mix, file.size, file.size),
                  shaped(wide, file.size, 2 * file.size), shaped(narrow, 2 * file.size, file.size) else { throw LoadError.notAModel }
            built.append(Block(query: query, key: key, value: value, mix: mix, wide: wide, narrow: narrow))
        }
        var table: [Unicode.Scalar: Int] = [:]
        for (index, letter) in file.alphabet.enumerated() {
            if let scalar = letter.unicodeScalars.first { table[scalar] = index }
        }
        alphabet = file.alphabet
        size = file.size
        heads = file.heads
        length = file.length
        letters = file.weights[0]
        places = file.weights[1]
        output = file.weights[2]
        blocks = built
        code = table
        unknown = file.alphabet.count - 1
    }

    /// The model that comes with the course. / Модель, которая идёт вместе с курсом.
    static let bundled: TinyLanguageModel? = {
        guard let root = Bundle.main.resourceURL else { return nil }
        let url = root.appendingPathComponent("02_Areas/Programming/resources/tiny_language_model.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? TinyLanguageModel(data: data)
    }()

    func encode(_ text: String) -> [Int] { text.unicodeScalars.map { code[$0] ?? unknown } }

    private static func multiply(_ a: [[Double]], _ b: [[Double]]) -> [[Double]] {
        let columns = b.first?.count ?? 0
        var result = [[Double]](repeating: [Double](repeating: 0, count: columns), count: a.count)
        for r in a.indices {
            let row = a[r]
            var line = [Double](repeating: 0, count: columns)
            for m in row.indices {
                let value = row[m]
                let other = b[m]
                for c in 0..<columns { line[c] += value * other[c] }
            }
            result[r] = line
        }
        return result
    }

    private static func normalize(_ a: [[Double]]) -> [[Double]] {
        a.map { row in
            let count = Double(row.count)
            let mean = row.reduce(0, +) / count
            let spread = (row.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / count).squareRoot() + 1e-5
            return row.map { ($0 - mean) / spread }
        }
    }

    private static func add(_ a: [[Double]], _ b: [[Double]]) -> [[Double]] {
        zip(a, b).map { zip($0, $1).map { $0 + $1 } }
    }

    /// The forward pass of the program. It returns the scores and, for each block and head, the attention rows.
    /// Прямой проход программы: оценки и, для каждого блока и головы, строки внимания.
    func run(_ indices: [Int]) -> (scores: [[Double]], attention: [[[[Double]]]]) {
        let part = size / heads
        let root = Double(part).squareRoot()
        var x = indices.enumerated().map { position, letter in zip(letters[letter], places[position]).map { $0 + $1 } }
        var attention: [[[[Double]]]] = []
        for block in blocks {
            var joined = [[Double]](repeating: [], count: x.count)
            var blockAttention: [[[Double]]] = []
            for head in 0..<heads {
                let q = Self.multiply(x, block.query[head])
                let k = Self.multiply(x, block.key[head])
                let v = Self.multiply(x, block.value[head])
                var rows: [[Double]] = []
                for t in x.indices {
                    var scores = [Double](repeating: 0, count: t + 1)
                    for j in 0...t {
                        var total = 0.0
                        for i in 0..<part { total += q[t][i] * k[j][i] }
                        scores[j] = total / root
                    }
                    let weights = Self.softmax(scores, temperature: 1)
                    var answer = [Double](repeating: 0, count: part)
                    for j in 0...t {
                        for i in 0..<part { answer[i] += weights[j] * v[j][i] }
                    }
                    joined[t] += answer
                    rows.append(weights)
                }
                blockAttention.append(rows)
            }
            attention.append(blockAttention)
            x = Self.normalize(Self.add(x, Self.multiply(joined, block.mix)))
            let spread = Self.multiply(x, block.wide).map { $0.map { max($0, 0) } }
            x = Self.normalize(Self.add(x, Self.multiply(spread, block.narrow)))
        }
        return (Self.multiply(x, output), attention)
    }

    static func softmax(_ scores: [Double], temperature: Double) -> [Double] {
        let top = scores.max() ?? 0
        let powers = scores.map { exp(($0 - top) / temperature) }
        let total = powers.reduce(0, +)
        return powers.map { $0 / total }
    }

    /// What the model reads: at most `length` last characters. / Что читает модель: не больше `length` последних символов.
    func window(of text: String) -> [Int] { Array(encode(text).suffix(length)) }

    /// The probabilities of the next character after a text, and the attention for that text.
    func next(after text: String, temperature: Double) -> (probabilities: [Double], attention: [[[[Double]]]])? {
        let indices = window(of: text)
        guard !indices.isEmpty else { return nil }
        let result = run(indices)
        guard let last = result.scores.last else { return nil }
        return (Self.softmax(last, temperature: temperature), result.attention)
    }

    /// Draws one index from probabilities, given a uniform number below 1. / Выбирает номер по вероятностям и равномерному числу.
    static func draw(_ probabilities: [Double], uniform: Double) -> Int {
        var point = uniform
        for (index, probability) in probabilities.enumerated() {
            point -= probability
            if point < 0 { return index }
        }
        return probabilities.count - 1
    }
}

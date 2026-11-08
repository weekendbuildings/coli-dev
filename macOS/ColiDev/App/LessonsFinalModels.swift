import Foundation

// Models for the importance B and C lessons of the AI path, Foundation only, so the CI can check them with swiftc.
// Модели для уроков важности B и C пути ИИ; только Foundation, чтобы CI проверял их через swiftc.

/// The same seeded generator as the Python `Rand` class in these lessons.
struct LFRand {
    var state: UInt64
    mutating func next() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / 9_007_199_254_740_992.0
    }
}

/// The pair counter of the lesson «Счётчик пар: первая языковая модель».
enum BigramCounter {
    static let train = "мама мыла раму. папа читал книгу. мама читала книгу сыну. "
        + "кот спал на окне. пёс спал у двери. кот видел пса, а пёс видел кота. "
        + "сын читал книгу коту. мама мыла окно. папа мыл пол. кот мыл лапу. "
        + "утром мама пила чай, а папа пил кофе. вечером сын пил молоко. "
        + "пёс любил гулять, а кот любил спать. мама любила книги. "
    static let test = "папа читал книгу маме. кот спал у окна. сын любил молоко. "
    static let smoothingSteps: [Double] = [0, 0.001, 0.003, 0.01, 0.03, 0.1, 0.3, 1, 3]

    private static func code(_ c: Character) -> UInt32 { c.unicodeScalars.first?.value ?? 0 }

    static let letters: [Character] = Array(Set(train + test)).sorted { code($0) < code($1) }

    /// For each letter, the letters that followed it in training with their counts, in order of first appearance.
    static let counts: [Character: [(Character, Int)]] = {
        var table: [Character: [(Character, Int)]] = [:]
        let chars = Array(train)
        for index in 0..<(chars.count - 1) {
            let a = chars[index], b = chars[index + 1]
            var row = table[a] ?? []
            if let position = row.firstIndex(where: { $0.0 == b }) {
                row[position].1 += 1
            } else {
                row.append((b, 1))
            }
            table[a] = row
        }
        return table
    }()

    static func rowTotal(_ a: Character) -> Int { (counts[a] ?? []).reduce(0) { $0 + $1.1 } }

    /// Letters that most often have something after them, for the buttons of the lab.
    static var commonLetters: [Character] {
        counts.keys.sorted { (rowTotal($0), code($1)) > (rowTotal($1), code($0)) }
    }

    /// Next-letter probabilities after `a` at temperature `t`: weight = count^(1/t), most likely first.
    static func probabilities(after a: Character, temperature t: Double) -> [(Character, Double)] {
        let row = counts[a] ?? []
        let weights = row.map { ($0.0, pow(Double($0.1), 1.0 / t)) }
        let total = weights.reduce(0.0) { $0 + $1.1 }
        return weights.map { ($0.0, $0.1 / total) }.sorted { ($0.1, code($1.0)) > ($1.1, code($0.0)) }
    }

    static func nextLetter(after a: Character, temperature t: Double, rand: inout LFRand) -> Character {
        let row = counts[a] ?? [(" ", 1)]
        var weights: [Character: Double] = [:]
        var total = 0.0
        for (b, c) in row {
            let w = pow(Double(c), 1.0 / t)
            weights[b] = w
            total += w
        }
        var r = rand.next() * total
        let ordered = weights.keys.sorted { code($0) < code($1) }
        for b in ordered {
            r -= weights[b] ?? 0
            if r <= 0 { return b }
        }
        return ordered.last ?? " "
    }

    static func generate(temperature t: Double, seed: UInt64 = 7, length: Int = 45) -> String {
        var rand = LFRand(state: seed)
        var text: [Character] = ["м"]
        for _ in 0..<length { text.append(nextLetter(after: text[text.count - 1], temperature: t, rand: &rand)) }
        return String(text)
    }

    /// Average −ln P(next | current) in nats with additive smoothing α; infinity if a pair gets probability zero.
    static func loss(_ text: String, alpha: Double) -> Double {
        let v = Double(letters.count)
        let chars = Array(text)
        var total = 0.0
        for index in 0..<(chars.count - 1) {
            let a = chars[index], b = chars[index + 1]
            let seen = Double((counts[a] ?? []).first(where: { $0.0 == b })?.1 ?? 0)
            let p = (seen + alpha) / (Double(rowTotal(a)) + alpha * v)
            if p == 0 { return .infinity }
            total -= log(p)
        }
        return total / Double(chars.count - 1)
    }

    static var randomGuess: Double { log(Double(letters.count)) }

    /// Index in `smoothingSteps` with the smallest finite test error.
    static var bestSmoothingIndex: Int {
        let losses = smoothingSteps.map { loss(test, alpha: $0) }
        return losses.indices.min { losses[$0] < losses[$1] } ?? 0
    }
}

/// The 20 best next tokens of qwen2.5-coder:7b after "The capital of France is", recorded 2026-11-02 with Ollama 0.40.13
/// and all filters off (`02_Areas/Programming/resources/live_model_recording.json`). A test keeps the two equal.
enum RealTop20 {
    static let tokens: [(String, Double)] = [
        (" Paris", -0.4599), (" __", -3.0503), (":\n", -3.1145), (" ______", -3.1598), (" a", -3.5436),
        (":\n\n", -3.5548), (" located", -3.5708), (" ____", -4.4905), (" the", -4.8847), (" not", -4.9136),
        (" ___", -5.0097), ("\n", -5.0983), (" in", -5.1732), ("____", -5.4525), (" an", -5.5102),
        (" known", -5.6419), (" also", -5.6668), (" situated", -5.6904), (" where", -5.7956), (" .\n", -5.8063),
    ]
    static var probabilities: [Double] { tokens.map { exp($0.1) } }

    /// How a token looks on a bar: a leading space is «␣», a line break «↵».
    static func shown(_ index: Int) -> String {
        tokens[index].0.replacingOccurrences(of: " ", with: "␣").replacingOccurrences(of: "\n", with: "↵")
    }

    /// Number of tokens top-p keeps, or nil if the 20 recorded ones do not reach `p`.
    static func nucleusSize(_ p: Double) -> Int? {
        var mass = 0.0
        for (index, q) in probabilities.enumerated() {
            mass += q
            if mass >= p { return index + 1 }
        }
        return nil
    }

    /// Tokens kept by top-k and top-p together; nil when top-p needs more than the recording holds.
    static func kept(k: Int, p: Double) -> Int? {
        guard let nucleus = nucleusSize(p) else { return k < 20 ? k : nil }
        return min(k, nucleus)
    }

    /// Picks `count` tokens among the first `kept`, with renormalized probabilities; returns how often each came up.
    static func pick(kept: Int, count: Int, seed: UInt64) -> [Int] {
        let weights = Array(probabilities.prefix(kept))
        let total = weights.reduce(0, +)
        var rand = LFRand(state: seed)
        var hits = [Int](repeating: 0, count: tokens.count)
        for _ in 0..<count {
            var r = rand.next() * total
            var chosen = kept - 1
            for (index, w) in weights.enumerated() {
                r -= w
                if r <= 0 { chosen = index; break }
            }
            hits[chosen] += 1
        }
        return hits
    }
}

/// Rules as the judge and DPO on a table of four answers per question, as in «Правила вместо людей и DPO».
enum DPOToy {
    static let prompts: [(String, [String])] = [
        ("Сколько будет 2 + 2?", [
            "Четыре, то есть 4.",
            "Отстань, это знает любой дурак: 4.",
            "Хороший вопрос, давай подумаем вместе, сложение это когда мы берём одно и другое.",
            "Пять, то есть 5.",
        ]),
        ("Сколько дней в неделе?", [
            "В неделе 7 дней.",
            "Семь, дурак.",
            "Неделя это отрезок времени, который люди придумали очень давно.",
            "В неделе 8 дней.",
        ]),
    ]
    /// Answers that are actually right, used only by the optional fourth rule.
    static let correct: [[Bool]] = [[true, true, false, false], [true, true, false, false]]

    static func breaks(prompt: Int, answer: Int, truthRule: Bool) -> [String] {
        let text = prompts[prompt].1[answer]
        let cleaned = text.lowercased().replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: ".", with: " ").replacingOccurrences(of: ":", with: " ")
        let words = cleaned.split(whereSeparator: { $0 == " " }).map(String.init)
        var result: [String] = []
        if words.contains("дурак") || words.contains("отстань") { result.append("polite") }
        if words.count > 8 { result.append("short") }
        if !text.contains(where: { $0.isNumber }) { result.append("on topic") }
        if truthRule, !correct[prompt][answer] { result.append("true") }
        return result
    }

    /// (prompt, winner, loser) for every pair where the winner breaks fewer rules.
    static func pairs(truthRule: Bool) -> [(Int, Int, Int)] {
        var result: [(Int, Int, Int)] = []
        for p in prompts.indices {
            for i in 0..<4 {
                for j in 0..<4 where breaks(prompt: p, answer: i, truthRule: truthRule).count < breaks(prompt: p, answer: j, truthRule: truthRule).count {
                    result.append((p, i, j))
                }
            }
        }
        return result
    }

    static func softmax(_ z: [Double]) -> [Double] {
        let m = z.max() ?? 0
        let e = z.map { exp($0 - m) }
        let s = e.reduce(0, +)
        return e.map { $0 / s }
    }

    /// Gradient descent on the DPO loss −ln σ(β (θw − θl)); the reference is the uniform start.
    static func train(beta: Double, steps: Int, truthRule: Bool = false, rate: Double = 1.0) -> [[Double]] {
        let list = pairs(truthRule: truthRule)
        var theta = [[Double]](repeating: [0, 0, 0, 0], count: prompts.count)
        guard !list.isEmpty else { return theta }
        for _ in 0..<steps {
            var grad = [[Double]](repeating: [0, 0, 0, 0], count: prompts.count)
            for (p, w, l) in list {
                let margin = beta * (theta[p][w] - theta[p][l])
                let push = beta * (1 - 1 / (1 + exp(-margin)))
                grad[p][w] -= push
                grad[p][l] += push
            }
            for p in prompts.indices {
                for k in 0..<4 { theta[p][k] -= rate * grad[p][k] / Double(list.count) }
            }
        }
        return theta
    }

    static func probabilities(_ theta: [[Double]]) -> [[Double]] { theta.map(softmax) }

    /// KL(π ‖ uniform start) for one question.
    static func kl(_ pi: [Double]) -> Double { pi.reduce(0) { $0 + ($1 > 0 ? $1 * log($1 / 0.25) : 0) } }
}

/// The Chinchilla fit (Hoffmann et al. 2022, equation 10) and the cost of training on this Mac.
enum ScalingLaw {
    static func loss(n: Double, d: Double) -> Double { 1.69 + 406.4 / pow(n, 0.34) + 410.7 / pow(d, 0.28) }

    /// The best model size for a compute budget C = 6ND, found on the same grid as the lesson's program.
    static func best(compute: Double) -> (n: Double, d: Double, loss: Double) {
        var result = (n: 0.0, d: 0.0, loss: Double.infinity)
        for step in 0...1200 {
            let n = pow(10.0, 6.0 + Double(step) / 100.0)
            let d = compute / (6.0 * n)
            let value = loss(n: n, d: d)
            if value < result.loss { result = (n, d, value) }
        }
        return result
    }

    /// Operations per second of the lesson «Своя языковая модель»: 6 · 26 624 weights · 1 536 000 characters in 47.2 minutes.
    static let mySpeed = 6.0 * 26_624.0 * 1_536_000.0 / (47.2 * 60.0)
    /// Apple's peak figure for the eight-core M1 GPU.
    static let gpuPeak = 2.6e12
    static func years(compute: Double, speed: Double) -> Double { compute / speed / (365.0 * 24.0 * 3600.0) }
}

/// Quality filters, exact copies and near-copies on twelve short texts, as in «Данные для языковой модели».
enum DedupToy {
    static let docs: [String] = [
        "Кот спал на тёплом окне и смотрел, как падает снег.",
        "Градиентный спуск уменьшает ошибку маленькими шагами против градиента.",
        "Главная | Новости | Контакты | Войти | Корзина",
        "Кот спал на тёплом окне и смотрел, как падает снег.",
        "Купить дёшево! Купить дёшево! Купить дёшево! Купить дёшево!",
        "Градиентный спуск уменьшает ошибку небольшими шагами против градиента.",
        "Ок",
        "Модель внимания сама выбирает, на какие прошлые токены смотреть.",
        "Пёс гулял во дворе и искал свой мяч под старой скамейкой.",
        "Кот спал на тёплом окне и смотрел, как падал снег.",
        "Токенизатор BPE склеивает самую частую пару кусочков текста.",
        "Пёс гулял по двору и искал мяч под скамейкой у подъезда.",
    ]

    enum Reason: String { case tooShort = "too short", noFullStop = "no full stop at the end", repeats = "repeats itself" }

    static func words(_ doc: String) -> [String] { doc.split(whereSeparator: { $0.isWhitespace }).map(String.init) }

    static func quality(_ doc: String) -> Reason? {
        let w = words(doc)
        if w.count < 5 { return .tooShort }
        if let last = doc.last, !".!?".contains(last) { return .noFullStop }
        if Double(Set(w).count) / Double(w.count) < 0.5 { return .repeats }
        return nil
    }

    static func normalized(_ doc: String) -> String { words(doc.lowercased()).joined(separator: " ") }

    static var afterFilters: [Int] { docs.indices.filter { quality(docs[$0]) == nil } }

    /// Index of the earlier exact copy for texts removed in step 2.
    static var exactCopies: [Int: Int] {
        var first: [String: Int] = [:]
        var copies: [Int: Int] = [:]
        for index in afterFilters {
            let key = normalized(docs[index])
            if let earlier = first[key] { copies[index] = earlier } else { first[key] = index }
        }
        return copies
    }

    static var unique: [Int] { afterFilters.filter { exactCopies[$0] == nil } }

    static func shingles(_ doc: String, size: Int = 5) -> Set<String> {
        let chars = Array(normalized(doc))
        guard chars.count >= size else { return [] }
        return Set((0...(chars.count - size)).map { String(chars[$0..<($0 + size)]) })
    }

    static func jaccard(_ a: Int, _ b: Int) -> Double {
        let x = shingles(docs[a]), y = shingles(docs[b])
        return Double(x.intersection(y).count) / Double(x.union(y).count)
    }

    /// Texts dropped as near-copies at a threshold: later text → the earlier text it copies.
    static func nearCopies(threshold: Double) -> [Int: Int] {
        var removed: [Int: Int] = [:]
        let list = unique
        for (i, a) in list.enumerated() where removed[a] == nil {
            for b in list[(i + 1)...] where removed[b] == nil && jaccard(a, b) >= threshold {
                removed[b] = a
            }
        }
        return removed
    }
}

/// A sparse autoencoder with five features on five sparse concepts in two dimensions, trained exactly as in «Разреженные признаки».
enum SparseAutoencoder {
    static let features: [(Double, Double)] = (0..<5).map { k in (cos(2.0 * Double.pi * Double(k) / 5.0), sin(2.0 * Double.pi * Double(k) / 5.0)) }
    static let penalties: [Double] = [0, 0.03, 0.3, 1, 3]

    static let data: [(Double, Double)] = {
        var rand = LFRand(state: 3)
        var points: [(Double, Double)] = []
        for _ in 0..<2000 {
            var x = (0.0, 0.0)
            for direction in features where rand.next() < 0.1 {
                let value = rand.next()
                x.0 += value * direction.0
                x.1 += value * direction.1
            }
            points.append(x)
        }
        return points
    }()

    struct Result {
        let decoder: [(Double, Double)]
        let alive: [Bool]
        let error: Double
        let activePerPoint: Double
        let found: Int
        var dead: Int { alive.filter { !$0 }.count }
    }

    static func train(lambda: Double, epochs: Int = 20, rate: Double = 0.05, seed: UInt64 = 11) -> Result {
        let units = 5
        var r = LFRand(state: seed)
        var enc: [[Double]] = (0..<units).map { _ in
            let a = r.next() - 0.5
            let b = r.next() - 0.5
            return [a, b]
        }
        var bias = [Double](repeating: 0, count: units)
        var dec = enc
        for _ in 0..<epochs {
            for x in data {
                let xs = [x.0, x.1]
                var f = [Double](repeating: 0, count: units)
                for j in 0..<units { f[j] = max(0.0, enc[j][0] * xs[0] + enc[j][1] * xs[1] + bias[j]) }
                var out = [0.0, 0.0]
                for i in 0..<2 {
                    var s = 0.0
                    for j in 0..<units { s += f[j] * dec[j][i] }
                    out[i] = s
                }
                let err = [out[0] - xs[0], out[1] - xs[1]]
                for j in 0..<units {
                    let g = (0.0 + 2 * err[0] * dec[j][0]) + 2 * err[1] * dec[j][1] + lambda
                    for i in 0..<2 { dec[j][i] -= rate * 2 * err[i] * f[j] }
                    if f[j] > 0 {
                        for i in 0..<2 { enc[j][i] -= rate * g * xs[i] }
                        bias[j] -= rate * g
                    }
                }
                for j in 0..<units {
                    var norm = hypot(dec[j][0], dec[j][1])
                    if norm == 0 { norm = 1 }
                    dec[j] = [dec[j][0] / norm, dec[j][1] / norm]
                }
            }
        }
        var counts = [Int](repeating: 0, count: units)
        var active = 0
        var error = 0.0
        for x in data {
            var f = [Double](repeating: 0, count: units)
            for j in 0..<units { f[j] = max(0.0, enc[j][0] * x.0 + enc[j][1] * x.1 + bias[j]) }
            var out = [0.0, 0.0]
            for i in 0..<2 {
                var s = 0.0
                for j in 0..<units { s += f[j] * dec[j][i] }
                out[i] = s
            }
            let e0 = out[0] - x.0, e1 = out[1] - x.1
            error += e0 * e0 + e1 * e1
            for j in 0..<units where f[j] > 0 {
                active += 1
                counts[j] += 1
            }
        }
        let alive = counts.map { $0 > 0 }
        let found = features.filter { t in
            let best = dec.indices.filter { alive[$0] }.map { abs(dec[$0][0] * t.0 + dec[$0][1] * t.1) }.max() ?? 0
            return best > 0.95
        }.count
        return Result(decoder: dec.map { ($0[0], $0[1]) }, alive: alive, error: error / Double(data.count),
                      activePerPoint: Double(active) / Double(data.count), found: found)
    }
}

/// The trained 3-6-1 network of «Цепи», weights rounded to two decimals exactly as in the lesson's program.
enum TinyCircuit {
    static let w1: [[Double]] = [[-0.41, -2.2, -0.43], [1.82, 0.12, -4.26], [7.17, 5.53, -6.76], [-5.11, -6.79, 0.97], [-3.08, -5.17, -1.24], [4.92, -5.38, -0.43]]
    static let b1: [Double] = [-0.27, 1.56, -3.05, 1.45, 2.75, -2.7]
    static let w2: [Double] = [-1.49, -4.86, -13.85, -9.6, -6.43, 5.87]
    static let b2 = 7.26
    static let inputs: [[Double]] = [0, 1].flatMap { a in [0, 1].flatMap { b in [0, 1].map { c in [Double(a), Double(b), Double(c)] } } }

    static func target(_ x: [Double]) -> Bool { (x[0] != x[1]) && x[2] == 1 }
    static func sig(_ z: Double) -> Double { 1 / (1 + exp(-z)) }

    static func hidden(_ x: [Double]) -> [Double] {
        (0..<6).map { j in
            var s = 0.0
            for i in 0..<3 { s += w1[j][i] * x[i] }
            return sig(s + b1[j])
        }
    }

    static func output(_ h: [Double]) -> Double {
        var s = 0.0
        for j in 0..<6 { s += w2[j] * h[j] }
        return sig(s + b2)
    }

    static let mean: [Double] = (0..<6).map { j in inputs.map { hidden($0)[j] }.reduce(0, +) / 8 }

    /// Output for an input when only the neurons in `keep` stay on; the others give their mean.
    static func output(_ x: [Double], keep: Set<Int>) -> Double {
        let h = hidden(x).enumerated().map { keep.contains($0.offset) ? $0.element : mean[$0.offset] }
        return output(h)
    }

    static func accuracy(keep: Set<Int>) -> Int { inputs.filter { (output($0, keep: keep) > 0.5) == target($0) }.count }

    static let clean: [Double] = [1, 0, 1]
    static let corrupt: [Double] = [1, 1, 1]

    /// Output on the corrupted input with one neuron's activation taken from the clean run.
    static func patched(_ neuron: Int) -> Double {
        var h = hidden(corrupt)
        h[neuron] = hidden(clean)[neuron]
        return output(h)
    }
}

/// «21 палочка»: take 1, 2 or 3, whoever takes the last one wins. Exact answer and MCTS as in «Планирование».
enum StickGame {
    static let win: [Bool] = {
        var table = [false]
        for n in 1...21 { table.append([1, 2, 3].contains { $0 <= n && !table[n - $0] }) }
        return table
    }()

    static func perfectMoves(_ n: Int) -> [Int] { [1, 2, 3].filter { $0 <= n && !win[n - $0] } }
    static var winningPiles: [Int] { (5...21).filter { win[$0] } }

    static func rollout(_ start: Int, _ rand: inout LFRand) -> Bool {
        var n = start
        var mover = true
        while true {
            let take = 1 + Int(rand.next() * Double(min(3, n)))
            n -= take
            if n == 0 { return mover }
            mover.toggle()
        }
    }

    /// Returns the chosen move and how often each move's pile was visited.
    static func mcts(_ n: Int, simulations: Int, seed: UInt64, c: Double = 1.4) -> (move: Int, visits: [Int: Int]) {
        var rand = LFRand(state: seed)
        var visits: [Int: Int] = [:]
        var wins: [Int: Double] = [:]
        for _ in 0..<simulations {
            var path: [Int] = []
            var node = n
            while node > 0, let total = visits[node] {
                var best = -1
                var bestKey = (-Double.infinity, Int.min)
                for take in 1...3 where take <= node {
                    let child = node - take
                    let score: Double
                    if child == 0 || visits[child] == nil {
                        score = .infinity
                    } else {
                        let v = Double(visits[child] ?? 0)
                        score = (1 - (wins[child] ?? 0) / v) + c * (log(Double(total)) / v).squareRoot()
                    }
                    let key = (score, -child)
                    if best == -1 || key > bestKey { best = child; bestKey = key }
                }
                path.append(node)
                node = best
            }
            var moverWon: Bool
            if node == 0 {
                moverWon = false
            } else {
                visits[node] = 0
                wins[node] = 0
                moverWon = rollout(node, &rand)
            }
            path.append(node)
            for state in path.reversed() {
                if state == 0 { moverWon.toggle(); continue }
                visits[state, default: 0] += 1
                wins[state, default: 0] += moverWon ? 1 : 0
                moverWon.toggle()
            }
        }
        var counts: [Int: Int] = [:]
        var chosen = 1
        var chosenKey = (false, -1)
        for take in 1...3 where take <= n {
            let child = n - take
            counts[take] = visits[child] ?? 0
            let key = (child == 0, visits[child] ?? 0)
            if chosenKey.1 == -1 || (key.0 && !chosenKey.0) || (key.0 == chosenKey.0 && key.1 > chosenKey.1) { chosen = take; chosenKey = key }
        }
        return (chosen, counts)
    }

    /// For each pile from 5 to 21: did MCTS with this many simulations pick a perfect move? Losing piles are nil.
    static func results(simulations: Int) -> [Int: Bool] {
        var map: [Int: Bool] = [:]
        for n in winningPiles { map[n] = perfectMoves(n).contains(mcts(n, simulations: simulations, seed: UInt64(n)).move) }
        return map
    }
}

/// A tanh network that learns x₁ + x₂ on a square [0, high]², as in «Открытые задачи на пути к AGI».
enum AdditionNet {
    struct Trained {
        let w1: [[Double]]
        let b1: [Double]
        let w2: [Double]
        let b2: Double
        let near: [(Double, Double)]
        let far: [(Double, Double)]

        func predict(_ x: (Double, Double)) -> Double {
            var s = 0.0
            for j in 0..<w2.count { s += w2[j] * tanh(w1[j][0] * x.0 + w1[j][1] * x.1 + b1[j]) }
            return s + b2
        }

        func error(_ points: [(Double, Double)]) -> Double {
            var s = 0.0
            for x in points {
                let e = predict(x) - (x.0 + x.1)
                s += e * e
            }
            return s / Double(points.count)
        }
    }

    static let trainingRanges: [Double] = [1, 1.5, 2, 2.5]

    static func train(high: Double) -> Trained {
        var rand = LFRand(state: 2)
        func make(_ low: Double, _ top: Double, _ count: Int) -> [(Double, Double)] {
            (0..<count).map { _ in
                let a = low + (top - low) * rand.next()
                let b = low + (top - low) * rand.next()
                return (a, b)
            }
        }
        let data = make(0, high, 200)
        let near = make(0, 1, 100)
        let far = make(1, 2, 100)
        var w1: [[Double]] = (0..<8).map { _ in
            let a = rand.next() - 0.5
            let b = rand.next() - 0.5
            return [a, b]
        }
        var b1 = [Double](repeating: 0, count: 8)
        var w2: [Double] = (0..<8).map { _ in rand.next() - 0.5 }
        var b2 = 0.0
        for _ in 0..<300 {
            for x in data {
                var h = [Double](repeating: 0, count: 8)
                for j in 0..<8 { h[j] = tanh(w1[j][0] * x.0 + w1[j][1] * x.1 + b1[j]) }
                var y = 0.0
                for j in 0..<8 { y += w2[j] * h[j] }
                y += b2
                let d = y - (x.0 + x.1)
                for j in 0..<8 {
                    let g = d * w2[j] * (1 - h[j] * h[j])
                    w2[j] -= 0.02 * d * h[j]
                    w1[j][0] -= 0.02 * g * x.0
                    w1[j][1] -= 0.02 * g * x.1
                    b1[j] -= 0.02 * g
                }
                b2 -= 0.02 * d
            }
        }
        return Trained(w1: w1, b1: b1, w2: w2, b2: b2, near: near, far: far)
    }
}

/// Ten neurons with feedback; a "chip" computes the same function by another formula, as in «Биология или функция».
enum ReplacementBrain {
    static let weights: [[Double]] = {
        var rand = LFRand(state: 4)
        return (0..<10).map { _ in (0..<10).map { _ in (rand.next() - 0.5) * 3 } }
    }()

    static func neuron(_ z: Double) -> Double { 1 / (1 + exp(-z)) }
    static func chip(_ z: Double) -> Double { 0.5 * (1 + tanh(z / 2)) }

    /// Output of neuron 9 over 12 steps when the first `chips` neurons are chips.
    static func run(chips: Int, steps: Int = 12) -> [Double] {
        var x = [Double](repeating: 0, count: 10)
        var trace: [Double] = []
        for t in 0..<steps {
            var next = [Double](repeating: 0, count: 10)
            for j in 0..<10 {
                var z = 0.0
                for i in 0..<10 { z += weights[j][i] * x[i] }
                z += (t == 0 && j == 0) ? 2.0 : 0.0
                next[j] = j < chips ? chip(z) : neuron(z)
            }
            x = next
            trace.append(x[9])
        }
        return trace
    }

    static func largestDifference(chips: Int) -> Double {
        zip(run(chips: 0), run(chips: chips)).map { abs($0 - $1) }.max() ?? 0
    }
}

/// A preregistered hypothesis about confidence, tested by the bootstrap on the 20 recorded answers, as in «Что можешь сделать ты».
enum Preregistration {
    /// Confidence and correctness of the 20 answers of qwen2.5-coder:7b from «Как модель ошибается».
    static let data: [(Double, Int)] = [(0.869, 1), (0.945, 1), (0.936, 1), (0.795, 0), (0.898, 1), (0.988, 1), (0.998, 1), (0.991, 1),
                                        (0.344, 0), (0.631, 0), (0.36, 0), (0.559, 0), (0.602, 0), (0.737, 1), (0.771, 0), (0.877, 0),
                                        (0.89, 0), (0.896, 1), (0.994, 0), (0.964, 0)]

    static func gap(_ rows: [(Double, Int)], cut: Double) -> Double? {
        let high = rows.filter { $0.0 >= cut }.map(\.1)
        let low = rows.filter { $0.0 < cut }.map(\.1)
        guard !high.isEmpty, !low.isEmpty else { return nil }
        return Double(high.reduce(0, +)) / Double(high.count) - Double(low.reduce(0, +)) / Double(low.count)
    }

    /// 95 % interval of the difference; `copies` repeats the data to show how the interval narrows with more answers.
    static func interval(cut: Double, copies: Int = 1, draws: Int = 2000, seed: UInt64 = 9) -> (low: Double, high: Double) {
        let rows = Array(repeating: data, count: copies).flatMap { $0 }
        var rand = LFRand(state: seed)
        var gaps: [Double] = []
        for _ in 0..<draws {
            let sample = rows.indices.map { _ in rows[Int(rand.next() * Double(rows.count))] }
            if let value = gap(sample, cut: cut) { gaps.append(value) }
        }
        gaps.sort()
        return (gaps[Int(0.025 * Double(gaps.count))], gaps[Int(0.975 * Double(gaps.count))])
    }
}

/// SVD of a 2 × 2 matrix in closed form, for «SVD и малоранговые матрицы».
enum SVD2 {
    /// Singular values (largest first) and the right singular vectors for [[a, b], [c, d]].
    static func decompose(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> (s1: Double, s2: Double, v1: (Double, Double), v2: (Double, Double)) {
        let p = a * a + c * c
        let q = a * b + c * d
        let r = b * b + d * d
        let mean = (p + r) / 2
        let spread = ((p - r) * (p - r) / 4 + q * q).squareRoot()
        let l1 = mean + spread
        let l2 = max(0, mean - spread)
        let angle = 0.5 * atan2(2 * q, p - r)
        let v1 = (cos(angle), sin(angle))
        let v2 = (-sin(angle), cos(angle))
        return (l1.squareRoot(), l2.squareRoot(), v1, v2)
    }
}

/// The map f(x₁, x₂) = (x₁² − x₂, x₁ · x₂) and its Jacobian, for «Матричные производные и якобианы».
enum JacobianMap {
    static func f(_ x: (Double, Double)) -> (Double, Double) { (x.0 * x.0 - x.1, x.0 * x.1) }
    static func jacobian(_ x: (Double, Double)) -> [[Double]] { [[2 * x.0, -1], [x.1, x.0]] }
    static func determinant(_ x: (Double, Double)) -> Double { 2 * x.0 * x.0 + x.1 }

    /// The layer of the lesson's program: y = tanh(W x) with its Jacobian diag(1 − y²) · W.
    static let w: [[Double]] = [[0.5, -1.0], [2.0, 0.3], [-0.7, 0.8]]
    static func layerJacobian(_ x: [Double]) -> [[Double]] {
        w.map { row in
            let z = row[0] * x[0] + row[1] * x[1]
            let t = tanh(z)
            return row.map { (1 - t * t) * $0 }
        }
    }
}

/// The Hodgkin–Huxley squid-axon model with rest near −65 mV, integrated as in the lesson's program.
enum HodgkinHuxley {
    static func rates(_ v: Double) -> (an: Double, bn: Double, am: Double, bm: Double, ah: Double, bh: Double) {
        (0.01 * (v + 55) / (1 - exp(-(v + 55) / 10)), 0.125 * exp(-(v + 65) / 80),
         0.1 * (v + 40) / (1 - exp(-(v + 40) / 10)), 4.0 * exp(-(v + 65) / 18),
         0.07 * exp(-(v + 65) / 20), 1 / (1 + exp(-(v + 35) / 10)))
    }

    /// Voltage every 0.01 ms over 50 ms, with a constant current from 5 ms on, and the number of spikes.
    static func simulate(current: Double, ms: Double = 50, dt: Double = 0.01) -> (trace: [Double], spikes: Int) {
        var v = -65.0
        var r = rates(v)
        var n = r.an / (r.an + r.bn), m = r.am / (r.am + r.bm), h = r.ah / (r.ah + r.bh)
        var trace: [Double] = []
        var spikes = 0
        var above = false
        for step in 0..<Int(ms / dt) {
            r = rates(v)
            let iNa = 120.0 * m * m * m * h * (v - 50.0)
            let iK = 36.0 * n * n * n * n * (v + 77.0)
            let iL = 0.3 * (v + 54.387)
            let drive = Double(step) * dt >= 5 ? current : 0.0
            v += dt * (drive - iNa - iK - iL) / 1.0
            n += dt * (r.an * (1 - n) - r.bn * n)
            m += dt * (r.am * (1 - m) - r.bm * m)
            h += dt * (r.ah * (1 - h) - r.bh * h)
            if v > 0 && !above { spikes += 1 }
            above = v > 0
            trace.append(v)
        }
        return (trace, spikes)
    }

    /// Four ways to measure the brain: time and space resolution as orders of magnitude, in seconds and metres.
    static let methods: [(key: String, time: Double, space: Double)] = [
        ("eeg", 0.001, 0.01), ("fmri", 2, 0.002), ("patch", 0.0001, 0.00001), ("neuropixels", 0.0001, 0.00002),
    ]
}

/// From loops to matrices: measurements on this M1 on 2026-11-08 (system python3 3.9.6, NumPy 2.0.2 with Accelerate)
/// and a rough "call plus arithmetic" model with two numbers.
/// От циклов к матрицам: замеры на этом M1 8 ноября 2026 и грубая модель «вызов плюс счёт».
enum LoopsMatrices {
    static let measuredSizes: [Int] = [16, 32, 64, 128, 256]
    static let loopMilliseconds: [Double] = [0.128, 0.801, 5.736, 42.816, 326.877]
    static let numpyMilliseconds: [Double] = [0.001, 0.0013, 0.003, 0.0142, 0.0976]
    static let measuredTimesFaster: [Int] = [133, 620, 1912, 3005, 3348]
    static let sliderSizes: [Int] = [8, 16, 32, 64, 128, 256, 512]
    static let loopSecondsPerMultiply = 19.5e-9
    static let callSeconds = 1.0e-6
    static let multipliesPerSecond = 1.7e11
    static let plainTrainingMinutes = 47.2
    static let numpyTrainingSeconds = 22.0

    static func multiplications(_ n: Int) -> Double { pow(Double(n), 3) }
    static func loopSeconds(_ n: Int) -> Double { multiplications(n) * loopSecondsPerMultiply }
    static func computeSeconds(_ n: Int) -> Double { multiplications(n) / multipliesPerSecond }
    static func numpySeconds(_ n: Int) -> Double { callSeconds + computeSeconds(n) }
    static func computeShare(_ n: Int) -> Double { computeSeconds(n) / numpySeconds(n) }
    static func timesFaster(_ n: Int) -> Double { loopSeconds(n) / numpySeconds(n) }

    /// The smallest size where most of NumPy's time is arithmetic, not the call.
    static var firstComputeBound: Int { sliderSizes.first { computeShare($0) > 0.5 } ?? 512 }
    static var trainingTimesFaster: Double { plainTrainingMinutes * 60 / numpyTrainingSeconds }
}

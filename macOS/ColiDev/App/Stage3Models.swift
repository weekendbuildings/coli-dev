import Foundation

/// A word-pair language model, a reward model and the shift by REINFORCE, as in the RLHF lesson's program.
/// Модель пар слов, модель награды и сдвиг через REINFORCE, как в программе урока о RLHF.
enum PreferenceModel {
    typealias Table = [[Double]]

    struct Point: Equatable {
        let update: Int
        let reward: Double
        let person: Double
        let different: Int
        let length: Double
    }

    static let corpus = "кот ест рыбу\nспасибо кот ест рыбу\nпёс ищет дом\nплохой пёс ест кашу\nдурак ищет кашу\nмама любит кота\nспасибо мама любит кота\nпапа несёт воду\nпожалуйста несёт воду папа\nдобрый дед несёт кашу\nплохой дед ищет рыбу\nдурак несёт воду\nгусь ест траву\nдобрый гусь ищет дом\nпожалуйста кот несёт рыбу\nочень добрый пёс любит маму\nочень плохой гусь ест кашу".components(separatedBy: "\n")
    static let words: [String] = ["воду", "гусь", "дед", "добрый", "дом", "дурак", "ест", "ищет", "кашу", "кот", "кота", "любит", "мама", "маму", "несёт", "очень", "папа", "плохой", "пожалуйста", "пёс", "рыбу", "спасибо", "траву", "."]
    static let stop = words.count - 1
    static let start = words.count
    static let good: Set<String> = ["спасибо", "пожалуйста", "добрый"]
    static let bad: Set<String> = ["дурак", "плохой"]

    static func index(_ word: String) -> Int { words.firstIndex(of: word) ?? 0 }

    static let startTable: Table = {
        var table = Table(repeating: [Double](repeating: 0.1, count: words.count), count: words.count + 1)
        for line in corpus {
            var previous = start
            for word in line.components(separatedBy: " ") + ["."] {
                table[previous][index(word)] += 1
                previous = index(word)
            }
        }
        return table.map { row in
            let total = row.reduce(0, +)
            return row.map { log($0 / total) }
        }
    }()

    static func probabilities(_ row: [Double]) -> [Double] {
        let top = row.max() ?? 0
        let weights = row.map { exp($0 - top) }
        let total = weights.reduce(0, +)
        return weights.map { $0 / total }
    }

    static func sample(_ table: Table, _ rand: inout RLRand, limit: Int = 10) -> [String] {
        var previous = start
        var result: [String] = []
        while result.count < limit {
            let p = probabilities(table[previous])
            let pick = rand.next()
            var total = 0.0
            var chosen = p.count - 1
            for (word, q) in p.enumerated() {
                total += q
                if pick <= total {
                    chosen = word
                    break
                }
            }
            if chosen == stop { break }
            result.append(words[chosen])
            previous = chosen
        }
        return result
    }

    /// The stand-in for a person from the lesson's program. / Замена человека из программы урока.
    static func person(_ sentence: [String]) -> Int {
        var score = 0
        for word in sentence {
            if good.contains(word) { score += 1 }
            if bad.contains(word) { score -= 1 }
        }
        return score - 2 * (sentence.count - Set(sentence).count)
    }

    static func reward(_ sentence: [String], _ weight: [String: Double]) -> Double {
        var total = 0.0
        for word in sentence { total += weight[word] ?? 0 }
        return total
    }

    static func fitReward(_ pairs: [(better: [String], worse: [String])], epochs: Int = 60) -> [String: Double] {
        var weight: [String: Double] = [:]
        for word in words { weight[word] = 0 }
        for _ in 0..<epochs {
            for pair in pairs {
                let chance = 1 / (1 + exp(reward(pair.worse, weight) - reward(pair.better, weight)))
                for word in pair.better { weight[word, default: 0] += 0.02 * (1 - chance) }
                for word in pair.worse { weight[word, default: 0] -= 0.02 * (1 - chance) }
            }
        }
        return weight
    }

    /// The pairs of the lesson's program. / Пары из программы урока.
    static func lessonPairs() -> [(better: [String], worse: [String])] {
        var rand = RLRand(5)
        for _ in 0..<5 { _ = sample(startTable, &rand) }
        var pairs: [(better: [String], worse: [String])] = []
        for _ in 0..<200 {
            let first = sample(startTable, &rand)
            let second = sample(startTable, &rand)
            if person(first) != person(second) {
                pairs.append(person(first) > person(second) ? (first, second) : (second, first))
            }
        }
        return pairs
    }

    static func shift(_ weight: [String: Double], updates: Int = 2000, rate: Double = 0.02, klWeight: Double, seed: UInt64 = 6) -> (log: [Point], tables: [Table]) {
        var table = startTable
        var rand = RLRand(seed)
        var base = 0.0
        var log: [Point] = []
        var tables: [Table] = []
        for update in 0...updates {
            if update % 200 == 0 {
                var check = RLRand(77)
                var texts: [[String]] = []
                for _ in 0..<300 { texts.append(sample(table, &check)) }
                let rewards = texts.reduce(0.0) { $0 + reward($1, weight) }
                let persons = texts.reduce(0) { $0 + person($1) }
                let lengths = texts.reduce(0) { $0 + $1.count }
                log.append(Point(update: update, reward: rewards / 300, person: Double(persons) / 300,
                                 different: Set(texts.map { $0.joined(separator: " ") }).count, length: Double(lengths) / 300))
                tables.append(table)
            }
            let sentence = sample(table, &rand)
            var chain = [start]
            for word in sentence { chain.append(index(word)) }
            var targets = Array(chain.dropFirst())
            var previous = chain
            if sentence.count < 10 {
                targets.append(stop)
            } else {
                previous.removeLast()
            }
            var penalty = 0.0
            for (from, to) in zip(previous, targets) {
                penalty += Foundation.log(probabilities(table[from])[to]) - Foundation.log(probabilities(startTable[from])[to])
            }
            let score = reward(sentence, weight) - klWeight * penalty
            base += 0.05 * (score - base)
            for (from, to) in zip(previous, targets) {
                let p = probabilities(table[from])
                for word in 0..<words.count {
                    let one: Double = word == to ? 1 : 0
                    table[from][word] += rate * (score - base) * (one - p[word])
                }
            }
        }
        return (log, tables)
    }
}

/// Equally good models on a noisy test: the winner looks better than it is.
/// Одинаково хорошие модели на шумном тесте: победитель кажется лучше, чем он есть.
enum WinnerCurse {
    static let truth = 0.7

    static func score(testSize: Int, rand: inout RLRand) -> Double {
        var hits = 0
        for _ in 0..<testSize where rand.next() < truth { hits += 1 }
        return Double(hits) / Double(testSize)
    }

    static func winner(models: Int, testSize: Int, rand: inout RLRand) -> Double {
        var best = 0.0
        for _ in 0..<models { best = max(best, score(testSize: testSize, rand: &rand)) }
        return best
    }

    static func meanWinner(models: Int, testSize: Int, repeats: Int = 40, seed: UInt64 = 21) -> Double {
        var rand = RLRand(seed)
        var total = 0.0
        for _ in 0..<repeats { total += winner(models: models, testSize: testSize, rand: &rand) }
        return total / Double(repeats)
    }

    static func wilson(hits: Int, count: Int, z: Double = 1.96) -> (low: Double, high: Double) {
        let n = Double(count)
        let p = Double(hits) / n
        let middle: Double = (p + z * z / (2 * n)) / (1 + z * z / n)
        let half: Double = z * (p * (1 - p) / n + z * z / (4 * n * n)).squareRoot() / (1 + z * z / n)
        return (middle - half, middle + half)
    }
}

/// The toy model of superposition, trained by Adam as in the lesson's program.
/// Игрушечная модель суперпозиции, обучение через Adam как в программе урока.
struct SuperpositionTrainer {
    let features: Int
    let dims: Int
    let sparsity: Double
    private(set) var step = 0
    private var w: [[Double]]
    private var b: [Double]
    private var m1: [[Double]]
    private var m2: [[Double]]
    private var rand: RLRand
    private let batch = 16
    private let rate = 0.01

    init(features: Int, dims: Int, sparsity: Double, seed: UInt64) {
        self.features = features
        self.dims = dims
        self.sparsity = sparsity
        rand = RLRand(seed)
        var source = rand
        w = (0..<dims).map { _ in (0..<features).map { _ in (source.next() - 0.5) * 0.6 } }
        rand = source
        b = [Double](repeating: 0, count: features)
        m1 = [[Double]](repeating: [Double](repeating: 0, count: features), count: dims + 1)
        m2 = m1
    }

    mutating func run(steps: Int) {
        for _ in 0..<steps {
            step += 1
            var gw = [[Double]](repeating: [Double](repeating: 0, count: features), count: dims)
            var gb = [Double](repeating: 0, count: features)
            var x = [Double](repeating: 0, count: features)
            var hidden = [Double](repeating: 0, count: dims)
            var error = [Double](repeating: 0, count: features)
            for _ in 0..<batch {
                for i in 0..<features {
                    let alive = rand.next() > sparsity
                    x[i] = alive ? rand.next() : 0
                }
                for d in 0..<dims {
                    var sum = 0.0
                    for i in 0..<features { sum += w[d][i] * x[i] }
                    hidden[d] = sum
                }
                for i in 0..<features {
                    var out = b[i]
                    for d in 0..<dims { out += w[d][i] * hidden[d] }
                    error[i] = out > 0 ? out - x[i] : 0
                }
                for d in 0..<dims {
                    var back = 0.0
                    for i in 0..<features { back += w[d][i] * error[i] }
                    for i in 0..<features { gw[d][i] += 2 * (error[i] * hidden[d] + back * x[i]) / Double(batch) }
                }
                for i in 0..<features { gb[i] += 2 * error[i] / Double(batch) }
            }
            let fix1: Double = 1 - pow(0.9, Double(step))
            let fix2: Double = 1 - pow(0.999, Double(step))
            for row in 0...dims {
                for i in 0..<features {
                    let g = row < dims ? gw[row][i] : gb[i]
                    m1[row][i] = 0.9 * m1[row][i] + 0.1 * g
                    m2[row][i] = 0.999 * m2[row][i] + 0.001 * g * g
                    let change: Double = rate * (m1[row][i] / fix1) / ((m2[row][i] / fix2).squareRoot() + 1e-8)
                    if row < dims { w[row][i] -= change } else { b[i] -= change }
                }
            }
        }
    }

    /// One vector per feature. / По одному вектору на признак.
    var vectors: [[Double]] {
        (0..<features).map { i in (0..<dims).map { d in w[d][i] } }
    }

    static func length(_ vector: [Double]) -> Double {
        vector.reduce(0) { $0 + $1 * $1 }.squareRoot()
    }

    var aliveCount: Int { vectors.filter { Self.length($0) > 0.5 }.count }
}

/// A straight line through two points that splits the recorded activations.
/// Прямая через две точки, которая делит записанные активации.
enum ProbeGeometry {
    static func accuracy(points: [(x: Double, y: Double, label: Bool)], from a: (x: Double, y: Double), to b: (x: Double, y: Double)) -> Double {
        guard !points.isEmpty else { return 0 }
        var right = 0
        for point in points {
            let side: Double = (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)
            if (side > 0) == point.label { right += 1 }
        }
        let share = Double(right) / Double(points.count)
        return max(share, 1 - share)
    }
}

import Foundation

/// The lesson's attention model: it continues repeating patterns of four symbols, trained by gradient descent with the
/// lesson's backward pass. The start comes from the same simple generator as the lesson's program, so the numbers match.
/// Модель внимания из урока: продолжает повторяющиеся узоры из четырёх символов. Начало задаёт тот же простой генератор,
/// что в программе урока, поэтому числа совпадают.
struct PatternAttentionModel: Equatable {
    enum Phase: Equatable {
        case ready, training, learned, stuck, outOfSteps
    }

    static let symbols = 4
    static let length = 8
    static let vectorLength = 4
    static let tableRows = 8
    static let trainCount = 32
    static let unseenCount = 100
    static let rate = 1.0
    static let weightSeed = 4242
    static let dataSeed = 777
    static let periods = 1...4
    static let stepLimit = 800
    /// The task: at least this share of right answers on new patterns.
    static let goalAccuracy = 0.95
    static let stallChange = 2e-3
    static let stallWindow = 40
    static let letters = ["A", "B", "C", "D"]

    private(set) var period: Int
    private(set) var usesPositions: Bool
    private(set) var query: [[Double]]
    private(set) var key: [[Double]]
    private(set) var value: [[Double]]
    private(set) var output: [[Double]]
    private(set) var train: [[Int]]
    private(set) var unseen: [[Int]]
    private(set) var history: [Double] = []
    /// Kept after each step, since the scene and the texts read them many times per frame.
    /// Хранятся после каждого шага, потому что сцена и тексты читают их много раз за кадр.
    private(set) var accuracy = 0.0
    private(set) var loss = 0.0

    /// The table entries are in the order of the lesson's program, so both draw the same numbers.
    init(period: Int = 3, usesPositions: Bool = false) {
        self.period = period
        self.usesPositions = usesPositions
        var state = Self.weightSeed
        func next() -> Double {
            state = state * 16807 % 2147483647
            return Double(state) / 2147483647
        }
        func table(_ rows: Int) -> [[Double]] {
            var built: [[Double]] = []
            for _ in 0..<rows {
                var row: [Double] = []
                for _ in 0..<Self.vectorLength { row.append(next() - 0.5) }
                built.append(row)
            }
            return built
        }
        query = table(Self.tableRows)
        key = table(Self.tableRows)
        value = table(Self.symbols)
        output = table(Self.symbols)
        state = Self.dataSeed
        func patterns(_ count: Int) -> [[Int]] {
            var built: [[Int]] = []
            for _ in 0..<count {
                var pattern: [Int] = []
                for _ in 0..<period { pattern.append(Int(next() * Double(Self.symbols))) }
                built.append((0..<Self.length).map { pattern[$0 % period] })
            }
            return built
        }
        train = patterns(Self.trainCount)
        unseen = patterns(Self.unseenCount)
        refreshResults()
    }

    static func == (left: Self, right: Self) -> Bool {
        left.query == right.query && left.key == right.key && left.period == right.period && left.usesPositions == right.usesPositions
    }

    private static func dot(_ a: [Double], _ b: [Double]) -> Double {
        var total = 0.0
        for i in a.indices { total += a[i] * b[i] }
        return total
    }

    static func softmax(_ scores: [Double]) -> [Double] {
        let top = scores.max() ?? 0
        let powers = scores.map { exp($0 - top) }
        let total = powers.reduce(0, +)
        return powers.map { $0 / total }
    }

    private func places(_ line: [Int], _ t: Int) -> (query: Int, keys: [Int]) {
        (usesPositions ? t : line[t], (0...t).map { usesPositions ? $0 : line[$0] })
    }

    /// The weights of the places already read: a true softmax of q · k / √d. / Веса уже прочитанных мест.
    func weights(_ line: [Int], at t: Int) -> [Double] {
        let (q, keys) = places(line, t)
        let root = Double(Self.vectorLength).squareRoot()
        return Self.softmax(keys.map { Self.dot(query[q], key[$0]) / root })
    }

    private func context(_ line: [Int], weights: [Double]) -> [Double] {
        var total = [Double](repeating: 0, count: Self.vectorLength)
        for (j, weight) in weights.enumerated() {
            for i in total.indices { total[i] += weight * value[line[j]][i] }
        }
        return total
    }

    /// The probabilities of the next symbol at place t. / Вероятности следующего символа на месте t.
    func answer(_ line: [Int], at t: Int) -> [Double] {
        let c = context(line, weights: weights(line, at: t))
        return Self.softmax(output.map { Self.dot(c, $0) })
    }

    /// Rows with a target to learn: the first period − 1 places have nothing to repeat yet.
    func hasTarget(row t: Int) -> Bool { t >= period - 1 && t < Self.length - 1 }

    /// The share of right answers on patterns the model has not seen, and the mean error on the training patterns.
    private mutating func refreshResults() {
        var right = 0, total = 0
        for line in unseen {
            for t in (period - 1)..<(Self.length - 1) {
                let q = answer(line, at: t)
                if q.indices.max(by: { q[$0] < q[$1] }) == line[t + 1] { right += 1 }
                total += 1
            }
        }
        accuracy = Double(right) / Double(total)
        var error = 0.0, count = 0.0
        for line in train {
            for t in (period - 1)..<(Self.length - 1) {
                error -= log(answer(line, at: t)[line[t + 1]])
                count += 1
            }
        }
        loss = error / count
    }

    var steps: Int { history.count }

    var phase: Phase {
        if steps == 0 { return .ready }
        if accuracy >= Self.goalAccuracy { return .learned }
        if steps >= Self.stepLimit { return .outOfSteps }
        if steps >= Self.stallWindow, abs(history[steps - Self.stallWindow] - (history.last ?? 0)) < Self.stallChange { return .stuck }
        return .training
    }

    var isFinished: Bool { steps >= Self.stepLimit }

    /// One step over all training patterns, with the backward pass of the lesson. The history keeps the error before the step.
    mutating func step() {
        guard !isFinished else { return }
        let size = Self.vectorLength
        let root = Double(size).squareRoot()
        let zero = [Double](repeating: 0, count: size)
        var gradQuery = [[Double]](repeating: zero, count: Self.tableRows)
        var gradKey = gradQuery
        var gradValue = [[Double]](repeating: zero, count: Self.symbols)
        var gradOutput = gradValue
        var total = 0.0, count = 0.0
        for line in train {
            for t in (period - 1)..<(Self.length - 1) {
                let attention = weights(line, at: t)
                let c = context(line, weights: attention)
                let q = Self.softmax(output.map { Self.dot(c, $0) })
                let target = line[t + 1]
                total -= log(q[target])
                count += 1
                var back = zero
                for m in 0..<Self.symbols {
                    let difference = q[m] - (m == target ? 1 : 0)
                    for i in 0..<size {
                        gradOutput[m][i] += difference * c[i]
                        back[i] += difference * output[m][i]
                    }
                }
                let (place, keys) = places(line, t)
                let effect = (0...t).map { Self.dot(back, value[line[$0]]) }
                let mean = Self.dot(attention, effect)
                for (j, k) in keys.enumerated() {
                    let pull = attention[j] * (effect[j] - mean) / root
                    for i in 0..<size {
                        gradValue[line[j]][i] += attention[j] * back[i]
                        gradQuery[place][i] += pull * key[k][i]
                        gradKey[k][i] += pull * query[place][i]
                    }
                }
            }
        }
        history.append(total / count)
        for r in 0..<Self.tableRows {
            for i in 0..<size {
                query[r][i] -= Self.rate * gradQuery[r][i] / count
                key[r][i] -= Self.rate * gradKey[r][i] / count
            }
        }
        for r in 0..<Self.symbols {
            for i in 0..<size {
                value[r][i] -= Self.rate * gradValue[r][i] / count
                output[r][i] -= Self.rate * gradOutput[r][i] / count
            }
        }
        refreshResults()
    }

    /// For the task: learned the longer patterns on new data, with place numbers. / Для задания: выучены длинные узоры на новых данных.
    var solvesChallenge: Bool { usesPositions && period >= 3 && steps > 0 && accuracy >= Self.goalAccuracy }
}

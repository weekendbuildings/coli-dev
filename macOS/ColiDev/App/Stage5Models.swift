import Foundation

/// The agent that says it hurts, as in the lesson on the hard problem.
/// Агент, который говорит, что ему больно, как в уроке о трудной проблеме.
struct PainAgent {
    static let places = ["floor", "stove"]
    private(set) var avoid: [String: Double] = ["floor": 0, "stove": 0]
    private(set) var damage = 0.0

    mutating func touch(_ place: String) {
        let signal: Double = place == "stove" ? 1 : 0
        damage += signal
        avoid[place, default: 0] += 0.5 * (signal - (avoid[place] ?? 0))
    }

    var hurts: Bool { damage > 0 }

    var choice: String { (avoid["stove"] ?? 0) < (avoid["floor"] ?? 0) ? "stove" : "floor" }
}

/// A small global workspace: self-sustaining activity through feedback.
/// Маленькое глобальное рабочее пространство: активность поддерживает себя через обратную связь.
enum WorkspaceModel {
    private static let feedback = 2.4
    private static let decay = 0.7
    private static let gain = 6.0
    private static let threshold = 0.8

    private static func squash(_ x: Double) -> Double { 1 / (1 + exp(-gain * (x - threshold))) }

    private static func noise(_ rand: inout RLRand) -> Double {
        var total = 0.0
        for _ in 0..<12 { total += rand.next() }
        return total - 6
    }

    static func trial(strength: Double, rand: inout RLRand, steps: Int = 12, noiseSize: Double = 0.08) -> [Double] {
        var workspace = 0.0
        var trace: [Double] = []
        for step in 0..<steps {
            let pushed: Double = step < 2 ? strength : 0
            let drive: Double = pushed + feedback * workspace * decay + noiseSize * noise(&rand)
            workspace = squash(drive)
            trace.append(workspace)
        }
        return trace
    }

    static func ignitionShare(strength: Double, trials: Int = 200, rand: inout RLRand) -> Double {
        var lit = 0
        for _ in 0..<trials where (trial(strength: strength, rand: &rand).last ?? 0) > 0.5 { lit += 1 }
        return Double(lit) / Double(trials)
    }
}

/// A simplified measure of integration on three nodes. It is not IIT's Φ.
/// Упрощённая мера интеграции на трёх узлах. Это не Φ из теории интегрированной информации.
enum IntegrationModel {
    enum Gate: String, CaseIterable {
        case keep, previous, next, and, xor, majority
    }

    typealias State = [Int]

    static func output(_ gate: Gate, node: Int, state: State) -> Int {
        let first = state[(node + 1) % 3]
        let second = state[(node + 2) % 3]
        switch gate {
        case .keep: return state[node]
        case .previous: return second
        case .next: return first
        case .and: return first & second
        case .xor: return first ^ second
        case .majority: return state[0] + state[1] + state[2] >= 2 ? 1 : 0
        }
    }

    private static let states: [State] = (0..<8).map { [$0 >> 2 & 1, $0 >> 1 & 1, $0 & 1] }

    private static func chance(_ gates: [Gate], part: [Int], state: State, wanted: [Int]) -> Double {
        let others = (0..<3).filter { !part.contains($0) }
        let count = 1 << others.count
        var hits = 0
        for choice in 0..<count {
            var filled = state
            for (position, node) in others.enumerated() { filled[node] = choice >> position & 1 }
            var same = true
            for (position, node) in part.enumerated() where output(gates[node], node: node, state: filled) != wanted[position] {
                same = false
            }
            if same { hits += 1 }
        }
        return Double(hits) / Double(count)
    }

    /// Bits lost by cutting one node from the other two. / Биты, потерянные при отделении одного узла от двух других.
    static func loss(_ gates: [Gate], cutNode: Int) -> Double {
        let rest = (0..<3).filter { $0 != cutNode }
        var total = 0.0
        for state in states {
            let real = (0..<3).map { output(gates[$0], node: $0, state: state) }
            let first = chance(gates, part: [cutNode], state: state, wanted: [real[cutNode]])
            let second = chance(gates, part: rest, state: state, wanted: rest.map { real[$0] })
            let both = first * second
            total += both > 0 ? log2(1 / both) : 3
        }
        return total / 8
    }

    static func weakestCut(_ gates: [Gate]) -> Double {
        (0..<3).map { loss(gates, cutNode: $0) }.min() ?? 0
    }
}

/// A small overconfident classifier and its reliability, as in the lesson's program.
/// Маленький самоуверенный классификатор и его надёжность, как в программе урока.
struct ConfidenceModel {
    typealias Point = (x: Double, y: Double, label: Int)
    private(set) var weights = [Double](repeating: 0, count: 6)
    private(set) var bias = 0.0
    let check: [Point]

    private static func sample(count: Int, seed: UInt64) -> [Point] {
        var rand = RLRand(seed)
        var out: [Point] = []
        for _ in 0..<count {
            let label = Int(rand.next() * 2)
            var noise = 0.0
            for _ in 0..<12 { noise += rand.next() }
            let x: Double = (label == 1 ? 1.0 : -1.0) + 1.3 * (noise - 6)
            let y: Double = rand.next() * 2 - 1
            out.append((x, y, label))
        }
        return out
    }

    private static func extras(_ x: Double, _ y: Double) -> [Double] {
        [x, y, sin(9 * x), sin(9 * y), cos(13 * x), sin(5 * x + 7 * y)]
    }

    init() {
        let train = Self.sample(count: 40, seed: 1)
        check = Self.sample(count: 1000, seed: 2)
        for _ in 0..<400 {
            for point in train {
                let f = Self.extras(point.x, point.y)
                var s = bias
                for j in 0..<6 { s += weights[j] * f[j] }
                let p: Double = 1 / (1 + exp(-max(min(s, 30), -30)))
                for j in 0..<6 { weights[j] += 0.3 * (Double(point.label) - p) * f[j] }
                bias += 0.3 * (Double(point.label) - p)
            }
        }
    }

    func score(_ point: Point) -> Double {
        let f = Self.extras(point.x, point.y)
        var s = bias
        for j in 0..<6 { s += weights[j] * f[j] }
        return s
    }

    func confidence(_ s: Double, temperature: Double) -> Double {
        let p: Double = 1 / (1 + exp(-max(min(s / temperature, 30), -30)))
        return max(p, 1 - p)
    }

    var accuracy: Double {
        var right = 0
        for point in check where (score(point) > 0) == (point.label == 1) { right += 1 }
        return Double(right) / Double(check.count)
    }

    /// Bins of confidence: count, real share right, mean confidence; and the mean gap. / Корзины уверенности: число, доля верных, средняя уверенность; и средний разрыв.
    func reliability(temperature: Double, bins: Int = 5) -> (rows: [(count: Int, accuracy: Double, confidence: Double)], gap: Double) {
        var counts = [Int](repeating: 0, count: bins)
        var rights = [Int](repeating: 0, count: bins)
        var sums = [Double](repeating: 0, count: bins)
        for point in check {
            let s = score(point)
            let c = confidence(s, temperature: temperature)
            let bin = min(Int((c - 0.5) * 2 * Double(bins)), bins - 1)
            counts[bin] += 1
            if (s > 0) == (point.label == 1) { rights[bin] += 1 }
            sums[bin] += c
        }
        var gap = 0.0
        var rows: [(count: Int, accuracy: Double, confidence: Double)] = []
        for bin in 0..<bins {
            gap += abs(Double(rights[bin]) - sums[bin])
            let n = max(counts[bin], 1)
            rows.append((counts[bin], Double(rights[bin]) / Double(n), sums[bin] / Double(n)))
        }
        return (rows, gap / Double(check.count))
    }
}

/// The cost of two errors when the chance of experience is unknown; the numbers are illustrations.
/// Цена двух ошибок при неизвестной вероятности переживания; числа только для примера.
enum TwoErrors {
    static func threshold(falseAlarm: Double, miss: Double) -> Double { falseAlarm / (falseAlarm + miss) }

    static func costs(probability: Double, falseAlarm: Double, miss: Double) -> (protect: Double, ignore: Double) {
        ((1 - probability) * falseAlarm, probability * miss)
    }
}

/// A threshold from accuracy by duration, found by trying values, with chance at one in four.
/// Порог по точности при разных длительностях, найденный перебором, случай равен одной четвёртой.
enum MaskingFit {
    static let durations = [17, 33, 50, 67, 100, 150]

    static func fit(_ rows: [(ms: Double, share: Double)]) -> (threshold: Int, slope: Int) {
        var best = (error: Double.infinity, threshold: 0, slope: 0)
        for threshold in 20...120 {
            for slope in [4, 6, 8, 10, 12, 16, 20, 25] {
                var error = 0.0
                for row in rows {
                    let model: Double = 0.25 + 0.75 / (1 + exp(-(row.ms - Double(threshold)) / Double(slope)))
                    error += (model - row.share) * (model - row.share)
                }
                if error < best.error { best = (error, threshold, slope) }
            }
        }
        return (best.threshold, best.slope)
    }
}

/// My ratings of the large local model on the report's 14 indicators, in its order; an opinion, not an expert assessment.
/// Мои оценки большой локальной модели по 14 индикаторам отчёта, в его порядке; мнение, а не оценка экспертов.
enum IndicatorJudgement {
    static let large = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.0, 0.5, 0.0, 0.0, 0.5, 0.0]
    static var sum: Double { large.reduce(0, +) }
    static var lenient: Int { large.filter { $0 > 0 }.count }
    static var strict: Int { large.filter { $0 == 1 }.count }
}

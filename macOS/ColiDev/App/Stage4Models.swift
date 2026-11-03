import Foundation

/// Three systems in eight small worlds, as in the lesson on definitions of intelligence.
/// Три системы в восьми маленьких средах, как в уроке об определениях интеллекта.
enum IntelligenceModel {
    enum System: Int, CaseIterable {
        case blind, specialist, learner
    }

    static let worlds: [(probabilities: [Double], bits: Int)] = [
        ([0.9, 0.1], 2), ([0.1, 0.9], 2), ([0.8, 0.2, 0.2], 3), ([0.2, 0.8, 0.2], 3),
        ([0.2, 0.2, 0.2, 0.8], 4), ([0.3, 0.7, 0.3, 0.3, 0.3], 5), ([0.4, 0.4, 0.4, 0.4, 0.4, 0.6], 6),
        ([0.45, 0.55, 0.45, 0.55, 0.45, 0.55, 0.45, 0.55], 8)
    ]

    private static func play(_ system: System, world: Int, steps: Int, rand: inout RLRand) -> Double {
        let probabilities = worlds[world].probabilities
        let count = probabilities.count
        var values = [Double](repeating: 0, count: count)
        var counts = [Int](repeating: 0, count: count)
        var total = 0.0
        for _ in 0..<steps {
            let arm: Int
            switch system {
            case .blind:
                arm = Int(rand.next() * Double(count))
            case .specialist:
                arm = world == 0 ? 0 : Int(rand.next() * Double(count))
            case .learner:
                if rand.next() < 0.1 {
                    arm = Int(rand.next() * Double(count))
                } else {
                    arm = values.firstIndex(of: values.max() ?? 0) ?? 0
                }
            }
            let reward: Double = rand.next() < probabilities[arm] ? 1 : 0
            if system == .learner {
                counts[arm] += 1
                values[arm] += (reward - values[arm]) / Double(counts[arm])
            }
            total += reward
        }
        return total / Double(steps)
    }

    /// Mean reward: [system][world]. / Средняя награда: [система][среда].
    static func table(steps: Int, runs: Int = 30) -> [[Double]] {
        System.allCases.map { system in
            worlds.indices.map { world in
                var total = 0.0
                for run in 0..<runs {
                    var rand = RLRand(UInt64(100 * world + run + 1))
                    total += play(system, world: world, steps: steps, rand: &rand)
                }
                return total / Double(runs)
            }
        }
    }

    /// Weighted mean with weight 2^(−simplicity · bits). / Взвешенное среднее с весом 2^(−простота · биты).
    static func score(_ row: [Double], simplicity: Double) -> Double {
        var total = 0.0
        var weights = 0.0
        for (value, world) in zip(row, worlds) {
            let weight: Double = pow(2, -simplicity * Double(world.bits))
            total += value * weight
            weights += weight
        }
        return total / weights
    }

    static func leggHutter(_ row: [Double]) -> Double {
        var total = 0.0
        for (value, world) in zip(row, worlds) { total += value * pow(2, -Double(world.bits)) }
        return total
    }
}

/// A Q-agent that also learns in imagination from its remembered world, as in the Dyna scheme.
/// Q-агент, который учится и в воображении по запомненному миру, как в схеме Dyna.
enum DynaModel {
    static let rows = 5
    static let columns = 6
    static let start = 24
    static let goal = 5
    static let walls: Set<Int> = [8, 14, 20]
    static let movedWalls: Set<Int> = [2, 8, 14]
    private static let moves: [(Int, Int)] = [(-1, 0), (0, 1), (1, 0), (0, -1)]

    private static func step(_ cell: Int, _ action: Int, _ walls: Set<Int>) -> (next: Int, reward: Double) {
        let row = cell / columns + moves[action].0
        let column = cell % columns + moves[action].1
        guard row >= 0, row < rows, column >= 0, column < columns, !walls.contains(row * columns + column) else { return (cell, 0) }
        let next = row * columns + column
        return (next, next == goal ? 1 : 0)
    }

    private static func choose(_ row: [Double], rand: inout RLRand) -> Int {
        if rand.next() < 0.1 { return Int(rand.next() * 4) }
        let top = row.max() ?? 0
        let ties = (0..<4).filter { row[$0] == top }
        return ties[Int(rand.next() * Double(ties.count))]
    }

    /// Real steps in each game. / Настоящие шаги в каждой игре.
    static func run(plans: Int, games: Int, seed: UInt64, moveAt: Int? = nil) -> [Int] {
        var rand = RLRand(seed)
        var q = [[Double]](repeating: [0, 0, 0, 0], count: rows * columns)
        var model = [(next: Int, reward: Double)?](repeating: nil, count: rows * columns * 4)
        var seen: [Int] = []
        var current = walls
        var log: [Int] = []
        for game in 0..<games {
            if game == moveAt { current = movedWalls }
            var cell = start
            var steps = 0
            while cell != goal, steps < 300 {
                let action = choose(q[cell], rand: &rand)
                let result = step(cell, action, current)
                let future: Double = result.next == goal ? 0 : 0.95 * (q[result.next].max() ?? 0)
                q[cell][action] += 0.5 * (result.reward + future - q[cell][action])
                let key = cell * 4 + action
                if model[key] == nil { seen.append(key) }
                model[key] = result
                if plans > 0 {
                    for _ in 0..<plans {
                        let picked = seen[Int(rand.next() * Double(seen.count))]
                        guard let memory = model[picked] else { continue }
                        let ahead: Double = memory.next == goal ? 0 : 0.95 * (q[memory.next].max() ?? 0)
                        q[picked / 4][picked % 4] += 0.5 * (memory.reward + ahead - q[picked / 4][picked % 4])
                    }
                }
                cell = result.next
                steps += 1
            }
            log.append(steps)
        }
        return log
    }

    static func meanSteps(plans: Int, games: Int, moveAt: Int?, runs: Int = 20) -> [Double] {
        var total = [Double](repeating: 0, count: games)
        let base: UInt64 = moveAt == nil ? 500 : 700
        for run in 0..<runs {
            let log = Self.run(plans: plans, games: games, seed: base + UInt64(run), moveAt: moveAt)
            for game in 0..<games { total[game] += Double(log[game]) / Double(runs) }
        }
        return total
    }
}

/// A small network on two tasks in different zones, and replay of stored examples.
/// Маленькая сеть на двух задачах в разных зонах и повторение сохранённых примеров.
struct ReplayNet {
    typealias Point = (x: Double, y: Double, label: Bool)
    static let hidden = 8
    private(set) var inner: [[Double]]
    private(set) var outer: [Double]

    init(seed: UInt64) {
        var rand = RLRand(seed)
        var first: [[Double]] = []
        for _ in 0..<Self.hidden {
            var row: [Double] = []
            for _ in 0..<3 { row.append((rand.next() - 0.5) * 2) }
            first.append(row)
        }
        var second: [Double] = []
        for _ in 0...Self.hidden { second.append((rand.next() - 0.5) * 2) }
        inner = first
        outer = second
    }

    static func points(side: Double, count: Int, seed: UInt64) -> [Point] {
        var rand = RLRand(seed)
        var result: [Point] = []
        for _ in 0..<count {
            let x = side * (0.1 + 0.9 * rand.next())
            let y = rand.next() * 2 - 1
            result.append((x, y, side < 0 ? y > 0 : y < 0))
        }
        return result
    }

    func probability(_ x: Double, _ y: Double) -> Double {
        var sum = outer[Self.hidden]
        for j in 0..<Self.hidden {
            sum += outer[j] * tanh(inner[j][0] * x + inner[j][1] * y + inner[j][2])
        }
        return 1 / (1 + exp(-max(min(sum, 30), -30)))
    }

    private mutating func learn(_ point: Point, rate: Double) {
        var h = [Double](repeating: 0, count: Self.hidden)
        var sum = outer[Self.hidden]
        for j in 0..<Self.hidden {
            h[j] = tanh(inner[j][0] * point.x + inner[j][1] * point.y + inner[j][2])
            sum += outer[j] * h[j]
        }
        let error: Double = 1 / (1 + exp(-max(min(sum, 30), -30))) - (point.label ? 1 : 0)
        for j in 0..<Self.hidden {
            let g: Double = outer[j] * (1 - h[j] * h[j]) * error
            inner[j][0] -= rate * g * point.x
            inner[j][1] -= rate * g * point.y
            inner[j][2] -= rate * g
            outer[j] -= rate * h[j] * error
        }
        outer[Self.hidden] -= rate * error
    }

    /// Steps of training; the generator is kept so that a long run can go in pieces. / Шаги обучения; генератор хранится, чтобы идти кусками.
    mutating func train(_ data: [Point], steps: Int, rand: inout RLRand, replay: [Point] = [], share: Double = 0, rate: Double = 0.08) {
        for _ in 0..<steps {
            let point: Point
            if !replay.isEmpty, rand.next() < share {
                point = replay[Int(rand.next() * Double(replay.count))]
            } else {
                point = data[Int(rand.next() * Double(data.count))]
            }
            learn(point, rate: rate)
        }
    }

    func accuracy(_ data: [Point]) -> Double {
        var right = 0
        for point in data where (probability(point.x, point.y) > 0.5) == point.label { right += 1 }
        return Double(right) / Double(data.count)
    }
}

/// The power law through the first points on a log-log chart. / Степенной закон по первым точкам на графике в логарифмах.
enum ScalingFit {
    static func fit(_ xs: [Double], _ ys: [Double]) -> (slope: Double, scale: Double) {
        let lx = xs.map { log($0) }
        let ly = ys.map { log($0) }
        let mx = lx.reduce(0, +) / Double(lx.count)
        let my = ly.reduce(0, +) / Double(ly.count)
        var top = 0.0
        var bottom = 0.0
        for (a, b) in zip(lx, ly) {
            top += (a - mx) * (b - my)
            bottom += (a - mx) * (a - mx)
        }
        let slope = top / bottom
        return (slope, exp(my - slope * mx))
    }

    static func law(_ n: Double, _ fit: (slope: Double, scale: Double)) -> Double {
        fit.scale * pow(n, fit.slope)
    }
}
